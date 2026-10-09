"""Stage 2 of Linnaea v3: measured joints, Linnaea's own accessories (shaped to
the outfit's real surface), rig, skin weights, animations, export.
Called from build_linnaea_v3.build(stage="full")."""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

import lib_common as C


def measure_joints(body_objs):
    P = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in body_objs])
    left = P[P[:, 0] > 0]
    arm = left[(left[:, 0] > 0.2) & (left[:, 2] > 0.6)]
    xs = np.linspace(0.2, arm[:, 0].max() - 0.01, 30)
    line = []
    for i in range(len(xs) - 1):
        m = (arm[:, 0] >= xs[i]) & (arm[:, 0] < xs[i + 1])
        if m.sum() > 5:
            line.append(arm[m].mean(axis=0))
    line = np.array(line)
    tip_x = float(arm[:, 0].max())

    def arm_at(x):
        return np.array([x, np.interp(x, line[:, 0], line[:, 1]), np.interp(x, line[:, 0], line[:, 2])])
    sh_x = 0.15
    sh = arm_at(0.21) + np.array([0.0, 0.0, 0.04])
    sh[0] = sh_x
    la = tip_x - sh_x
    J = {
        "pelvis": (0, -0.05, 0.84), "spine": (0, -0.06, 0.98), "chest": (0, -0.07, 1.16),
        "neck_base": (0, -0.06, 1.34), "neck_top": (0, -0.07, 1.42),
        "shoulder_in": (0.03, -0.06, 1.32), "shoulder": tuple(sh),
        "elbow": tuple(arm_at(sh_x + la * 0.4)), "wrist": tuple(arm_at(sh_x + la * 0.74)),
        "hand_tip": tuple(arm_at(tip_x - 0.01)), "thumb": tuple(arm_at(sh_x + la * 0.8) + np.array([0, -0.03, 0])),
        "hip": (0.082, -0.07, 0.78), "knee": (0.075, -0.08, 0.43), "ankle": (0.072, -0.05, 0.085),
        "toe": (0.072, -0.17, 0.02),
    }
    for key, z in (("hip", 0.78), ("knee", 0.43), ("ankle", 0.085)):
        sl = left[(np.abs(left[:, 2] - z) < 0.015) & (left[:, 0] < 0.2)]
        if len(sl):
            J[key] = (float(sl[:, 0].mean()), float(sl[:, 1].mean()), z)
    J["toe"] = (J["ankle"][0], J["ankle"][1] - 0.12, 0.02)
    J = {k: tuple(float(c) for c in v) for k, v in J.items()}
    print("JOINTS", {k: tuple(round(c, 3) for c in v) for k, v in J.items()})
    return J


def surface_points(objs):
    return np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objs])


def wrap_surface(name, pts, z_top, z_bot, a0, a1, offset, mat, rows=8, segs=24, hem_drop=0.0):
    """Band hugging the outer silhouette of pts (angles in degrees, 270 = front)."""
    ang = np.degrees(np.arctan2(pts[:, 1], pts[:, 0])) % 360
    rad = np.hypot(pts[:, 0], pts[:, 1])
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        t = j / rows
        z = z_top + (z_bot - z_top) * t
        zmask = np.abs(pts[:, 2] - z) < 0.025
        fallback = float(np.percentile(rad[zmask], 90)) if zmask.any() else 0.12
        row = []
        for i in range(segs + 1):
            u = i / segs
            a = (a0 + (a1 - a0) * u) % 360
            m = zmask & (np.abs(((ang - a) + 180) % 360 - 180) < 8)
            r = float(np.percentile(rad[m], 97)) if m.sum() > 3 else fallback
            drop = hem_drop * (1 - abs(u * 2 - 1)) ** 1.3 * t ** 2
            ar = math.radians(a)
            row.append(bm.verts.new((math.cos(ar) * (r + offset), math.sin(ar) * (r + offset), z - drop)))
        grid.append(row)
    for j in range(rows):
        for i in range(segs):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    edge = [grid[j][0].co.copy() for j in range(rows + 1)] + [v.co.copy() for v in grid[-1][1:]] + \
           [grid[j][-1].co.copy() for j in range(rows - 1, -1, -1)]
    return C.mesh_obj(name, bm, mat, smooth=True), edge


def accessories(objs, rig):
    import lib_character as Lc
    import lib_linnaea as LL
    M = LL.mats(rig.spec)
    cloth = [o for n, o in objs.items() if n.startswith(("Dress Skirt_", "Body01_"))]
    cp = surface_points(cloth)
    cp = cp[np.abs(cp[:, 0]) < 0.2]  # torso only (arms hang at waist height)
    parts = []
    corset, _ = wrap_surface("Corset", cp, 1.13, 0.99, 0, 360, 0.01, M["leather"], rows=4, segs=40)
    parts.append((corset, ["hips", "spine", "chest"]))
    trim = []
    front_r = float(np.percentile(np.abs(cp[(np.abs(cp[:, 2] - 1.08) < 0.02) & (np.abs(cp[:, 0]) < 0.03)][:, 1]), 97))
    for z in (1.11, 1.05, 1.0):
        trim.append(C.box("Buckle", (0.0, -front_r - 0.016, z), (0.016, 0.006, 0.012), M["gold"], bevel=0.003))
    hip, _ = wrap_surface("HipBelt", cp, 0.975, 0.95, 0, 360, 0.018, M["leather_dark"], rows=1, segs=40)
    trim.append(hip)
    hip_r = float(np.percentile(np.abs(cp[(np.abs(cp[:, 2] - 0.96) < 0.02) & (np.abs(cp[:, 0]) < 0.04)][:, 1]), 97))
    trim.append(C.box("HipBuckle", (0.03, -hip_r - 0.024, 0.962), (0.02, 0.006, 0.016), M["gold"], bevel=0.004))
    pc = Vector((0.15, -hip_r + 0.02, 0.9))
    trim.append(C.box("Pouch", pc, (0.045, 0.03, 0.045), M["leather"], bevel=0.01))
    trim.append(C.box("PouchFlap", pc + Vector((0, -0.031, 0.018)), (0.047, 0.005, 0.03), M["leather_dark"], bevel=0.004))
    trim.append(C.box("PouchClasp", pc + Vector((0, -0.037, 0.0)), (0.009, 0.003, 0.009), M["gold"]))
    for k, (dx, ln, kind) in enumerate(((-0.08, 0.07, "coin"), (-0.055, 0.1, "coin"), (-0.03, 0.06, "leaf"),
                                        (-0.005, 0.09, "coin"), (-0.105, 0.05, "leaf"))):
        top = Vector((dx, -hip_r - 0.022, 0.955))
        low = top + Vector((0, -0.006, -ln))
        trim.append(C.tube("CharmChain", [top, low], [0.0022, 0.0022], M["gold"], segs=4))
        if kind == "coin":
            trim.append(C.cylinder("Coin", low + Vector((0, 0.002, -0.012)), low + Vector((0, -0.002, -0.012)), 0.012, material=M["gold"], segs=12))
        else:
            trim.append(C.ellipsoid("LeafCharm", low + Vector((0, 0, -0.022)), (0.011, 0.003, 0.022), M["leaf"], segs=6, rings=4))
    parts.append((C.join(trim, "BeltBits"), ["hips", "spine", "thigh.L", "thigh.R"]))
    skirt = [o for n, o in objs.items() if n.startswith("Dress Skirt_M_Frieren_001")]
    sp_ = surface_points(skirt) if skirt else cp
    hem_z = float(np.percentile(sp_[:, 2], 1))
    bits = []
    sp_ = sp_[np.abs(sp_[:, 0]) < 0.3]
    for (ac, hw) in ((270, 9), (215, 7), (325, 7), (90, 9)):
        pn, edge = wrap_surface("PlumPanel", sp_, 0.9, hem_z + 0.01, ac - hw, ac + hw, 0.006, M["plum"], rows=8, segs=8, hem_drop=0.12)
        bits.append(pn)
        bits.append(C.tube("PanelTrim", edge, [0.004] * len(edge), M["gold"], segs=4, caps=False))
    parts.append((C.join(bits, "PlumPanels"), ["hips", "thigh.L", "thigh.R"]))
    pet, _ = wrap_surface("Petticoat", sp_, hem_z + 0.07, hem_z - 0.06, 0, 360, -0.004, M["cream2"], rows=4, segs=72)
    Lc.ruffle(pet, hem_z - 0.02, 0.016, 0.012, 18)
    parts.append((pet, ["hips", "thigh.L", "thigh.R"]))
    # Flower circlet + tassels.
    hc = Vector((0.0, -0.07, 1.53))
    hr = Vector((0.1, 0.12, 0.12))
    flow = []
    for k in range(17):
        t = k / 16
        a = math.radians(5 + 170 * t)
        p = hc + Vector((math.cos(a) * hr.x * 1.12, math.sin(a) * hr.y * 1.08 + 0.01, hr.z * (0.42 + 0.15 * math.sin(t * math.pi))))
        out = Vector((math.cos(a), math.sin(a), 0.3)).normalized()
        sc = 0.85 + 0.3 * ((k * 7) % 3) / 2
        tang = Vector((-math.sin(a), math.cos(a), 0))
        for j in range(5):
            pa = j * math.tau / 5 + k
            off = (tang * math.cos(pa) + Vector((0, 0, 1)) * math.sin(pa)) * 0.017 * sc
            flow.append(C.ellipsoid("Petal", p + off + out * 0.004, (0.012 * sc, 0.012 * sc, 0.012 * sc), M["flower"], segs=7, rings=4))
        flow.append(C.ellipsoid("FlowerC", p + out * 0.013, (0.0065, 0.0065, 0.0065), M["flower_c"], segs=6, rings=4))
        if k % 2 == 0:
            flow.append(C.ellipsoid("Leaf", p + Vector((0, 0, -0.024)) + out * 0.004, (0.01, 0.01, 0.024), M["leaf"], segs=6, rings=4))
    for side in (1, -1):
        tp = hc + Vector((0.04 * side, hr.y * 1.12, hr.z * 0.25))
        flow.append(C.tube("TasselCord", [tp, tp + Vector((0.002 * side, 0.004, -0.04))], [0.003, 0.003], M["gold"], segs=4))
        flow.append(C.ellipsoid("TasselKnot", tp + Vector((0, 0.004, -0.045)), (0.008, 0.008, 0.008), M["ribbon"], segs=6, rings=4))
        flow.append(C.cylinder("Tassel", tp + Vector((0, 0.004, -0.05)), tp + Vector((0, 0.006, -0.11)), 0.008, 0.015, material=M["ribbon"], segs=8))
    parts.append((C.join(flow, "Circlet"), None))
    LL.staff(rig, M)
    return parts


def build_rig(J, hair_chain):
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def P(key, side=1):
        v = J[key]
        return Vector((v[0] * side, v[1], v[2]))
    mid = (P("pelvis") + P("spine")) / 2 + Vector((0, 0, 0.04))
    defs = [("hips", P("pelvis"), mid, None), ("spine", mid, P("chest"), "hips"),
            ("chest", P("chest"), P("neck_base"), "spine"), ("neck", P("neck_base"), P("neck_top"), "chest"),
            ("head", P("neck_top"), P("neck_top") + Vector((0, 0, 0.24)), "neck")]
    for sfx, side in (("L", 1), ("R", -1)):
        defs += [(f"shoulder.{sfx}", P("shoulder_in", side), P("shoulder", side), "chest"),
                 (f"upper_arm.{sfx}", P("shoulder", side), P("elbow", side), f"shoulder.{sfx}"),
                 (f"forearm.{sfx}", P("elbow", side), P("wrist", side), f"upper_arm.{sfx}"),
                 (f"hand.{sfx}", P("wrist", side), P("hand_tip", side), f"forearm.{sfx}"),
                 (f"thigh.{sfx}", P("hip", side), P("knee", side), "hips"),
                 (f"shin.{sfx}", P("knee", side), P("ankle", side), f"thigh.{sfx}"),
                 (f"foot.{sfx}", P("ankle", side), P("toe", side), f"shin.{sfx}")]
    prev = "head"
    for i in range(len(hair_chain) - 1):
        defs.append((f"hair.{i + 1}", Vector(hair_chain[i]), Vector(hair_chain[i + 1]), prev))
        prev = f"hair.{i + 1}"
    made = {}
    for name, h, t, parent in defs:
        b = eb.new(name)
        b.head, b.tail, b.roll = h, t, 0.0
        made[name] = b
    for name, h, t, parent in defs:
        if parent:
            made[name].parent = made[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def run(root, mesh_objects, target_h):
    import build_characters as BC
    import lib_character as Lc
    objs = {o.name: o for o in mesh_objects()}
    body = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    J = measure_joints(body)
    Lc.J.update(J)
    spec = dict(BC.SPECS["linnaea"])
    spec["height"] = Lc.BASE_H
    rig = Lc.Rig(spec)
    parts = accessories(objs, rig)
    arm = build_rig(J, [(0, 0.03, 1.56), (0, 0.08, 1.33), (0, 0.11, 1.1), (0, 0.13, 0.86), (0, 0.15, 0.6)])
    rig.arm = arm
    # Eye bones (blink / squint / wide) placed at each eyeball's centre.
    eye_objs = [o for n, o in objs.items() if n.startswith("FrierenEyes")]
    ep = surface_points(eye_objs)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for sfx, sgn in (("L", 1), ("R", -1)):
        sel = ep[np.sign(ep[:, 0]) == sgn]
        c = Vector(sel.mean(axis=0))
        b = arm.data.edit_bones.new(f"eye.{sfx}")
        b.head, b.tail, b.roll = c, c + Vector((0, 0, 0.02)), 0.0
        b.parent = arm.data.edit_bones["head"]
    bpy.ops.object.mode_set(mode="OBJECT")
    head_bits = ("Object_3_", "Object_4_", "Object_6_", "FrierenEyes")
    body_bones = [b.name for b in arm.data.bones if not b.name.startswith("hair")]
    for n, o in objs.items():
        if n.startswith(head_bits):
            rig.add(o, rigid="head")
        elif n.startswith("HairBackV3"):
            rig.add(o, allowed=["head", "neck", "hair.1", "hair.2", "hair.3", "hair.4"])
        elif n.startswith(("Boots_", "Leggings_")):
            rig.add(o, allowed=["thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "hips"])
        else:
            rig.add(o, allowed=body_bones)
    for (o, bones) in parts:
        if bones is None:
            rig.add(o, rigid="head")
        else:
            rig.add(o, allowed=bones)
    for (o, _, _) in rig.objects:
        C.set_origin_world(o)
    Lc.skin_all(rig, falloff=5.0)
    for o in eye_objs:
        o.vertex_groups.clear()
        gl, gr = o.vertex_groups.new(name="eye.L"), o.vertex_groups.new(name="eye.R")
        gl.add([v.index for v in o.data.vertices if v.co.x > 0], 1.0, "REPLACE")
        gr.add([v.index for v in o.data.vertices if v.co.x <= 0], 1.0, "REPLACE")
    # Neutral, Linnaea-specific names in the shipped asset.
    renames = {"FrierenIris": "M_Eye_Iris_linnaea", "FrierenSclera": "M_Eye_White_linnaea", "FrierenBoots": "M_Outfit_Sleeves_linnaea",
               "M_Frieren_001_Skirt": "M_Outfit_Skirt_linnaea", "M_Frieren_001_Glass": "M_Outfit_Gem_linnaea", "M_Frieren_001": "M_Outfit_A_linnaea",
               "M_Frieren_002": "M_Outfit_B_linnaea", "defaultMat": "M_Skin_linnaea", "eyelashes_and_stuff": "M_Hair_linnaea",
               "Leggings": "M_Tights_linnaea", "Panties": "M_Under_linnaea", "Teeth": "M_Teeth_linnaea", "Tongue": "M_Tongue_linnaea"}
    for m in bpy.data.materials:
        if m.name in renames:
            m.name = renames[m.name]
    for o, _, _ in rig.objects:
        o.name = o.name.replace("Frieren", "Linnaea").replace("Dress Skirt", "Outfit")
    for i, img in enumerate(list(bpy.data.images)):
        if not img.name.startswith("linnaea_tex"):
            img.name = f"linnaea_tex_{i}"
    tip = bpy.data.objects.new("StaffTip", None)
    bpy.context.scene.collection.objects.link(tip)
    tip.parent = arm
    tip.parent_type = "BONE"
    tip.parent_bone = "hand.R"
    bpy.context.view_layer.update()
    tip.matrix_world = Matrix.Translation(rig.staff_tip)
    anim = Lc.Animator(rig)
    for (aname, frames, fn, loop) in BC.ANIMS["mage"]:
        anim.action(aname, frames, fn, loop)
    anim.reset()
    objs_out = [arm] + [o for o, _, _ in rig.objects] + [tip]
    C.export_glb(os.path.join(root, "game", "assets", "models", "characters", "linnaea.glb"), objs_out)
    ad = arm.animation_data
    for tr in ad.nla_tracks:
        tr.mute = True
    anim.reset()
    bpy.context.view_layer.update()
    prev = os.path.join(root, "art", "previews", "linnaea_v3_full.png")
    C.render_preview(prev, objs_out, views=((0, "front"), (35, "tq"), (90, "side"), (180, "back")),
                     height=target_h * 1.12, look_z=target_h * 0.55, size=(1800, 900))
    for (aname, frames, fn, loop) in BC.ANIMS["mage"]:
        act = bpy.data.actions.get(aname)
        ad.action = act
        try:
            if act.slots:
                ad.action_slot = act.slots[0]
        except AttributeError:
            pass
        bpy.context.scene.frame_set(int(frames * (0.55 if aname == "Cast" else 0.25)))
        C.render_preview(prev.replace(".png", f"_pose_{aname}.png"), objs_out, views=((30, "q"),),
                         height=target_h * 1.25, look_z=target_h * 0.55, size=(400, 900))
    ad.action = None
    print("BUILT linnaea v3", sum(len(o.data.polygons) for o, _, _ in rig.objects), "faces")
