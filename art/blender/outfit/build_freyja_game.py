"""Freyja game model: VRoid body + reference outfit + retargeted mocap, one GLB.

    blender -b --factory-startup --python art/blender/outfit/build_freyja_game.py -- <repo>

- Body: the owner's VRoid model (art/source/vroid/freyja.glb), its own clothing
  removed, skin under opaque garments deleted.
- Outfit: built by build_reference_outfit.build_outfit() on that body, with the
  shared skirt spring chains (skirt_k_n).
- Hair: VRoid's J_Sec_Hair chains renamed hairB_<chain>_<n> so the game's
  spring-bone setup (CharacterPhysics) simulates them.
- Face: VRoid expression keys renamed to the FaceController's names.
- Motion: CMU mocap (walk, run, standing idle, jump/fall/land) retargeted via a
  stand-in armature with the legacy bone names at the VRoid joint positions,
  then transferred bone by bone as world-space rotation deltas. Fingers get a
  relaxed curl.
Exports game/assets/models/characters/freyja_vroid_game.glb.
"""
import json
import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import build_reference_outfit as REF  # noqa: E402
import mocap_retarget as MR  # noqa: E402
import tailor as T  # noqa: E402

C = REF.C
ROOT = REF.ROOT
OUT = os.path.join(ROOT, "game", "assets", "models", "characters", "freyja_vroid_game.glb")

SHAPE_KEYS = {"Fcl_EYE_Close": "blink", "Fcl_EYE_Joy": "squint", "Fcl_MTH_A": "mouth_open",
              "Fcl_MTH_Fun": "mouth_smile", "Fcl_MTH_O": "mouth_o", "Fcl_BRW_Surprised": "brow_up"}

# legacy proxy bone -> (real bone, aim target joint or None for a +Z stub)
PROXY = [
    ("hips", None, "Hips", "Spine"), ("spine", "hips", "Spine", "Chest"),
    ("chest", "spine", "Chest", "Neck"), ("neck", "chest", "Neck", "Head"),
    ("head", "neck", "Head", None),
]
for s, S in (("L", "Left"), ("R", "Right")):
    PROXY += [
        (f"shoulder.{s}", "chest", f"{S}Shoulder", f"{S}UpperArm"),
        (f"upper_arm.{s}", f"shoulder.{s}", f"{S}UpperArm", f"{S}LowerArm"),
        (f"forearm.{s}", f"upper_arm.{s}", f"{S}LowerArm", f"{S}Hand"),
        (f"hand.{s}", f"forearm.{s}", f"{S}Hand", None),
        (f"thigh.{s}", "hips", f"{S}UpperLeg", f"{S}LowerLeg"),
        (f"shin.{s}", f"thigh.{s}", f"{S}LowerLeg", f"{S}Foot"),
        (f"foot.{s}", f"shin.{s}", f"{S}Foot", f"{S}Toes"),
    ]
# Real bones driven from the proxy (others keep their rest relative to the parent).
DRIVEN = {real: legacy for legacy, _, real, _ in PROXY if not legacy.startswith("shoulder")}

FINGER_CURL = {  # degrees per joint (proximal/metacarpal, intermediate/proximal, distal)
    "Index": (16, 26, 16), "Middle": (18, 28, 18), "Ring": (22, 30, 20), "Little": (26, 34, 22),
    "Thumb": (4, 10, 12),
}


def J(arm, name):
    return arm.matrix_world @ arm.data.bones[name].head_local


def make_proxy(arm):
    data = bpy.data.armatures.new("Proxy")
    prox = bpy.data.objects.new("Proxy", data)
    bpy.context.scene.collection.objects.link(prox)
    T._select_only([prox])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = data.edit_bones
    for legacy, parent, real, tgt in PROXY:
        b = eb.new(legacy)
        h = J(arm, real)
        if tgt is not None:
            t = J(arm, tgt)
        elif legacy == "head":
            t = h + Vector((0, 0, 0.15))
        else:  # hand: continue the forearm direction
            fa = J(arm, real.replace("Hand", "LowerArm"))
            t = h + (h - fa).normalized() * 0.08
        b.head, b.tail, b.roll = h, t, 0.0
        if parent:
            b.parent = eb[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return prox


def finger_basis(arm):
    """Constant relaxed-curl pose basis per finger bone (palms face down in the T-pose)."""
    out = {}
    bones = arm.data.bones
    for side in ("Left", "Right"):
        for f, angles in FINGER_CURL.items():
            names = [f"{side}{f}{k}" for k in (("Metacarpal", "Proximal", "Distal") if f == "Thumb" else ("Proximal", "Intermediate", "Distal"))]
            for i, n in enumerate(names):
                if n not in bones:
                    continue
                b = bones[n]
                kids = [c for c in b.children if not c.name.endswith("_end")]
                if kids:
                    d = (kids[0].head_local - b.head_local)
                elif b.parent is not None:
                    d = (b.head_local - b.parent.head_local)
                else:
                    continue
                d.normalize()
                axis = d.cross(Vector((0, 0, -1)))
                if axis.length < 1e-4:
                    continue
                R = Matrix.Rotation(math.radians(angles[i]), 3, axis.normalized())
                M = b.matrix_local.to_3x3()
                out[n] = (M.inverted() @ R @ M).to_quaternion()
    return out


def transfer(arm, prox, clip, fingers):
    """Bake one proxy clip onto the real armature (world-space rotation deltas)."""
    src = bpy.data.actions[clip]
    prox.animation_data.action = src
    f0, f1 = (int(round(x)) for x in src.frame_range)
    act = bpy.data.actions.new(clip + "_vroid")
    arm.animation_data_create()
    arm.animation_data.action = act
    pbs = arm.pose.bones
    for p in pbs:
        p.rotation_mode = "QUATERNION"
    order = [b for b in arm.data.bones]   # parents come before children
    prev = {}
    scn = bpy.context.scene
    for f in range(f0, f1 + 1):
        scn.frame_set(f)
        pose = {}
        for b in order:
            par = b.parent
            local_rest = (par.matrix_local.inverted() @ b.matrix_local) if par else b.matrix_local.copy()
            base = (pose[par.name] @ local_rest) if par else local_rest
            if b.name in DRIVEN:
                lp = prox.pose.bones[DRIVEN[b.name]]
                delta = lp.matrix.to_3x3() @ lp.bone.matrix_local.to_3x3().inverted()
                rot = delta @ b.matrix_local.to_3x3()
                pos = lp.matrix.translation if b.name == "Hips" else base.translation
                pm = Matrix.Translation(pos) @ rot.to_4x4()
                basis = base.inverted() @ pm
            elif b.name in fingers:
                basis = fingers[b.name].to_matrix().to_4x4()
                pm = base @ basis
            else:
                pm = base
                pose[b.name] = pm
                continue
            pose[b.name] = pm
            pb = pbs[b.name]
            q = basis.to_quaternion()
            if b.name in prev:
                q.make_compatible(prev[b.name])
            prev[b.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f, group=b.name)
            if b.name == "Hips":
                pb.location = basis.translation
                pb.keyframe_insert("location", frame=f, group=b.name)
    arm.animation_data.action = None
    src.name = clip + "_proxy"
    act.name = clip
    return act


def remove_covered(body, covering, reach=0.03):
    """Delete body skin triangles that opaque fitted garments fully cover."""
    bm = bmesh.new()
    for o in covering:
        tmp = o.data.copy()
        tmp.transform(o.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    total = 0
    for o in body.meshes:
        mats = [m.name.upper() if m else "" for m in o.data.materials]
        b2 = bmesh.new()
        b2.from_mesh(o.data)
        b2.normal_update()
        cov = {}
        for v in b2.verts:
            p = o.matrix_world @ v.co
            n = (o.matrix_world.to_3x3() @ v.normal).normalized()
            cov[v.index] = bvh.ray_cast(p, n, reach)[0] is not None
        kill = [f for f in b2.faces
                if mats[f.material_index].split(" (")[0].endswith("_SKIN") and "BODY" in mats[f.material_index]
                and all(cov[v.index] for v in f.verts)]
        total += len(kill)
        bmesh.ops.delete(b2, geom=kill, context="FACES")
        b2.to_mesh(o.data)
        b2.free()
    print("COVERED SKIN removed", total)


def build_staff(arm):
    """Freyja's staff (the existing design from lib_freyja), as a free prop:
    vertical, grip at its local origin, with a StaffTip empty at the gem. The
    game holds it at her right hand each frame (StaffSummon), so it stays
    upright however the hand is posed."""
    import build_characters as BC
    import lib_character as Lc
    import lib_freyja as LL
    wrist = J(arm, "RightHand")
    tip = J(arm, "RightMiddleDistal") if "RightMiddleDistal" in arm.data.bones else wrist + Vector((-0.12, 0, 0))
    Lc.J["wrist"] = (abs(wrist.x), wrist.y, wrist.z)    # Rig.p(..., -1) mirrors x
    Lc.J["hand_tip"] = (abs(tip.x), tip.y, tip.z)
    spec = dict(BC.SPECS["freyja"])
    spec["height"] = Lc.BASE_H
    rig = Lc.Rig(spec)
    LL.staff(rig, LL.mats(rig.spec))
    staff = rig.objects[-1][0]
    grip = rig.p("wrist", -1).lerp(rig.p("hand_tip", -1), 0.45)
    staff.data.transform(Matrix.Translation(-grip))
    staff.data.update()
    staff.location = (0, 0, 0)
    staff.name = "Staff"
    st = bpy.data.objects.new("StaffTip", None)
    bpy.context.scene.collection.objects.link(st)
    st.parent = staff
    st.location = Vector(rig.staff_tip) - grip
    return staff, st


def main():
    built = REF.build_outfit()
    body, arm, output = built["body"], built["arm"], built["output"]
    remove_covered(body, built["covering"])
    # Hair chains -> hairB_<chain>_<n> for the game's spring bones.
    for b in list(arm.data.bones):
        m = re.match(r"J_Sec_Hair(\d+)_(\d+)$", b.name)
        if m:
            # VRoid: J_Sec_Hair<segment>_<chain>; ours: hairB_<chain>_<segment>.
            b.name = f"hairB_{int(m.group(2))}_{int(m.group(1))}"
    for o in body.meshes:
        if o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks:
                if kb.name in SHAPE_KEYS:
                    kb.name = SHAPE_KEYS[kb.name]
    # Motion.
    prox = make_proxy(arm)
    mocap = os.path.join(ROOT, "art", "source", "mocap")
    clips = [("Idle", "16_05.bvh", {"segment": "stand", "lean": 3.0, "calm_head": 0.5}),
             ("Walk", "07_01.bvh", {"lean": 4.0}),
             ("Run", "09_02.bvh", {"lean": 9.0}),
             ("Jump", "16_05.bvh", {"segment": "jump", "lean": 6.0, "calm_head": 0.7}),
             ("Fall", "16_05.bvh", {"segment": "fall", "lean": 4.0, "calm_head": 0.7}),
             ("Land", "16_05.bvh", {"segment": "land", "lean": 6.0, "calm_head": 0.6})]
    speeds = MR.retarget_clips(prox, clips, mocap)
    prox.animation_data_create()
    for tr in prox.animation_data.nla_tracks:
        tr.mute = True
    fingers = finger_basis(arm)
    acts = [transfer(arm, prox, name, fingers) for name, _, _ in clips]
    # Placeholders so the game's animation tree finds every state it expects.
    idle = next(a for a in acts if a.name == "Idle")
    for alias in ("Talk", "Cast", "Summon", "SummonFlick", "SummonReach", "SummonTwirl", "IdleStaff"):
        c = idle.copy()
        c.name = alias
        acts.append(c)
    for a in ("Walk", "Run"):
        c = next(x for x in acts if x.name == a).copy()
        c.name = a + "Staff"
        acts.append(c)
    arm.animation_data_create()
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)
    for a in acts:
        tr = arm.animation_data.nla_tracks.new()
        tr.name = a.name
        tr.strips.new(a.name, 0, a)
    arm.animation_data.action = None
    bpy.data.objects.remove(prox, do_unlink=True)
    for b in arm.pose.bones:
        b.matrix_basis.identity()
    with open(os.path.join(ROOT, "game", "data", "characters", "freyja_vroid_locomotion.json"), "w") as fh:
        json.dump({"natural_speed": speeds, "source": "CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu)"}, fh, indent=1)
    staff, staff_tip = build_staff(arm)
    objs = [arm] + list(body.meshes) + output + [staff, staff_tip]
    for o in objs:
        o.hide_render = False
        o.hide_set(False)
    C.export_glb(OUT, objs, animations=True)
    print("GAME_MODEL_EXPORTED", OUT, "clips", [a.name for a in acts], "speeds", speeds)


main()
