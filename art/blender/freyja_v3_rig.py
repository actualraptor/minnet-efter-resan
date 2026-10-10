"""Stage 2 of Freyja v3: measured joints, Freyja's own accessories (shaped to
the outfit's real surface), rig, skin weights, animations, export.
Called from build_freyja_v3.build(stage="full")."""
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


class OuterShell:
    """Exact outer surface of some meshes, sampled by casting rays from outside
    toward the vertical axis through (0, cy). Sparse meshes (the skirt has ~300
    vertices) made percentile sampling jump between wrong radii."""

    def __init__(self, objs, start_r=0.42):
        from mathutils.bvhtree import BVHTree
        bm = bmesh.new()
        for o in objs:
            tmp = bmesh.new()
            tmp.from_mesh(o.data)
            tmp.transform(o.matrix_world)
            me = bpy.data.meshes.new("_shell")
            tmp.to_mesh(me)
            tmp.free()
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        self.bvh = BVHTree.FromBMesh(bm)
        bm.free()
        self.start_r = start_r

    def centre_y(self, z):
        hits = [self.radius(a, z, 0.0, raw=True) for a in (90.0, 270.0)]
        if None in hits:
            return 0.0
        return (hits[0] + hits[1]) / 2  # midway between the back and front surfaces

    def radius(self, a_deg, z, cy, raw=False):
        a = math.radians(a_deg)
        d = Vector((math.cos(a), math.sin(a), 0.0))
        origin = Vector((0.0, cy, z)) + d * self.start_r
        loc, nrm, idx, dist = self.bvh.ray_cast(origin, -d, self.start_r)
        if loc is None:
            return None
        if raw:
            return loc.y if abs(d.y) > 0.5 else loc.x
        return self.start_r - dist


def wrap_shell(name, shell, z_top, z_bot, a0, a1, offset, mat, rows=8, segs=24, hem_drop=0.0):
    """Band on the outer surface of `shell` (angles in degrees, 270 = front)."""
    cy = shell.centre_y((z_top + z_bot) / 2)
    bm = bmesh.new()
    grid = []
    prev = None
    for j in range(rows + 1):
        t = j / rows
        z = z_top + (z_bot - z_top) * t
        rs = []
        for i in range(segs + 1):
            a = a0 + (a1 - a0) * i / segs
            r = shell.radius(a, z, cy)
            rs.append(r if r is not None else (prev[i] if prev is not None else 0.15))
        rs = np.array(rs)
        full = abs((a1 - a0) - 360) < 1e-3
        for _ in range(2):
            pad = np.concatenate([rs[-3:-1], rs, rs[1:3]]) if full else np.concatenate([rs[:1], rs[:1], rs, rs[-1:], rs[-1:]])
            rs = np.convolve(pad, np.ones(5) / 5, mode='valid')
        prev = rs
        row = []
        for i in range(segs + 1):
            u = i / segs
            ar = math.radians(a0 + (a1 - a0) * u)
            drop = hem_drop * (1 - abs(u * 2 - 1)) ** 1.3 * t ** 2
            row.append(bm.verts.new((math.cos(ar) * (rs[i] + offset), cy + math.sin(ar) * (rs[i] + offset), z - drop)))
        grid.append(row)
    for j in range(rows):
        for i in range(segs):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    edge = [grid[j][0].co.copy() for j in range(rows + 1)] + [v.co.copy() for v in grid[-1][1:]] + \
           [grid[j][-1].co.copy() for j in range(rows - 1, -1, -1)]
    return C.mesh_obj(name, bm, mat, smooth=True), edge


def wrap_surface(name, pts, z_top, z_bot, a0, a1, offset, mat, rows=8, segs=24, hem_drop=0.0):
    """Band hugging the outer silhouette of pts (angles in degrees, 270 = front).
    Angles are measured around the torso's own centre: the model origin sits
    behind her back, and wrapping around it made bands bulge out like a bustle."""
    band = pts[(pts[:, 2] < max(z_top, z_bot) + 0.03) & (pts[:, 2] > min(z_top, z_bot) - 0.03)]
    cy = float(np.percentile(band[:, 1], 3) + np.percentile(band[:, 1], 97)) / 2 if len(band) > 10 else 0.0
    pts = pts - np.array([0.0, cy, 0.0])
    ang = np.degrees(np.arctan2(pts[:, 1], pts[:, 0])) % 360
    rad = np.hypot(pts[:, 0], pts[:, 1])
    bm = bmesh.new()
    grid = []
    for j in range(rows + 1):
        t = j / rows
        z = z_top + (z_bot - z_top) * t
        zmask = np.abs(pts[:, 2] - z) < 0.025
        fallback = float(np.percentile(rad[zmask], 90)) if zmask.any() else 0.12
        rs = []
        for i in range(segs + 1):
            u = i / segs
            a = (a0 + (a1 - a0) * u) % 360
            m = zmask & (np.abs(((ang - a) + 180) % 360 - 180) < 10)
            rs.append(float(np.percentile(rad[m], 95)) if m.sum() > 3 else fallback)
        rs = np.array(rs)
        full = abs((a1 - a0) - 360) < 1e-3
        for _ in range(4):  # smooth the outline so edges are clean, not jagged
            pad = np.concatenate([rs[-3:-1], rs, rs[1:3]]) if full else np.concatenate([rs[:1], rs[:1], rs, rs[-1:], rs[-1:]])
            rs = np.convolve(pad, np.ones(5) / 5, mode='valid')
        row = []
        for i in range(segs + 1):
            u = i / segs
            a = (a0 + (a1 - a0) * u) % 360
            drop = hem_drop * (1 - abs(u * 2 - 1)) ** 1.3 * t ** 2
            ar = math.radians(a)
            row.append(bm.verts.new((math.cos(ar) * (rs[i] + offset), cy + math.sin(ar) * (rs[i] + offset), z - drop)))
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
    import lib_freyja as LL
    M = LL.mats(rig.spec)
    cloth = [o for n, o in objs.items() if n.startswith(("Dress Skirt_", "Body01_"))]
    cp = surface_points(cloth)
    cp = cp[np.abs(cp[:, 0]) < 0.2]  # torso only (arms hang at waist height)
    parts = []
    torso_shell = OuterShell(cloth, start_r=0.3)   # inside the A-posed arms
    corset, _ = wrap_shell("Corset", torso_shell, 1.13, 0.99, 0, 360, 0.01, M["leather"], rows=4, segs=40)
    parts.append((corset, ["hips", "spine", "chest"]))
    trim = []
    front_r = float(np.percentile(np.abs(cp[(np.abs(cp[:, 2] - 1.08) < 0.02) & (np.abs(cp[:, 0]) < 0.03)][:, 1]), 97))
    for z in (1.11, 1.05, 1.0):
        trim.append(C.box("Buckle", (0.0, -front_r - 0.016, z), (0.016, 0.006, 0.012), M["gold"], bevel=0.003))
    hip, _ = wrap_shell("HipBelt", torso_shell, 0.975, 0.95, 0, 360, 0.016, M["leather_dark"], rows=1, segs=40)
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
    skirt_shell = OuterShell(skirt or cloth, start_r=0.45)
    for (ac, hw) in ((270, 9), (215, 7), (325, 7), (90, 9)):
        pn, edge = wrap_shell("PlumPanel", skirt_shell, 0.9, hem_z + 0.01, ac - hw, ac + hw, 0.006, M["plum"], rows=10, segs=8, hem_drop=0.1)
        bits.append(pn)
        bits.append(C.tube("PanelTrim", edge, [0.0035] * len(edge), M["gold"], segs=4, caps=False))
    parts.append((C.join(bits, "PlumPanels"), ["hips", "thigh.L", "thigh.R"]))
    # Two gathered ruffle tiers hanging straight down just inside the skirt hem.
    pcy = skirt_shell.centre_y(hem_z + 0.03)
    tiers = []
    for k, (top, bot, inset, freq) in enumerate(((hem_z + 0.06, hem_z - 0.035, 0.012, 22), (hem_z + 0.03, hem_z - 0.06, 0.03, 17))):
        bm = bmesh.new()
        rows = []
        segs = 72
        for j, z in enumerate((top, (top + bot) / 2, bot)):
            row = []
            for i in range(segs):
                a = i / segs * math.tau
                # Follow the skirt at this row's height (inside it above the hem,
                # flaring a little below it) so no wave pokes through the skirt.
                r_here = skirt_shell.radius(math.degrees(a), max(z, hem_z + 0.012), pcy) or 0.2
                amp = 0.005 + 0.004 * j
                wav = math.sin(a * freq) * amp
                below = max(0.0, hem_z - z)
                r = r_here - inset - (amp if z > hem_z else 0.0) + below * 0.35
                row.append(bm.verts.new((math.cos(a) * (r + wav), pcy + math.sin(a) * (r + wav), z + (math.sin(a * freq) * 0.004 if j == 2 else 0))))
            rows.append(row)
        for j in range(2):
            for i in range(segs):
                bm.faces.new((rows[j][i], rows[j][(i + 1) % segs], rows[j + 1][(i + 1) % segs], rows[j + 1][i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        tiers.append(C.mesh_obj(f"PetticoatTier{k}", bm, M["cream2"] if k == 0 else M["cream"], smooth=True))
    parts.append((C.join(tiers, "Petticoat"), ["hips", "thigh.L", "thigh.R"]))
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


def _centre_y(pts, z, band=0.04):
    m = np.abs(pts[:, 2] - z) < band
    return float(np.percentile(pts[m, 1], 3) + np.percentile(pts[m, 1], 97)) / 2 if m.sum() > 10 else 0.0


def _radius_at(pts, a_deg, z, pct=92, band=0.03, wedge=12):
    """Outer radius at angle a_deg around the local centre (see _centre_y)."""
    pts = pts - np.array([0.0, _centre_y(pts, z), 0.0])
    ang = np.degrees(np.arctan2(pts[:, 1], pts[:, 0])) % 360
    m = (np.abs(pts[:, 2] - z) < band) & (np.abs(((ang - a_deg) + 180) % 360 - 180) < wedge)
    if m.sum() < 3:
        m = np.abs(pts[:, 2] - z) < band
    return float(np.percentile(np.hypot(pts[m, 0], pts[m, 1]), pct)) if m.any() else 0.15


def add_dynamic_chains(arm, objs):
    """Bone chains driven at runtime by Godot's SpringBoneSimulator3D:
    hairB_k_* (back hair), hairS_{L,R}_* (side locks), skirt_k_* (ring), cape_k_* (rim)."""
    hair = surface_points([o for n, o in objs.items() if n.startswith("HairBackV3")])
    cap = surface_points([o for n, o in objs.items() if n.startswith("Object_6_")])
    skirt = surface_points([o for n, o in objs.items() if n.startswith("Dress Skirt_M_Frieren_001_Skirt")])
    cape = surface_points([o for n, o in objs.items() if n.startswith("Dress Skirt_M_Frieren_00")])
    chains = {}
    # Back hair strands.
    zs = [1.5, 1.28, 1.06, 0.84, 0.64]
    for k, x in enumerate(np.linspace(-0.14, 0.14, 9)):
        pts = []
        for z in zs:
            m = (np.abs(hair[:, 0] - x) < 0.03) & (np.abs(hair[:, 2] - z) < 0.04)
            y = float(hair[m, 1].mean()) if m.any() else 0.12
            pts.append(Vector((x, y, z)))
        chains[f"hairB_{k}"] = ("head", pts)
    # Side locks (long front strands of the hair cap).
    for sfx, sgn in (("L", 1), ("R", -1)):
        sel = cap[(np.sign(cap[:, 0]) == sgn) & (np.abs(cap[:, 0]) > 0.06) & (cap[:, 2] < 1.42)]
        if len(sel) > 10:
            zt, zb = 1.41, float(sel[:, 2].min()) + 0.01
            pts = []
            for z in np.linspace(zt, zb, 4):
                m = np.abs(sel[:, 2] - z) < 0.03
                c = sel[m].mean(axis=0) if m.any() else sel.mean(axis=0)
                pts.append(Vector(c))
            chains[f"hairS_{sfx}"] = ("head", pts)
    # Skirt ring.
    if len(skirt):
        hem = float(np.percentile(skirt[:, 2], 1))
        zl = [0.97, 0.86, 0.75, hem + 0.02]
        for k in range(10):
            a = k * 36.0 + 18.0
            pts = []
            for z in zl:
                r = _radius_at(skirt, a, z) - 0.012
                pts.append(Vector((math.cos(math.radians(a)) * r, _centre_y(skirt, z) + math.sin(math.radians(a)) * r, z)))
            chains[f"skirt_{k}"] = ("hips", pts)
    # Capelet rim (short, stiff).
    if len(cape):
        for k in range(8):
            a = k * 45.0 + 22.5
            pts = []
            for z in (1.39, 1.32, 1.25):
                r = _radius_at(cape, a, z) - 0.01
                pts.append(Vector((math.cos(math.radians(a)) * r, _centre_y(cape, z) + math.sin(math.radians(a)) * r, z)))
            chains[f"cape_{k}"] = ("chest", pts)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for prefix, (parent, pts) in chains.items():
        prev = eb[parent]
        for i in range(len(pts) - 1):
            b = eb.new(f"{prefix}_{i + 1}")
            b.head, b.tail, b.roll = pts[i], pts[i + 1], 0.0
            b.parent = prev
            prev = b
    bpy.ops.object.mode_set(mode="OBJECT")
    print("DYN CHAINS", {k: len(v[1]) - 1 for k, v in chains.items()})
    return chains


def _strip_groups(o, prefix, keep_if):
    """Remove weights of bones starting with `prefix` from vertices failing keep_if(co), renormalise."""
    me = o.data
    gidx = {g.index: g.name for g in o.vertex_groups}
    for v in me.vertices:
        if keep_if(v.co):
            continue
        tot = 0.0
        drop = []
        for g in v.groups:
            if gidx[g.group].startswith(prefix):
                drop.append(g.group)
            else:
                tot += g.weight
        for gi in drop:
            o.vertex_groups[gidx[gi]].remove([v.index])
        if drop and tot > 0:
            for g in v.groups:
                g.weight = g.weight / tot


def _select_only(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def _clear_skin(o):
    o.vertex_groups.clear()
    for m in list(o.modifiers):
        if m.type == "ARMATURE":
            o.modifiers.remove(m)


def _arm_mod(o, arm):
    m = o.modifiers.new("Armature", "ARMATURE")
    m.object = arm


def heat_skin_body(arm, body_objs, core, iterations=25):
    """Smooth anatomical weights on a connected, watertight proxy:
    seed with sharp nearest-bone weights, then diffuse across the surface
    (Laplacian smoothing) so joints get soft, wide blend zones like heat maps."""
    import lib_character as Lc
    segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones if b.name in core]
    names = [n for n, _, _ in segs]
    for o in body_objs:
        _clear_skin(o)
        me = o.data
        nv = len(me.vertices)
        co = np.array([v.co[:] for v in me.vertices])
        W = np.zeros((nv, len(segs)))
        for j, (n, h, t) in enumerate(segs):
            hh, tt = np.array(h[:]), np.array(t[:])
            ab = tt - hh
            tpar = np.clip(((co - hh) @ ab) / max(ab @ ab, 1e-9), 0, 1)
            d = np.linalg.norm(co - (hh + tpar[:, None] * ab), axis=1)
            W[:, j] = 1.0 / np.maximum(d, 0.004) ** 6
        W /= W.sum(axis=1, keepdims=True)
        # Graph Laplacian diffusion over mesh edges.
        e = np.array([ed.vertices[:] for ed in me.edges])
        deg = np.bincount(e.ravel(), minlength=nv).astype(float)
        deg[deg == 0] = 1
        for _ in range(iterations):
            acc = np.zeros_like(W)
            np.add.at(acc, e[:, 0], W[e[:, 1]])
            np.add.at(acc, e[:, 1], W[e[:, 0]])
            W = 0.5 * W + 0.5 * acc / deg[:, None]
        # Keep the 4 strongest influences, renormalise.
        idx = np.argsort(-W, axis=1)[:, :4]
        groups = [o.vertex_groups.new(name=n) for n in names]
        for i in range(nv):
            ww = W[i, idx[i]]
            ww = ww / ww.sum()
            for k in range(4):
                if ww[k] > 0.01:
                    groups[idx[i, k]].add([i], float(ww[k]), "REPLACE")
        print("SKIN", o.name, "verts", nv, "edges", len(e), "diffusion iters", iterations)


def transfer_skin(src, targets, arm):
    """Copy body weights onto clothing (nearest-surface interpolated)."""
    for o in targets:
        _clear_skin(o)
        for g in src.vertex_groups:
            o.vertex_groups.new(name=g.name)
        dt = o.modifiers.new("WeightXfer", "DATA_TRANSFER")
        dt.object = src
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        _select_only([o], o)
        bpy.ops.object.modifier_apply(modifier=dt.name)
        o.parent = arm
        _arm_mod(o, arm)
        _select_only([o], o)
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.01)
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        bpy.ops.object.mode_set(mode="OBJECT")


def blend_dynamic(o, arm, prefix, factor_fn, falloff=3.0):
    """Mix existing weights toward the nearest dynamic-chain bones by factor_fn(co) in 0..1."""
    import lib_character as Lc
    bones = [b for b in arm.data.bones if b.name.startswith(prefix)]
    if not bones:
        return
    segs = [(b.name, b.head_local.copy(), b.tail_local.copy()) for b in bones]
    for b in bones:
        if b.name not in o.vertex_groups:
            o.vertex_groups.new(name=b.name)
    gname = {g.index: g.name for g in o.vertex_groups}
    for v in o.data.vertices:
        f = factor_fn(v.co)
        if f <= 0.001:
            continue
        ds = sorted(((Lc._seg_dist(v.co, h, t), n) for n, h, t in segs))[:2]
        ws = [(1.0 / max(d, 0.01) ** falloff, n) for d, n in ds]
        tot = sum(w for w, _ in ws)
        for g in list(v.groups):
            o.vertex_groups[gname[g.group]].add([v.index], g.weight * (1 - f), "REPLACE")
        for w, n in ws:
            o.vertex_groups[n].add([v.index], w / tot * f, "ADD")


def _scale_groups(o, names, k):
    """Scale the given bone weights by k per vertex and renormalise."""
    gname = {g.index: g.name for g in o.vertex_groups}
    for v in o.data.vertices:
        ws = {gname[g.group]: g.weight for g in v.groups}
        if not any(n in ws for n in names):
            continue
        for n in names:
            if n in ws:
                ws[n] *= k
        tot = sum(ws.values())
        for n, w in ws.items():
            o.vertex_groups[n].add([v.index], w / tot, "REPLACE")


def _cuff_follow_hand(o, arm, J, reach=0.07, share=0.35):
    """Sleeve cuffs: blend part of the forearm weight to the hand near the opening
    so the cuff turns with the wrist instead of the hand rotating into it."""
    for sfx, sgn in (("L", 1), ("R", -1)):
        el = Vector((J["elbow"][0] * sgn, J["elbow"][1], J["elbow"][2]))
        wr = Vector((J["wrist"][0] * sgn, J["wrist"][1], J["wrist"][2]))
        d = (wr - el).normalized()
        fa, hd = f"forearm.{sfx}", f"hand.{sfx}"
        if fa not in o.vertex_groups:
            continue
        if hd not in o.vertex_groups:
            o.vertex_groups.new(name=hd)
        gi = o.vertex_groups[fa].index
        for v in o.data.vertices:
            w = next((g.weight for g in v.groups if g.group == gi), 0.0)
            if w <= 1e-4:
                continue
            u = (v.co - wr).dot(d)  # 0 at the wrist joint, negative toward the elbow
            f = _smooth01(-reach, 0.0, u) * share
            if f <= 0.0:
                continue
            o.vertex_groups[fa].add([v.index], w * (1 - f), "REPLACE")
            o.vertex_groups[hd].add([v.index], w * f, "ADD")


def _smooth01(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def relax_hands(body_objs, J, curl_deg=48.0, thumb_deg=18.0):
    """The base mesh has flat, spread T-pose hands. Curl the fingers gently
    toward the palm (more at the tips) so hands read relaxed and natural."""
    for sgn in (1, -1):
        wrist = Vector((J["wrist"][0] * sgn, J["wrist"][1], J["wrist"][2]))
        tip = Vector((J["hand_tip"][0] * sgn, J["hand_tip"][1], J["hand_tip"][2]))
        axis_d = (tip - wrist).normalized()
        hl = (tip - wrist).length
        P = np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in body_objs])
        rel = P - np.array(wrist[:])
        along = rel @ np.array(axis_d[:])
        hand = P[(along > -0.01) & (along < hl + 0.03) & (np.linalg.norm(rel - np.outer(along, axis_d[:]), axis=1) < 0.06)]
        cov = np.cov((hand - hand.mean(0)).T)
        w, vecs = np.linalg.eigh(cov)
        n = Vector(vecs[:, 0])  # smallest variance = palm normal
        if n.z > 0:
            n = -n                # palms face down-ish in the A-pose
        side = axis_d.cross(n).normalized()
        knuckle = wrist + axis_d * (hl * 0.42)
        for o in body_objs:
            for v in o.data.vertices:
                r = v.co - wrist
                a = r.dot(axis_d)
                if a < hl * 0.3 or a > hl + 0.04 or (r - axis_d * a).length > 0.06:
                    continue
                t = min(1.0, (a - hl * 0.3) / (hl * 0.75))
                ang = math.radians(curl_deg) * (t * t * (3 - 2 * t))
                # rotate about the knuckle line so fingers bend toward the palm
                piv = knuckle if a > hl * 0.42 else wrist + axis_d * a
                R = Matrix.Rotation(ang, 3, side)  # side = dir x palm-normal: tips move toward the palm
                v.co = piv + R @ (v.co - piv)
        print("HANDS relaxed side", sgn, "normal", tuple(round(c, 2) for c in n))


def run(root, mesh_objects, target_h):
    import build_characters as BC
    import lib_character as Lc
    objs = {o.name: o for o in mesh_objects()}
    body = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    J = measure_joints(body)
    import freyja_hands as FH
    hands = [FH.analyze(body, J, 1), FH.analyze(body, J, -1)]  # fingers stay straight at rest; Godot curls them
    Lc.J.update(J)
    spec = dict(BC.SPECS["freyja"])
    spec["height"] = Lc.BASE_H
    rig = Lc.Rig(spec)
    parts = accessories(objs, rig)
    # The staff is modelled vertical at the old grip; move it into the right
    # hand's palm and teach the staff poses the matching wrist orientation.
    right = hands[1]
    rig.grip_align = FH.grip_align(right)
    staff_obj = next(o for o, _, _ in rig.objects if o.name.startswith("Staff"))
    old_grip = rig.p("wrist", -1).lerp(rig.p("hand_tip", -1), 0.45)
    rig.staff_tip = FH.place_staff(staff_obj, rig.staff_tip, old_grip, right)
    arm = build_rig(J, [])  # hair is driven by dynamic chains (add_dynamic_chains)
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
    add_dynamic_chains(arm, objs)
    FH.add_bones(arm, hands)
    names = [b.name for b in arm.data.bones]
    dyn = lambda p: [n for n in names if n.startswith(p)]
    head_bits = ("Object_3_", "Object_4_", "FrierenEyes")
    core = [n for n in names if not n.startswith(("hair", "skirt_", "cape_", "eye.", "f_", "thumb_"))]
    skirt_bones = ["hips", "thigh.L", "thigh.R"] + dyn("skirt_")
    for n, o in objs.items():
        if n.startswith(head_bits):
            rig.add(o, rigid="head")
        elif n.startswith("Object_6_"):
            rig.add(o, allowed=["head"] + dyn("hairS_"))
        elif n.startswith("HairBackV3"):
            rig.add(o, allowed=["head", "neck"] + dyn("hairB_"))
        elif n.startswith(("Boots_", "Leggings_")):
            rig.add(o, allowed=["thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R", "hips"])
        elif n.startswith("Dress Skirt_M_Frieren_001_Skirt"):
            rig.add(o, allowed=skirt_bones)
        elif n.startswith("Dress Skirt_"):
            rig.add(o, allowed=core + dyn("cape_"))
        else:
            rig.add(o, allowed=core)
    for (o, bones) in parts:
        if bones is None:
            rig.add(o, rigid="head")
        elif o.name.startswith(("PlumPanels", "Petticoat")):
            rig.add(o, allowed=skirt_bones)
        else:
            rig.add(o, allowed=bones)
    for (o, _, _) in rig.objects:
        C.set_origin_world(o)
    Lc.skin_all(rig, falloff=5.0)
    for n, o in objs.items():
        if n.startswith("Object_6_"):
            _strip_groups(o, "hairS_", lambda co: co.z < 1.43 and abs(co.x) > 0.06)
    # Smooth, anatomical skinning: heat weights on a watertight voxel proxy of the
    # body, then transferred to the real body and to every piece of clothing.
    body_objs = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    proxy = body_objs[0].copy()
    proxy.data = body_objs[0].data.copy()
    proxy.name = "SkinProxy"
    bpy.context.scene.collection.objects.link(proxy)
    for o in body_objs[1:]:
        extra = o.copy()
        extra.data = o.data.copy()
        bpy.context.scene.collection.objects.link(extra)
        _select_only([proxy, extra], proxy)
        bpy.ops.object.join()
    _clear_skin(proxy)
    proxy.parent = None
    rm = proxy.modifiers.new("Remesh", "REMESH")
    rm.mode = "VOXEL"
    rm.voxel_size = 0.011
    _select_only([proxy], proxy)
    bpy.ops.object.modifier_apply(modifier=rm.name)
    dec = proxy.modifiers.new("Dec", "DECIMATE")
    dec.ratio = min(1.0, 30000 / max(len(proxy.data.polygons), 1))
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print("PROXY faces", len(proxy.data.polygons))
    heat_skin_body(arm, [proxy], core)
    # Delete body surface that clothing fully covers, so skin can never poke
    # through tights, dress or sleeves when joints bend.
    wrist_x = abs(J["wrist"][0])
    for n, o in objs.items():
        if not n.startswith("Body01_defaultMat_0"):
            continue
        bm = bmesh.new()
        bm.from_mesh(o.data)
        kill = []
        for v in bm.verts:
            x, z = abs(v.co.x), v.co.z
            legs = z < 0.9 and x < 0.2
            torso = 0.86 <= z < 1.33 and x < 0.17
            arms = 0.17 <= x < wrist_x - 0.035 and z > 0.85
            if legs or torso or arms:
                kill.append(v)
        bmesh.ops.delete(bm, geom=kill, context="VERTS")
        bm.to_mesh(o.data)
        bm.free()
        print("HIDDEN BODY removed", len(kill), "verts from", n)
    src = proxy
    transfer_skin(src, body_objs, arm)
    FH.weight(body_objs, arm, hands)
    cloth = [o for n, o in objs.items() if n.startswith(("Dress Skirt_", "Boots_", "Leggings_", "Panties_"))]
    cloth += [o for (o, bones) in parts if bones is not None]
    transfer_skin(src, cloth, arm)
    skirtish = [o for o in cloth if o.name.startswith(("Dress Skirt_M_Frieren_001_Skirt", "PlumPanels", "Petticoat"))]
    # One shared weighting function for every skirt layer so they never separate:
    # hips at the waist, easing into the near thigh lower down, then the cloth chains.
    for o in skirtish:
        _clear_skin(o)
        for n in ("hips", "thigh.L", "thigh.R"):
            o.vertex_groups.new(name=n)
        for v in o.data.vertices:
            leg = _smooth01(0.96, 0.6, v.co.z) * 0.4  # legs nudge the hem; springs + leg colliders do the rest
            side = 1.0 / (1.0 + math.exp(-v.co.x / 0.02))  # 1 = left
            o.vertex_groups["hips"].add([v.index], 1.0 - leg, "REPLACE")
            o.vertex_groups["thigh.L"].add([v.index], leg * side, "REPLACE")
            o.vertex_groups["thigh.R"].add([v.index], leg * (1.0 - side), "REPLACE")
        o.parent = arm
        _arm_mod(o, arm)
        blend_dynamic(o, arm, "skirt_", lambda co: _smooth01(0.97, 0.78, co.z) * 0.62)
    for o in cloth:
        if o.name.startswith("Dress Skirt_") and o not in skirtish:
            blend_dynamic(o, arm, "cape_", lambda co: _smooth01(0.2, 0.25, math.hypot(co.x, co.y)) * (1.0 if 1.2 < co.z < 1.42 else 0.0) * 0.8)
    # Torso-only pieces must not inherit arm weights (they tear at the armpits).
    torso_ok = {"hips", "spine", "chest", "neck", "shoulder.L", "shoulder.R"}
    restrict = {o.name: (set(bones) | torso_ok) for (o, bones) in parts if bones is not None}
    # Skirt layers keep the cloth-chain weights they share with the skirt;
    # stripping them made the petticoat follow the thighs and swing through it.
    chain_names = {b.name for b in arm.data.bones if b.name.startswith("skirt_")}
    for o in skirtish:
        if o.name in restrict:
            restrict[o.name] |= chain_names
    for o in cloth:
        if o.name.startswith("Dress Skirt_M_Frieren_002"):
            restrict[o.name] = torso_ok | {b.name for b in arm.data.bones if b.name.startswith("cape_")}
    for o in cloth:
        allowed = restrict.get(o.name)
        if not allowed:
            continue
        gname = {g.index: g.name for g in o.vertex_groups}
        for v in o.data.vertices:
            keep = [(g.group, g.weight) for g in v.groups if gname[g.group] in allowed]
            drop = [g.group for g in v.groups if gname[g.group] not in allowed]
            tot = sum(w for _, w in keep)
            for gi in drop:
                o.vertex_groups[gname[gi]].remove([v.index])
            if tot <= 1e-4:
                tgt = "chest" if v.co.z > 1.05 else "hips"
                if tgt not in o.vertex_groups:
                    o.vertex_groups.new(name=tgt)
                o.vertex_groups[tgt].add([v.index], 1.0, "REPLACE")
            else:
                for gi, w in keep:
                    o.vertex_groups[gname[gi]].add([v.index], w / tot, "REPLACE")
    for o in cloth:
        if o.name.startswith("Dress Skirt_M_Frieren_001_0"):
            _cuff_follow_hand(o, arm, J)
    bpy.data.objects.remove(proxy, do_unlink=True)
    for o in cloth:
        _select_only([o], o)
        bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    for o in eye_objs:
        o.vertex_groups.clear()
        gl, gr = o.vertex_groups.new(name="eye.L"), o.vertex_groups.new(name="eye.R")
        gl.add([v.index for v in o.data.vertices if v.co.x > 0], 1.0, "REPLACE")
        gr.add([v.index for v in o.data.vertices if v.co.x <= 0], 1.0, "REPLACE")
    import freyja_face
    freyja_face.build(arm, objs, rig)
    # Neutral, Freyja-specific names in the shipped asset.
    renames = {"FrierenIris": "M_Eye_Iris_freyja", "FrierenSclera": "M_Eye_White_freyja", "FrierenBoots": "M_Outfit_Sleeves_freyja",
               "M_Frieren_001_Skirt": "M_Outfit_Skirt_freyja", "M_Frieren_001_Glass": "M_Outfit_Gem_freyja", "M_Frieren_001": "M_Outfit_A_freyja",
               "M_Frieren_002": "M_Outfit_B_freyja", "defaultMat": "M_Skin_freyja", "eyelashes_and_stuff": "M_Hair_freyja",
               "Leggings": "M_Tights_freyja", "Panties": "M_Under_freyja", "Teeth": "M_Teeth_freyja", "Tongue": "M_Tongue_freyja"}
    for m in bpy.data.materials:
        if m.name in renames:
            m.name = renames[m.name]
    for o, _, _ in rig.objects:
        o.name = o.name.replace("Frieren", "Freyja").replace("Dress Skirt", "Outfit")
    for i, img in enumerate(list(bpy.data.images)):
        if not img.name.startswith("freyja_tex"):
            img.name = f"freyja_tex_{i}"
    tip = bpy.data.objects.new("StaffTip", None)
    bpy.context.scene.collection.objects.link(tip)
    tip.parent = arm
    tip.parent_type = "BONE"
    tip.parent_bone = "hand.R"
    bpy.context.view_layer.update()
    tip.matrix_world = Matrix.Translation(rig.staff_tip)
    anim = Lc.Animator(rig)
    import mocap_retarget as MR
    MR.GRIP_ALIGN = rig.grip_align
    mocap = os.path.join(root, "art", "source", "mocap")
    speeds = MR.retarget_clips(arm, [
        ("Walk", "07_01.bvh", {"lean": 4.0}),
        ("Run", "09_02.bvh", {"lean": 9.0}),
        ("WalkStaff", "07_01.bvh", {"hold_right": 0.55, "staff": True, "staff_tilt": 6, "lean": 4.0}),
        ("RunStaff", "09_02.bvh", {"hold_right": 0.5, "staff": True, "staff_tilt": 30, "lean": 9.0})], mocap)
    import json
    with open(os.path.join(root, "game", "data", "characters", "freyja_locomotion.json"), "w") as fh:
        json.dump({"natural_speed": speeds, "source": "CMU Graphics Lab Motion Capture Database (mocap.cs.cmu.edu)"}, fh, indent=1)
    for (aname, frames, fn, loop) in BC.ANIMS["mage"]:
        if aname in speeds:
            continue
        anim.action(aname, frames, fn, loop)
    anim.reset()
    objs_out = [arm] + [o for o, _, _ in rig.objects] + [tip]
    C.export_glb(os.path.join(root, "game", "assets", "models", "characters", "freyja.glb"), objs_out)
    ad = arm.animation_data
    for tr in ad.nla_tracks:
        tr.mute = True
    anim.reset()
    bpy.context.view_layer.update()
    prev = os.path.join(root, "art", "previews", "freyja_v3_full.png")
    C.render_preview(prev, objs_out, views=((0, "front"), (35, "tq"), (90, "side"), (180, "back")),
                     height=target_h * 1.12, look_z=target_h * 0.55, size=(1800, 900))
    for (aname, frames, fn, loop) in BC.ANIMS["mage"]:
        act = bpy.data.actions.get(aname)
        bpy.context.scene.frame_set(0)
        ad.action = act
        try:
            if act.slots:
                ad.action_slot = act.slots[0]
        except AttributeError:
            pass
        bpy.context.scene.frame_set(int(frames * (0.5 if aname == "Cast" else 0.42 if aname.startswith("Summon") else 0.25)))
        C.render_preview(prev.replace(".png", f"_pose_{aname}.png"), objs_out, views=((30, "q"),),
                         height=target_h * 1.25, look_z=target_h * 0.55, size=(400, 900))
    ad.action = None
    # Hand close-ups (rest pose and idle).
    anim.reset()
    bpy.context.view_layer.update()
    C.render_preview(os.path.join(root, "art", "previews", "freyja_hand_rest.png"), objs_out, views=((0, "f"), (90, "s")),
                     height=0.28, look_z=J["wrist"][2] - 0.04, look_x=-J["wrist"][0] - 0.04, size=(800, 400), elevation=10)
    ad.action = bpy.data.actions.get("Idle")
    try:
        ad.action_slot = ad.action.slots[0]
    except Exception:
        pass
    bpy.context.scene.frame_set(30)
    hb = arm.pose.bones["hand.L"]
    hp = arm.matrix_world @ hb.head
    C.render_preview(os.path.join(root, "art", "previews", "freyja_hand_idle.png"), objs_out, views=((20, "f"), (100, "s")),
                     height=0.3, look_z=hp.z - 0.06, look_x=hp.x, size=(800, 400), elevation=10)
    ad.action = None
    anim.reset()
    # Face key previews (rest pose).
    keyed = [o for o, _, _ in rig.objects if o.type == "MESH" and o.data.shape_keys]
    for tag, vals in (("neutral", {}), ("blink", {"blink": 1}), ("half", {"blink": 0.5}), ("squint", {"squint": 1, "mouth_smile": 1}),
                      ("talk", {"mouth_open": 1}), ("oh", {"mouth_o": 1, "brow_up": 1})):
        for o in keyed:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = vals.get(kb.name, 0.0)
        C.render_preview(os.path.join(root, "art", "previews", f"freyja_face_{tag}.png"), objs_out, views=((0, "f"),),
                         height=0.3, look_z=1.5, size=(420, 420), elevation=2)
    for o in keyed:
        for kb in o.data.shape_keys.key_blocks[1:]:
            kb.value = 0.0
    print("BUILT freyja v3", sum(len(o.data.polygons) for o, _, _ in rig.objects), "faces")
