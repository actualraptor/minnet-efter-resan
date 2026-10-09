"""Retarget CMU motion capture (BVH, cgspeed conversion) onto our rigs.

Approach: per output frame, every target bone is aimed along the matching
source bone's world direction (hips/chest also take twist from the hip and
shoulder lines). One clean gait cycle is cut from each clip using foot
contacts, made in-place (forward drift removed, bob and sway kept), and
crossfaded at the seam so it loops. Leg length is matched by scale.

Mocap: CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu), BVH
conversion by B. Hahne. Free to use, including in commercial products;
the raw data itself may not be resold.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

SRC_JOINTS = ["Hips", "LowerBack", "Spine", "Spine1", "Neck", "Neck1", "Head",
              "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand",
              "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]

# target bone: (from joint, to joint)
MAP = {
    "hips": ("Hips", "Spine"), "spine": ("Spine", "Spine1"), "chest": ("Spine1", "Neck1"),
    "neck": ("Neck1", "Head"), "head": ("Head", "HeadTop"),
    "shoulder.L": ("LeftShoulder", "LeftArm"), "upper_arm.L": ("LeftArm", "LeftForeArm"),
    "forearm.L": ("LeftForeArm", "LeftHand"), "hand.L": ("LeftHand", "LeftHandTip"),
    "shoulder.R": ("RightShoulder", "RightArm"), "upper_arm.R": ("RightArm", "RightForeArm"),
    "forearm.R": ("RightForeArm", "RightHand"), "hand.R": ("RightHand", "RightHandTip"),
    "thigh.L": ("LeftUpLeg", "LeftLeg"), "shin.L": ("LeftLeg", "LeftFoot"), "foot.L": ("LeftFoot", "LeftToeBase"),
    "thigh.R": ("RightUpLeg", "RightLeg"), "shin.R": ("RightLeg", "RightFoot"), "foot.R": ("RightFoot", "RightToeBase"),
}
ORDER = ["hips", "spine", "chest", "neck", "head", "upper_arm.L", "forearm.L", "hand.L",
         "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]
TWIST = {"hips": ("LeftUpLeg", "RightUpLeg"), "chest": ("LeftArm", "RightArm"), "spine": ("LeftUpLeg", "RightUpLeg")}


def sample_bvh(path):
    """Returns (fps, dict joint -> (F,3) world positions) for frames 2..end."""
    before = set(bpy.data.objects)
    bpy.ops.import_anim.bvh(filepath=path, axis_forward="-Z", axis_up="Y", global_scale=1.0,
                            rotate_mode="NATIVE", update_scene_fps=False, update_scene_duration=False)
    src = [o for o in bpy.data.objects if o not in before][0]
    act = src.animation_data.action
    f0, f1 = (int(x) for x in act.frame_range)
    pb = src.pose.bones
    data = {j: [] for j in SRC_JOINTS + ["HeadTop", "LeftHandTip", "RightHandTip"]}
    scn = bpy.context.scene
    for f in range(f0 + 1, f1 + 1):
        scn.frame_set(f)
        for j in SRC_JOINTS:
            data[j].append(np.array((src.matrix_world @ pb[j].head)[:]))
        data["HeadTop"].append(np.array((src.matrix_world @ pb["Head"].tail)[:]))
        data["LeftHandTip"].append(np.array((src.matrix_world @ pb["LeftHand"].tail)[:]))
        data["RightHandTip"].append(np.array((src.matrix_world @ pb["RightHand"].tail)[:]))
    with open(path) as fh:
        ft = [l for l in fh if l.strip().startswith("Frame Time")][0]
    fps = 1.0 / float(ft.split(":")[1])
    bpy.data.objects.remove(src, do_unlink=True)
    bpy.data.actions.remove(act)
    return fps, {k: np.array(v) for k, v in data.items()}


def normalise(data, hip_height):
    """Scale to our hip height, rotate so travel is -Y and the subject's left is +X."""
    H = data["Hips"]
    legs = np.linalg.norm(data["LeftUpLeg"] - data["LeftLeg"], axis=1).mean() + np.linalg.norm(data["LeftLeg"] - data["LeftFoot"], axis=1).mean()
    s = hip_height / max(legs * 1.08, 1e-6)
    ground = min(data["LeftToeBase"][:, 2].min(), data["RightToeBase"][:, 2].min())
    travel = H[-1] - H[0]
    travel[2] = 0
    if np.linalg.norm(travel) < 0.1:
        # in-place clip: use the facing (hip line rotated) instead
        hl = (data["LeftUpLeg"] - data["RightUpLeg"]).mean(axis=0)
        travel = np.array([-hl[1], hl[0], 0.0])
    ang = math.atan2(travel[0], -travel[1])  # rotate travel onto -Y
    c, si = math.cos(ang), math.sin(ang)
    R = np.array([[c, -si, 0], [si, c, 0], [0, 0, 1]])
    out = {}
    origin = np.array([H[0][0], H[0][1], ground])
    for k, v in data.items():
        out[k] = ((v - origin) @ R.T) * s
    # Subject's left must be +X; mirror X if not.
    if (out["LeftUpLeg"][:, 0] - out["RightUpLeg"][:, 0]).mean() < 0:
        for k in out:
            out[k][:, 0] *= -1
    return out


def find_cycle(d, fps):
    """Two consecutive left-foot contacts near the middle of the clip."""
    z = d["LeftFoot"][:, 2]
    zf = np.convolve(z, np.ones(5) / 5, mode="same")
    thr = zf.min() + 0.25 * (np.percentile(zf, 90) - zf.min())
    contacts = [i for i in range(1, len(zf)) if zf[i] < thr <= zf[i - 1]]
    if len(contacts) < 2:
        n = int(fps)
        return len(z) // 2 - n // 2, len(z) // 2 + n // 2
    mid = len(z) / 2
    contacts.sort(key=lambda i: abs(i - mid))
    a = contacts[0]
    later = [c for c in sorted(contacts) if c > a + fps * 0.5]
    b = later[0] if later else sorted(contacts)[-1]
    return a, b


def make_cycle(d, fps, out_fps=30):
    a, b = find_cycle(d, fps)
    n_in = b - a
    n_out = max(8, int(round(n_in / fps * out_fps)))
    H = d["Hips"]
    drift = (H[b] - H[a])
    speed = float(np.linalg.norm(drift[:2]) / (n_in / fps))
    cyc = {}
    for k, v in d.items():
        seg = v[a:b + 1].copy()
        t = np.linspace(0, 1, len(seg))[:, None]
        seg[:, :2] -= (H[a][:2] + (drift[:2])[None, :] * t)  # in place, centred
        src_t = np.linspace(0, len(seg) - 1, n_out + 1)
        res = np.stack([np.interp(src_t, np.arange(len(seg)), seg[:, i]) for i in range(3)], axis=1)
        # Close the loop: spread the seam error smoothly over the cycle.
        delta = res[0] - res[n_out]
        tt = np.linspace(0, 1, n_out + 1)[:, None]
        res += delta[None, :] * (tt * tt * (3 - 2 * tt))
        cyc[k] = res
    return cyc, n_out, speed


def _aim(pb, d_world, twist_ref=None):
    M = pb.matrix.copy()
    cur = Vector(M.col[1][:3]).normalized()
    D = Vector(d_world).normalized()
    R = cur.rotation_difference(D).to_matrix()
    rot = R @ M.to_3x3()
    if twist_ref is not None:
        x = Vector(rot.col[0][:3])
        ref = Vector(twist_ref)
        ref = (ref - D * ref.dot(D))
        if ref.length > 1e-5:
            ref.normalize()
            xp = (x - D * x.dot(D)).normalized()
            ang = xp.angle(ref)
            if xp.cross(ref).dot(D) < 0:
                ang = -ang
            rot = Matrix.Rotation(ang, 3, D) @ rot
    return rot


def bake(arm, name, cyc, n, hold_right=0.0, staff=False, staff_tilt=8.0):
    """Keyframe the cycle onto `arm` (a mesh-free armature for speed)."""
    act = bpy.data.actions.new(name)
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    pbs = arm.pose.bones
    for p in pbs:
        p.rotation_mode = "QUATERNION"
    hold = {"upper_arm.R": Vector((-0.25, -0.15, -1.0)), "forearm.R": Vector((-0.1, -0.7, -0.6))}
    for f in range(n + 1):
        for p in pbs:
            p.matrix_basis = Matrix.Identity(4)
        bpy.context.view_layer.update()
        for bname in ORDER:
            if bname not in pbs:
                continue
            j0, j1 = MAP[bname]
            d = cyc[j1][f] - cyc[j0][f]
            if np.linalg.norm(d) < 1e-4:
                continue
            if bname in hold and hold_right > 0:
                d = Vector(d).normalized() * (1 - hold_right) + hold[bname].normalized() * hold_right
            tw = None
            if bname in TWIST:
                a, b = TWIST[bname]
                tw = cyc[a][f] - cyc[b][f]
            rot = _aim(pbs[bname], d, tw)
            pb = pbs[bname]
            if bname == "hips":
                rest_head = pb.bone.head_local
                loc = Vector(cyc["Hips"][f]) + Vector((0, 0, 0))
                loc.z = rest_head.z + (cyc["Hips"][f][2] - cyc["Hips"][:, 2].mean())
                loc.x = rest_head.x + cyc["Hips"][f][0] * 0.6
                loc.y = rest_head.y + cyc["Hips"][f][1] * 0.6
                pb.matrix = Matrix.Translation(loc) @ rot.to_4x4()
            else:
                pb.matrix = Matrix.Translation(pb.matrix.translation) @ rot.to_4x4()
            bpy.context.view_layer.update()
        if staff and "hand.R" in pbs:
            pb = pbs["hand.R"]
            rest = pb.bone.matrix_local.to_3x3()
            R = Matrix.Rotation(math.radians(staff_tilt), 3, "X")
            pb.matrix = Matrix.Translation(pb.matrix.translation) @ (R @ rest).to_4x4()
            bpy.context.view_layer.update()
        for p in pbs:
            if p.name in MAP:
                p.keyframe_insert("rotation_quaternion", frame=f, group=p.name)
                if p.name == "hips":
                    p.keyframe_insert("location", frame=f, group=p.name)
    arm.animation_data.action = None
    return act


def retarget_clips(arm, clips, mocap_dir):
    """clips: [(action_name, bvh_file, options)]. Bakes on a mesh-free copy,
    then pushes the actions onto `arm` as NLA tracks. Returns {name: speed}."""
    real_name = arm.name
    arm.name = real_name + "_real"
    helper = bpy.data.objects.new(real_name, arm.data.copy())
    bpy.context.scene.collection.objects.link(helper)
    hip_h = arm.data.bones["thigh.L"].head_local.z
    speeds = {}
    for name, fname, opt in clips:
        fps, raw = sample_bvh(os.path.join(mocap_dir, fname))
        d = normalise(raw, hip_h)
        cyc, n, speed = make_cycle(d, fps)
        act = bake(helper, name, cyc, n, hold_right=opt.get("hold_right", 0.0), staff=opt.get("staff", False), staff_tilt=opt.get("staff_tilt", 8.0))
        speeds[name] = round(speed, 3)
        print(f"MOCAP {name}: {fname} cycle {n} frames, natural speed {speed:.2f} m/s")
    bpy.data.objects.remove(helper, do_unlink=True)
    arm.name = real_name
    if arm.animation_data is None:
        arm.animation_data_create()
    for name, _, _ in clips:
        act = bpy.data.actions[name]
        arm.animation_data.action = act
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, act)
        st.name = name
        arm.animation_data.action = None
    return speeds
