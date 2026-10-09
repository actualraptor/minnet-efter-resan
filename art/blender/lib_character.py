"""Scripted stylised humanoid characters: body (skin modifier), anime face,
hair, layered clothing, accessories, armature, weights and animations.

Conventions: Blender Z-up, characters face -Y (exports as glTF +Z forward).
Joints are authored for a 1.68 m adult and scaled per character spec."""
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

import lib_common as C

BASE_H = 1.68

# Joint positions for the base adult (left side; right mirrors X).
J = {
    "pelvis": (0, 0.0, 0.95), "spine": (0, 0.005, 1.10), "chest": (0, 0.0, 1.27),
    "neck_base": (0, 0.01, 1.42), "neck_top": (0, 0.005, 1.505),
    "shoulder_in": (0.03, 0.0, 1.405), "shoulder": (0.165, 0.01, 1.395),
    "elbow": (0.325, 0.03, 1.19), "wrist": (0.44, 0.0, 1.005), "hand_tip": (0.49, -0.012, 0.925),
    "thumb": (0.455, -0.045, 0.955),
    "hip": (0.085, 0.0, 0.925), "knee": (0.095, -0.012, 0.52), "ankle": (0.10, 0.02, 0.095),
    "toe": (0.10, -0.115, 0.03),
}

BONES = [
    # name, head, tail, parent
    ("hips", (0, 0, 0.925), (0, 0, 1.06), None),
    ("spine", (0, 0, 1.06), (0, 0, 1.25), "hips"),
    ("chest", (0, 0, 1.25), (0, 0, 1.42), "spine"),
    ("neck", (0, 0.005, 1.42), (0, 0.0, 1.51), "chest"),
    ("head", (0, 0.0, 1.51), (0, 0.0, 1.76), "neck"),
    ("shoulder.L", "shoulder_in", "shoulder", "chest"),
    ("upper_arm.L", "shoulder", "elbow", "shoulder.L"),
    ("forearm.L", "elbow", "wrist", "upper_arm.L"),
    ("hand.L", "wrist", "hand_tip", "forearm.L"),
    ("thigh.L", "hip", "knee", "hips"),
    ("shin.L", "knee", "ankle", "thigh.L"),
    ("foot.L", "ankle", "toe", "shin.L"),
]
HAIR_BONES = [
    ("hair.1", (0, 0.10, 1.66), (0, 0.14, 1.42), "head"),
    ("hair.2", (0, 0.14, 1.42), (0, 0.16, 1.18), "hair.1"),
    ("hair.3", (0, 0.16, 1.18), (0, 0.17, 0.94), "hair.2"),
    ("hair.4", (0, 0.17, 0.94), (0, 0.17, 0.64), "hair.3"),
]


class Rig:
    def __init__(self, spec):
        self.spec = spec
        self.s = spec["height"] / BASE_H
        self.objects = []          # (object, allowed_bones or None, rigid_bone or None)
        self.arm = None

    # -- coordinates ----------------------------------------------------------
    def p(self, key_or_xyz, side=1):
        v = J[key_or_xyz] if isinstance(key_or_xyz, str) else key_or_xyz
        return Vector((v[0] * side * self.s, v[1] * self.s, v[2] * self.s))

    def head_center(self):
        hs = self.spec.get("head_scale", 1.0)
        hc = Vector((0, -0.005, 1.505 + 0.112 * hs)) * 1.0
        return Vector((0, -0.005 * self.s, 1.505 * self.s + 0.112 * hs * self.s))

    def head_radii(self):
        hs = self.spec.get("head_scale", 1.0) * self.s
        r = self.spec.get("head_radii", (0.097, 0.104, 0.116))
        return Vector((r[0] * hs, r[1] * hs, r[2] * hs))

    def add(self, ob, allowed=None, rigid=None):
        self.objects.append((ob, allowed, rigid))
        return ob


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

def build_body(rig):
    sp = rig.spec
    s = rig.s
    w = sp.get("body_width", 1.0)
    bm = bmesh.new()
    verts = {}

    def v(name, key, side=1):
        verts[name] = bm.verts.new(rig.p(key, side))
        return verts[name]

    v("pelvis", "pelvis"); v("spine", "spine"); v("chest", "chest")
    v("neck_base", "neck_base"); v("neck_top", "neck_top")
    edges = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck_base"), ("neck_base", "neck_top")]
    for side, sfx in ((1, "L"), (-1, "R")):
        for k in ("shoulder_in", "shoulder", "elbow", "wrist", "hand_tip", "thumb", "hip", "knee", "ankle", "toe"):
            v(f"{k}.{sfx}", k, side)
        edges += [("neck_base", f"shoulder_in.{sfx}"), (f"shoulder_in.{sfx}", f"shoulder.{sfx}"),
                  (f"shoulder.{sfx}", f"elbow.{sfx}"), (f"elbow.{sfx}", f"wrist.{sfx}"),
                  (f"wrist.{sfx}", f"hand_tip.{sfx}"), (f"wrist.{sfx}", f"thumb.{sfx}"),
                  ("pelvis", f"hip.{sfx}"), (f"hip.{sfx}", f"knee.{sfx}"),
                  (f"knee.{sfx}", f"ankle.{sfx}"), (f"ankle.{sfx}", f"toe.{sfx}")]
    for a, b in edges:
        bm.edges.new((verts[a], verts[b]))
    me = bpy.data.meshes.new("Body")
    bm.to_mesh(me)
    order = [vv.index for vv in bm.verts]
    names = list(verts.keys())
    bm.free()
    ob = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("Skin", "SKIN")
    mod.use_smooth_shade = True
    radii = sp.get("radii", {})
    base = {
        "pelvis": (0.125, 0.095), "spine": (0.10, 0.08), "chest": (0.118, 0.085),
        "neck_base": (0.055, 0.05), "neck_top": (0.042, 0.042),
        "shoulder_in": (0.06, 0.05), "shoulder": (0.048, 0.045), "elbow": (0.034, 0.034),
        "wrist": (0.025, 0.022), "hand_tip": (0.022, 0.012), "thumb": (0.012, 0.012),
        "hip": (0.085, 0.08), "knee": (0.05, 0.05), "ankle": (0.042, 0.045), "toe": (0.04, 0.03),
    }
    base.update(radii)
    for i, n in enumerate(names):
        key = n.split(".")[0]
        r = base[key]
        wx = w if key in ("pelvis", "spine", "chest", "hip") else 1.0
        me.skin_vertices[0].data[i].radius = (r[0] * s * wx, r[1] * s)
        me.skin_vertices[0].data[i].use_root = (n == "pelvis")
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    C.apply_all_modifiers(ob)
    # Materials by region.
    cols = sp["colors"]
    mats = [C.mat("M_Skin_" + sp["name"], cols["skin"], 0.6),
            C.mat("M_Torso_" + sp["name"], cols.get("torso", cols["skin"]), 0.8),
            C.mat("M_Sleeve_" + sp["name"], cols.get("sleeve", cols["skin"]), 0.8),
            C.mat("M_Legs_" + sp["name"], cols.get("legs", cols["skin"]), 0.8),
            C.mat("M_Boots_" + sp["name"], cols.get("boots", "#6b4a32"), 0.7)]
    for m in mats:
        ob.data.materials.append(m)
    boot_top = sp.get("boot_top", 0.30) * s
    sleeve_end = sp.get("sleeve_end", 0.97)  # fraction along forearm toward wrist
    wrist_x = J["wrist"][0] * s
    for poly in ob.data.polygons:
        c = poly.center
        if c.z < boot_top:
            poly.material_index = 4
        elif c.z < 0.95 * s and abs(c.x) < 0.2 * s:
            poly.material_index = 3
        elif abs(c.x) > 0.13 * s and c.z > 0.85 * s:
            # Arm: sleeve until near the wrist, then skin (hands).
            poly.material_index = 2 if abs(c.x) < wrist_x * sleeve_end else 0
        elif c.z > 1.43 * s:
            poly.material_index = 0
        else:
            poly.material_index = 1
    rig.add(ob, allowed=[b[0] for b in BONES] + [b[0].replace(".L", ".R") for b in BONES if ".L" in b[0]])
    return ob


# ---------------------------------------------------------------------------
# Head & face
# ---------------------------------------------------------------------------

def _on_head(rig, x, z, lift=0.0):
    """Point and outward normal on the (front of the) head ellipsoid."""
    c = rig.head_center()
    r = rig.head_radii()
    nx = x / r.x
    nz = (z - c.z) / r.z
    t = max(0.0, 1.0 - nx * nx - nz * nz)
    y = c.y - r.y * math.sqrt(t)
    p = Vector((x, y, z))
    n = Vector(((p.x - c.x) / (r.x ** 2), (p.y - c.y) / (r.y ** 2), (p.z - c.z) / (r.z ** 2))).normalized()
    return p + n * lift, n


def _decal(rig, name, x, z, w, h, material, lift=0.0015, thickness=0.003, tilt=0.0, segs=14):
    p, n = _on_head(rig, x, z, lift)
    ob = C.ellipsoid(name, (0, 0, 0), (w, thickness, h), material, segs=segs, rings=6)
    q = Vector((0, -1, 0)).rotation_difference(n)
    rot = q.to_matrix().to_4x4() @ Matrix.Rotation(tilt, 4, "Y")
    for v in ob.data.vertices:
        v.co = (rot @ v.co.to_4d()).to_3d() + p
    return ob


def build_head(rig):
    sp = rig.spec
    cols = sp["colors"]
    c = rig.head_center()
    r = rig.head_radii()
    skin = C.mat("M_Skin_" + sp["name"], cols["skin"], 0.6)
    head = C.ellipsoid("Head", c, r, skin, segs=24, rings=16)
    # Anime jaw: taper the lower face to a soft point, flatten cheeks slightly.
    for v in head.data.vertices:
        dz = (v.co.z - c.z) / r.z
        if dz < 0.15:
            k = min(1.0, (0.15 - dz) / 1.15)
            v.co.x *= 1.0 - 0.38 * k
            if v.co.y < c.y:
                v.co.y = c.y + (v.co.y - c.y) * (1.0 - 0.12 * k)
        if v.co.y < c.y and dz > -0.2:
            v.co.y = c.y + (v.co.y - c.y) * 0.96
    rig.add(head, rigid="head")
    hs = sp.get("head_scale", 1.0) * rig.s
    eye_z = c.z - 0.012 * hs
    ex = 0.036 * hs * sp.get("eye_spacing", 1.0)
    es = sp.get("eye_size", 1.0) * hs
    white = C.mat("M_Eye_White", "#fbf7ef", 0.4)
    iris = C.mat("M_Eye_Iris_" + sp["name"], cols["eyes"], 0.3)
    pupil = C.mat("M_Eye_Pupil", "#1d1825", 0.3)
    shine = C.mat("M_Eye_Shine", "#ffffff", 0.2)
    lash = C.mat("M_Eye_Lash", cols.get("lash", "#3a2a3e"), 0.5)
    brow = C.mat("M_Hair_Brow_" + sp["name"], cols.get("brow", cols["hair"]), 0.6)
    mouth = C.mat("M_Eye_Mouth", cols.get("mouth", "#b0646b"), 0.5)
    parts = []
    for side in (1, -1):
        x = ex * side
        parts.append(_decal(rig, "EyeW", x, eye_z, 0.021 * es, 0.019 * es, white, 0.001))
        if sp.get("eyes_closed_smile"):
            arc = [_on_head(rig, x + 0.018 * es * t, eye_z + 0.006 * es * (1 - t * t), 0.004)[0] for t in (-1, -0.5, 0, 0.5, 1)]
            parts.append(C.tube("Lash", arc, [0.0025 * es] * 5, lash, segs=5))
            parts.pop(-2)
            continue
        parts.append(_decal(rig, "Iris", x - 0.002 * side * es, eye_z - 0.001 * es, 0.0145 * es, 0.0175 * es, iris, 0.0028))
        parts.append(_decal(rig, "Pupil", x - 0.002 * side * es, eye_z - 0.002 * es, 0.0065 * es, 0.0085 * es, pupil, 0.0042))
        parts.append(_decal(rig, "Shine", x + 0.004 * side * es, eye_z + 0.007 * es, 0.0038 * es, 0.0042 * es, shine, 0.0055))
        # Upper lash line, thicker at the outer corner.
        arc = []
        for t in (-1.05, -0.5, 0.0, 0.5, 1.1):
            arc.append(_on_head(rig, x + 0.021 * es * t * side, eye_z + 0.017 * es * (1 - 0.35 * t * t) + 0.002, 0.004)[0])
        parts.append(C.tube("Lash", arc, [0.0018 * es, 0.0026 * es, 0.0028 * es, 0.003 * es, 0.0036 * es], lash, segs=5))
        # Brow
        barc = [_on_head(rig, x + 0.02 * es * t * side, eye_z + 0.04 * es + 0.004 * (1 - t * t) * es, 0.004)[0] for t in (-0.9, 0, 0.9)]
        parts.append(C.tube("Brow", barc, [0.0016 * es, 0.0024 * es, 0.0012 * es], brow, segs=5))
        if sp.get("glasses"):
            ring = [_on_head(rig, x + math.cos(a) * 0.024 * es, eye_z + math.sin(a) * 0.022 * es, 0.012)[0]
                    for a in [i * math.tau / 14 for i in range(15)]]
            parts.append(C.tube("Glasses", ring, [0.0018] * len(ring), C.mat("M_Glasses", "#b89a5a", 0.3, 0.6), segs=4, caps=False))
    mz = c.z - 0.072 * hs
    marc = [_on_head(rig, 0.009 * hs * t, mz + 0.0025 * hs * (t * t), 0.002)[0] for t in (-1, 0, 1)]
    if sp.get("smile", 0.0) > 0:
        marc = [_on_head(rig, 0.011 * hs * t, mz - 0.003 * hs * (1 - t * t) * sp["smile"], 0.002)[0] for t in (-1, -0.5, 0, 0.5, 1)]
    parts.append(C.tube("Mouth", marc, [0.0016 * hs] * len(marc), mouth, segs=5))
    nose = _on_head(rig, 0.0, c.z - 0.042 * hs, -0.003)[0]
    parts.append(C.ellipsoid("Nose", nose, (0.004 * hs, 0.005 * hs, 0.008 * hs), skin, segs=8, rings=5))
    if sp.get("blush"):
        bl = C.mat("M_Blush", "#f0a8a8", 0.6)
        for side in (1, -1):
            parts.append(_decal(rig, "Blush", 0.05 * hs * side, eye_z - 0.03 * hs, 0.012 * hs, 0.006 * hs, bl, 0.0012))
    if sp.get("freckles"):
        fm = C.mat("M_Freckle", "#c78a62", 0.6)
        for side in (1, -1):
            for (fx, fz) in ((0.035, -0.033), (0.045, -0.028), (0.028, -0.038), (0.05, -0.036)):
                parts.append(_decal(rig, "Freckle", fx * hs * side, eye_z + fz * hs, 0.0022 * hs, 0.0022 * hs, fm, 0.0016, segs=6))
    if sp.get("wrinkles"):
        wm = C.mat("M_Eye_Wrinkle", "#b98e7c", 0.6)
        for side in (1, -1):
            x = ex * side
            for k in range(2):
                arc = [_on_head(rig, x + side * (0.026 + 0.004 * k) * es, eye_z + (t * 0.009 - 0.004 * k) * es, 0.002)[0] for t in (-1, 0, 1)]
                parts.append(C.tube("Wrinkle", arc, [0.0009] * 3, wm, segs=4))
    face = C.join(parts, "Face")
    rig.add(face, rigid="head")
    # Ears
    ear_type = sp.get("ears", "human")
    ears = []
    for side in (1, -1):
        base = Vector((r.x * 0.93 * side, c.y + 0.012 * hs, c.z - 0.005 * hs))
        if ear_type == "elf":
            tip = base + Vector((0.115 * hs * side, 0.035 * hs, 0.085 * hs))
            mid = base.lerp(tip, 0.45) + Vector((0.0, 0.004, -0.008))
            ears.append(C.tube("Ear", [base, mid, tip], [0.024 * hs, 0.017 * hs, 0.0005], skin, segs=8,
                               flatten=0.32, flat_axis=(0.25 * side, -1.0, 0.0)))
        else:
            ears.append(C.ellipsoid("Ear", base + Vector((0.006 * side, 0.004, 0)), (0.012 * hs, 0.018 * hs, 0.026 * hs), skin, segs=8, rings=6))
    rig.add(C.join(ears, "Ears"), rigid="head")


# ---------------------------------------------------------------------------
# Hair styles
# ---------------------------------------------------------------------------

def _hair_cap(rig, hair, front_cut=0.035, back_low=-0.6):
    c = rig.head_center()
    r = rig.head_radii()
    cap = C.ellipsoid("HairCap", c + Vector((0, 0.008, 0.012)), (r.x * 1.09, r.y * 1.10, r.z * 1.07), hair, segs=24, rings=16)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    kill = []
    for v in bm.verts:
        dz = (v.co.z - c.z) / r.z
        front = v.co.y < c.y - r.y * 0.25
        if front and dz < front_cut / r.z * 1.0 + 0.25:
            kill.append(v)
        elif dz < back_low:
            kill.append(v)
        elif v.co.y < c.y + r.y * 0.1 and dz < -0.15:
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(cap.data)
    bm.free()
    return cap


def _strand(rig, name, root, tip, mid_push, r0, hair, flat_axis=(0, -1, 0), flatten=0.4, segs=7):
    pts = []
    for i in range(6):
        t = i / 5
        p = root.lerp(tip, t) + Vector(mid_push) * math.sin(t * math.pi)
        pts.append(p)
    radii = [r0 * (1 - 0.85 * (i / 5) ** 1.3) for i in range(6)]
    radii[-1] = r0 * 0.05
    return C.tube(name, pts, radii, hair, segs=segs, flatten=flatten, flat_axis=flat_axis)


def build_hair(rig):
    sp = rig.spec
    style = sp.get("hair_style", "long")
    hair = C.mat("M_Hair_" + sp["name"], sp["colors"]["hair"], 0.55)
    c = rig.head_center()
    r = rig.head_radii()
    hs = sp.get("head_scale", 1.0) * rig.s
    head_parts = [_hair_cap(rig, hair)]
    # Bangs across the forehead.
    n_bangs = sp.get("bangs", 7)
    for i in range(n_bangs):
        t = (i / (n_bangs - 1)) * 2 - 1
        x = t * r.x * 0.78
        root, _ = _on_head(rig, x * 0.6, c.z + r.z * 0.78, 0.012)
        length = 0.075 + 0.02 * (1 - abs(t)) * (1 if i % 2 else 0.6)
        tip, _ = _on_head(rig, x * 1.05 + 0.01 * t, c.z + r.z * 0.78 - length * hs, 0.016)
        head_parts.append(_strand(rig, "Bang", root, tip, (0, -0.012, 0), 0.02 * hs, hair, flatten=0.35))
    rig.add(C.join(head_parts, "HairHead"), rigid="head")

    if style == "long":
        # Side locks framing the face, down to the chest.
        locks = []
        for side in (1, -1):
            root = Vector((r.x * 0.95 * side, c.y - r.y * 0.25, c.z + r.z * 0.35))
            tip = Vector((0.115 * rig.s * side, -0.06 * rig.s, 1.24 * rig.s))
            locks.append(_strand(rig, "Lock", root, tip, (0.025 * side, -0.01, 0), 0.03 * hs, hair,
                                 flat_axis=(side, 0.4, 0), flatten=0.4))
        rig.add(C.join(locks, "HairLocks"), allowed=["head", "neck", "chest"])
        # Back curtain: a full, layered fall of hair to below the waist.
        back = []
        for layer, (count, depth, length, thick) in enumerate(((15, 0.8, 0.86, 0.064), (11, 0.6, 0.98, 0.058))):
            for i in range(count):
                t = (i / (count - 1)) * 2 - 1
                wav = math.sin(i * 2.3 + layer) * 0.02
                root = Vector((t * r.x * 0.9, c.y + r.y * depth, c.z + r.z * (0.35 - 0.1 * layer) - abs(t) * 0.04 * hs))
                tip = Vector((t * (0.17 + 0.03 * layer) * rig.s + wav, (0.16 - 0.02 * layer) * rig.s - abs(t) * 0.02,
                              (length + abs(t) * 0.07 + wav) * rig.s))
                back.append(_strand(rig, "Back", root, tip, (0.012 * t, 0.06, 0), (thick - abs(t) * 0.012) * hs, hair,
                                    flat_axis=(0, 1, 0), flatten=0.4, segs=8))
        rig.add(C.join(back, "HairBack"), allowed=["head", "hair.1", "hair.2", "hair.3"])
        # Crown braid wrapping from the left temple round the back of the head.
        braid = []
        n = 16
        for k in range(n):
            a = math.radians(160 - k * 13.5)
            p = c + Vector((math.cos(a) * r.x * 1.07, math.sin(a) * r.y * 1.07 + 0.01 * hs, r.z * (0.42 - 0.12 * math.sin(k / n * math.pi))))
            off = Vector((0, 0, 0.008 * hs * (1 if k % 2 else -1)))
            braid.append(C.ellipsoid("Braid", p + off, (0.019 * hs, 0.019 * hs, 0.014 * hs), hair, segs=8, rings=6))
        # Flower ornament and ribbon at the left temple, like a pressed keepsake.
        fpos = c + Vector((r.x * 0.98, r.y * 0.1, r.z * 0.5))
        petal = C.mat("M_HairFlower", "#fbf6ea", 0.6)
        for k in range(5):
            a = k * math.tau / 5
            braid.append(C.ellipsoid("HairPetal", fpos + Vector((0.006, math.cos(a) * 0.02, math.sin(a) * 0.02)) * hs / max(hs, 1e-6),
                                     (0.006, 0.016, 0.016), petal, segs=8, rings=4))
        braid.append(C.ellipsoid("HairFlowerC", fpos + Vector((0.012, 0, 0)), (0.006, 0.009, 0.009), C.mat("M_HairFlowerCentre", "#e8b84a", 0.5), segs=8, rings=4))
        leafm = C.mat("M_HairLeaf", "#6d9a52", 0.7)
        for k, a in enumerate((2.4, 3.6)):
            braid.append(C.ellipsoid("HairLeaf", fpos + Vector((0.002, math.cos(a) * 0.03, math.sin(a) * 0.03)), (0.004, 0.012, 0.022), leafm, segs=6, rings=4))
        rib = C.mat("M_Plum_Ribbon", "#7b4f7a", 0.7)
        rp = fpos + Vector((0.0, 0.03, -0.02))
        braid.append(C.tube("HairRibbon", [rp, rp + Vector((0.01, 0.02, -0.07)), rp + Vector((0.015, 0.03, -0.14))], [0.011, 0.01, 0.006], rib, segs=5, flatten=0.3, flat_axis=(1, 0, 0)))
        braid.append(C.tube("HairRibbon2", [rp, rp + Vector((0.005, 0.045, -0.05)), rp + Vector((0.01, 0.06, -0.11))], [0.011, 0.01, 0.006], rib, segs=5, flatten=0.3, flat_axis=(1, 0, 0)))
        rig.add(C.join(braid, "HairBraid"), rigid="head")
    elif style == "bun":
        bun_c = c + Vector((0, r.y * 0.75, r.z * 0.55))
        bun = C.ellipsoid("Bun", bun_c, (0.055 * hs, 0.05 * hs, 0.05 * hs), hair, segs=14, rings=10)
        C.displace_noise(bun, 0.004, 4.0, 3)
        pin = C.cylinder("Pin", bun_c + Vector((-0.07 * hs, 0, 0.01)), bun_c + Vector((0.07 * hs, 0.01, 0.03)), 0.003,
                         material=C.mat("M_Pin", "#d8b25a", 0.3, 0.7), segs=6)
        rig.add(C.join([bun, pin], "HairBun"), rigid="head")
    elif style == "pigtails":
        tails = []
        for side in (1, -1):
            tie = Vector((r.x * 0.92 * side, c.y + r.y * 0.35, c.z - r.z * 0.05))
            tails.append(C.ellipsoid("Tie", tie, (0.016 * hs, 0.016 * hs, 0.016 * hs), C.mat("M_Tie_" + sp["name"], sp["colors"].get("accent", "#d06a5a"), 0.6), segs=10, rings=6))
            tip = tie + Vector((0.07 * hs * side, 0.03 * hs, -0.17 * hs))
            tails.append(_strand(rig, "Tail", tie, tip, (0.03 * side, 0.02, 0), 0.035 * hs, hair, flat_axis=(side, 0, 0), flatten=0.6, segs=8))
        rig.add(C.join(tails, "HairTails"), rigid="head")


# ---------------------------------------------------------------------------
# Clothing / accessories
# ---------------------------------------------------------------------------

def _scaled_profile(rig, prof):
    return [(r * rig.s, z * rig.s) for (r, z) in prof]


def trim_ring(rig, name, r, z, sy, material, skip=None, segs=40, thick=0.007):
    pts = []
    for i in range(segs + 1):
        a = 2 * math.pi * i / segs
        if skip is not None:
            da = (math.degrees(a) - skip[0] + 180) % 360 - 180
            if abs(da) < skip[1]:
                continue
        pts.append(Vector((math.cos(a) * r * rig.s, math.sin(a) * r * rig.s * sy, z * rig.s)))
    if skip is not None:
        # rotate list so the gap is at the ends
        gap_i = 0
        for i in range(1, len(pts)):
            if (pts[i] - pts[i - 1]).length > 0.05 * rig.s:
                gap_i = i
        pts = pts[gap_i:] + pts[:gap_i]
    return C.tube(name, pts, [thick * rig.s] * len(pts), material, segs=5, caps=skip is not None)


def ruffle(ob, z_below, amp_r, amp_z, freq, center=(0.0, 0.0)):
    """Wavy, frilled hem: displaces vertices below z_below radially and vertically."""
    for v in ob.data.vertices:
        if v.co.z < z_below:
            dx, dy = v.co.x - center[0], v.co.y - center[1]
            a = math.atan2(dy, dx)
            k = min(1.0, (z_below - v.co.z) / 0.06)
            w = math.sin(a * freq)
            rr = math.hypot(dx, dy)
            if rr > 1e-5:
                f = 1.0 + (amp_r * w * k) / rr
                v.co.x = center[0] + dx * f
                v.co.y = center[1] + dy * f
            v.co.z += amp_z * w * k


def outfit_mage(rig):
    sp = rig.spec
    cl = sp["colors"]
    s = rig.s
    cream = C.mat("M_Cream_" + sp["name"], cl["cream"], 0.85)
    sage = C.mat("M_Tunic_" + sp["name"], cl["tunic"], 0.8)
    mantle = C.mat("M_Mantle_" + sp["name"], cl["mantle"], 0.8)
    plum = C.mat("M_Plum_" + sp["name"], cl["plum"], 0.7)
    gold = C.mat("M_Gold", "#d8b25a", 0.35, 0.8)
    leather = C.mat("M_Leather", "#7a5236", 0.65)
    torso_bones = ["hips", "spine", "chest", "thigh.L", "thigh.R"]
    under = C.lathe("Underdress", _scaled_profile(rig, [(0.108, 1.12), (0.14, 0.95), (0.19, 0.76), (0.25, 0.56), (0.275, 0.5), (0.28, 0.485)]),
                    64, cream, scale_xy=(1.0, 0.8))
    ruffle(under, 0.56 * s, 0.018 * s, 0.014 * s, 14)
    rig.add(under, allowed=torso_bones)
    lining = C.lathe("SkirtLining", _scaled_profile(rig, [(0.112, 1.1), (0.15, 0.95), (0.2, 0.76), (0.252, 0.6), (0.262, 0.555)]),
                     56, plum, scale_xy=(1.0, 0.8), skip_angle=(270.0, 30.0, 0.98 * s))
    ruffle(lining, 0.6 * s, 0.012 * s, 0.01 * s, 10)
    rig.add(lining, allowed=torso_bones)
    open_front = (270.0, 24.0, 1.02 * s)
    tunic = C.lathe("Tunic", _scaled_profile(rig, [(0.066, 1.47), (0.11, 1.44), (0.136, 1.38), (0.138, 1.29), (0.124, 1.16),
                                                   (0.119, 1.08), (0.156, 0.95), (0.20, 0.78), (0.238, 0.62)]),
                    32, sage, scale_xy=(1.0, 0.8), skip_angle=open_front)
    rig.add(tunic, allowed=torso_bones + ["neck"])
    trims = [trim_ring(rig, "HemTrim", 0.239, 0.62, 0.8, gold, skip=(270.0, 26.0)),
             trim_ring(rig, "WaistTrim", 0.122, 1.095, 0.8, plum, thick=0.016)]
    # Vertical trims along the coat opening.
    for side in (1, -1):
        pts = []
        for z in (1.02, 0.95, 0.86, 0.76, 0.68, 0.62):
            # radius at z by interpolation of tunic profile
            prof = [(0.119, 1.08), (0.156, 0.95), (0.20, 0.78), (0.238, 0.62)]
            for k in range(len(prof) - 1):
                if prof[k + 1][1] <= z <= prof[k][1]:
                    t = (prof[k][1] - z) / (prof[k][1] - prof[k + 1][1])
                    rr = prof[k][0] + (prof[k + 1][0] - prof[k][0]) * t
                    break
            else:
                rr = 0.12
            a = math.radians(270 + 24 * side)
            pts.append(Vector((math.cos(a) * rr * s, math.sin(a) * rr * s * 0.8, z * s)))
        trims.append(C.tube("EdgeTrim", pts, [0.006 * s] * len(pts), gold, segs=5))
    buckle = C.box("Buckle", (0, -0.1 * s, 1.095 * s), (0.028 * s, 0.01 * s, 0.024 * s), gold, bevel=0.003)
    rig.add(C.join(trims + [buckle], "Trims"), allowed=torso_bones)
    # Short mantle / capelet over the shoulders.
    cape = C.lathe("Mantle", _scaled_profile(rig, [(0.058, 1.465), (0.085, 1.455), (0.165, 1.425), (0.222, 1.365), (0.236, 1.30)]),
                   36, mantle, scale_xy=(1.0, 0.86))
    cape_trim = trim_ring(rig, "MantleTrim", 0.237, 1.30, 0.86, gold, thick=0.008)
    clasp = C.ellipsoid("Clasp", (0, -0.075 * s, 1.44 * s), (0.017 * s, 0.008 * s, 0.017 * s), gold, segs=10, rings=6)
    gem = C.ellipsoid("ClaspGem", (0, -0.084 * s, 1.44 * s), (0.009 * s, 0.006 * s, 0.011 * s),
                      C.mat("M_Crystal_Glow", "#5fe0a8", 0.1, emit=1.5), segs=8, rings=6)
    rig.add(C.join([cape, cape_trim, clasp, gem], "MantleSet"), allowed=["chest", "neck", "shoulder.L", "shoulder.R", "spine"])
    # Wrist cuffs.
    cuffs = []
    for side in (1, -1):
        e = rig.p("elbow", side)
        w = rig.p("wrist", side)
        a = e.lerp(w, 0.55)
        b = e.lerp(w, 0.93)
        cuffs.append(C.tube("Cuff", [a, b], [0.036 * s, 0.05 * s], sage, segs=12, caps=False))
        cuffs.append(C.tube("CuffTrim", [b - (b - a).normalized() * 0.006, b], [0.051 * s, 0.051 * s], gold, segs=12))
    rig.add(C.join(cuffs, "Cuffs"), allowed=["forearm.L", "forearm.R", "hand.L", "hand.R"])
    # Puffed cream upper sleeves.
    puffs = []
    for side in (1, -1):
        sh = rig.p("shoulder", side)
        el = rig.p("elbow", side)
        mid = sh.lerp(el, 0.45)
        pf = C.tube("Puff", [sh.lerp(el, 0.05), mid, sh.lerp(el, 0.85)], [0.052 * s, 0.062 * s, 0.04 * s], cream, segs=12)
        C.displace_noise(pf, 0.004 * s, 6.0, 5)
        puffs.append(pf)
        puffs.append(C.tube("PuffBand", [sh.lerp(el, 0.82), sh.lerp(el, 0.9)], [0.043 * s, 0.043 * s], plum, segs=12))
    rig.add(C.join(puffs, "Sleeves"), allowed=["upper_arm.L", "upper_arm.R", "shoulder.L", "shoulder.R", "forearm.L", "forearm.R"])
    # Satchel on the right hip with a strap across the chest.
    sat_c = Vector((-0.175 * s, 0.0, 0.9 * s))
    satchel = C.box("Satchel", sat_c, (0.035 * s, 0.065 * s, 0.055 * s), leather, bevel=0.012 * s)
    flap = C.box("Flap", sat_c + Vector((-0.036 * s, 0, 0.03 * s)), (0.006 * s, 0.067 * s, 0.035 * s), C.mat("M_LeatherDark", "#5a3b27", 0.6), bevel=0.004)
    strap_pts = [Vector((0.1, -0.095, 1.40)), Vector((0.02, -0.125, 1.27)), Vector((-0.08, -0.12, 1.12)),
                 Vector((-0.15, -0.07, 0.99)), Vector((-0.17, 0.0, 0.95))]
    strap = C.tube("Strap", [p * s for p in strap_pts], [0.007 * s] * 5, leather, segs=4, flatten=0.35, flat_axis=(0, -1, 0))
    back_pts = [Vector((0.1, 0.07, 1.41)), Vector((0.0, 0.11, 1.27)), Vector((-0.1, 0.1, 1.1)), Vector((-0.17, 0.04, 0.96))]
    strap2 = C.tube("Strap2", [p * s for p in back_pts], [0.007 * s] * 4, leather, segs=4, flatten=0.35, flat_axis=(0, 1, 0))
    rig.add(C.join([satchel, flap, strap, strap2], "Satchel"), allowed=["hips", "spine", "chest"])
    # Boot cuffs.
    bc = []
    for side in (1, -1):
        k = rig.p("knee", side)
        a = rig.p("ankle", side)
        p = k.lerp(a, 0.25)
        bc.append(C.tube("BootCuff", [p + Vector((0, 0, -0.02)), p + Vector((0, 0, 0.035))], [0.054 * s, 0.062 * s],
                         C.mat("M_Boots_" + sp["name"], sp["colors"]["boots"], 0.7), segs=12))
    rig.add(C.join(bc, "BootCuffs"), allowed=["shin.L", "shin.R"])


def outfit_elder(rig):
    sp = rig.spec
    cl = sp["colors"]
    s = rig.s
    dress = C.mat("M_Dress_" + sp["name"], cl["dress"], 0.85)
    apron = C.mat("M_Apron_" + sp["name"], cl["apron"], 0.85)
    shawl = C.mat("M_Shawl_" + sp["name"], cl["shawl"], 0.95)
    torso_bones = ["hips", "spine", "chest", "thigh.L", "thigh.R"]
    body = C.lathe("Dress", _scaled_profile(rig, [(0.06, 1.47), (0.11, 1.43), (0.14, 1.36), (0.145, 1.25), (0.135, 1.12),
                                                  (0.16, 0.98), (0.2, 0.78), (0.24, 0.5), (0.25, 0.2), (0.25, 0.17)]),
                   32, dress, scale_xy=(1.0, 0.85))
    rig.add(body, allowed=torso_bones + ["neck"])
    ap = C.lathe("Apron", _scaled_profile(rig, [(0.142, 1.13), (0.168, 0.98), (0.208, 0.78), (0.247, 0.5), (0.255, 0.32)]),
                 32, apron, scale_xy=(1.0, 0.87), skip_angle=(90.0, 110.0, 2.0))
    rig.add(ap, allowed=torso_bones)
    sh = C.lathe("Shawl", _scaled_profile(rig, [(0.062, 1.47), (0.095, 1.455), (0.17, 1.42), (0.222, 1.33), (0.218, 1.21)]),
                 32, shawl, scale_xy=(1.0, 0.9))
    C.displace_noise(sh, 0.003 * s, 6.0, 1)
    knot = C.ellipsoid("Knot", (0, -0.15 * s, 1.31 * s), (0.03 * s, 0.02 * s, 0.025 * s), shawl, segs=10, rings=6)
    tails = [C.tube("ShawlTail", [Vector((0.01 * sd, -0.16, 1.30)) * s, Vector((0.03 * sd, -0.17, 1.2)) * s, Vector((0.035 * sd, -0.165, 1.12)) * s],
                    [0.02 * s, 0.022 * s, 0.012 * s], shawl, segs=6, flatten=0.4, flat_axis=(0, 1, 0)) for sd in (1, -1)]
    rig.add(C.join([sh, knot] + tails, "ShawlSet"), allowed=["chest", "neck", "shoulder.L", "shoulder.R", "spine"])


def outfit_child(rig):
    sp = rig.spec
    cl = sp["colors"]
    s = rig.s
    pin = C.mat("M_Pinafore_" + sp["name"], cl["pinafore"], 0.85)
    torso_bones = ["hips", "spine", "chest", "thigh.L", "thigh.R"]
    dress = C.lathe("Pinafore", _scaled_profile(rig, [(0.085, 1.41), (0.125, 1.37), (0.13, 1.30), (0.128, 1.15), (0.14, 1.02), (0.19, 0.85), (0.22, 0.68), (0.222, 0.66)]),
                    32, pin, scale_xy=(1.0, 0.85))
    rig.add(dress, allowed=torso_bones)
    pocket = C.box("Pocket", (0.06 * s, -0.17 * s, 0.86 * s), (0.04 * s, 0.006 * s, 0.035 * s), C.mat("M_Pocket", cl.get("accent", "#d06a5a"), 0.8), bevel=0.004)
    book = C.box("FactBook", (-0.06 * s, -0.175 * s, 0.86 * s), (0.03 * s, 0.01 * s, 0.04 * s), C.mat("M_Book_Pippa", "#6c8fb5", 0.7), bevel=0.003)
    rig.add(C.join([pocket, book], "Pocket"), allowed=["hips", "spine"])
    collar = trim_ring(rig, "Collar", 0.052, 1.49, 0.9, C.mat("M_Cream_" + sp["name"], "#f6f0e2", 0.8), thick=0.012)
    rig.add(collar, allowed=["chest", "neck"])


def staff(rig, length=1.72, kind="staff"):
    """Staff (or cane) gripped in the right hand, weighted rigidly to hand.R."""
    s = rig.s
    grip = rig.p("wrist", -1).lerp(rig.p("hand_tip", -1), 0.45)
    wood = C.mat("M_Wood_Staff", "#7a5536", 0.7)
    gold = C.mat("M_Gold", "#d8b25a", 0.35, 0.8)
    parts = []
    if kind == "staff":
        bottom = grip + Vector((0, 0, -0.86 * s))
        top = grip + Vector((0, 0, (length - 0.86) * s))
        shaft_pts = [bottom.lerp(top, t) + Vector((0.006 * math.sin(t * 9), 0.004 * math.cos(t * 7), 0)) for t in [i / 8 for i in range(9)]]
        parts.append(C.tube("Shaft", shaft_pts, [0.014 * s] + [0.017 * s] * 7 + [0.021 * s], wood, segs=8))
        crystal_c = top + Vector((0, 0, 0.12 * s))
        cr = C.ellipsoid("Crystal", crystal_c, (0.04 * s, 0.04 * s, 0.1 * s), C.mat("M_Crystal_Glow", "#5fe0a8", 0.1, emit=1.5), segs=6, rings=4)
        for v in cr.data.vertices:
            # Faceted, pointed ends.
            dz = (v.co.z - crystal_c.z) / (0.1 * s)
            k = 1.0 - abs(dz) ** 1.5 * 0.6
            v.co.x = crystal_c.x + (v.co.x - crystal_c.x) * k
            v.co.y = crystal_c.y + (v.co.y - crystal_c.y) * k
        parts.append(cr)
        for i in range(3):
            a = i * math.tau / 3 + 0.4
            pts = []
            for t in [k / 6 for k in range(7)]:
                rr = (0.02 + 0.045 * math.sin(t * math.pi * 0.9)) * s
                aa = a + t * 1.4
                pts.append(top + Vector((math.cos(aa) * rr, math.sin(aa) * rr, (t * 0.24 - 0.02) * s)))
            parts.append(C.tube("Prong", pts, [0.012 * s * (1 - 0.8 * t) for t in [k / 6 for k in range(7)]], wood, segs=6))
        parts.append(C.tube("Ring", [top + Vector((0, 0, -0.02 * s)), top + Vector((0, 0, 0.015 * s))], [0.022 * s, 0.022 * s], gold, segs=10))
        parts.append(C.tube("Ring2", [grip + Vector((0, 0, 0.22 * s)), grip + Vector((0, 0, 0.245 * s))], [0.02 * s, 0.02 * s], gold, segs=10))
        glow = C.mat("M_Crystal_Glow", "#5fe0a8", 0.1, emit=1.5)
        chain = C.mat("M_Gold", "#d8b25a", 0.35, 0.8)
        for i in range(3):
            a = i * math.tau / 3 + 1.0
            hang = top + Vector((math.cos(a) * 0.05 * s, math.sin(a) * 0.05 * s, 0.03 * s))
            low = hang + Vector((0, 0, -(0.07 + 0.03 * i) * s))
            parts.append(C.tube("DangleChain", [hang, low], [0.0025, 0.0025], chain, segs=4))
            d = C.ellipsoid("Dangle", low + Vector((0, 0, -0.03 * s)), (0.012 * s, 0.012 * s, 0.032 * s), glow, segs=6, rings=4)
            parts.append(d)
        leafm = C.mat("M_StaffLeaf", "#7fae5a", 0.7)
        for i in range(3):
            a = i * 2.1 + 0.3
            lp = top + Vector((math.cos(a) * 0.035 * s, math.sin(a) * 0.035 * s, 0.05 * s))
            parts.append(C.ellipsoid("StaffLeaf", lp + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0.01)), (0.012 * s, 0.03 * s, 0.006 * s), leafm, segs=6, rings=4))
        rib = C.mat("M_Plum_Ribbon", "#7b4f7a", 0.7)
        rp = top + Vector((0, 0, -0.06 * s))
        parts.append(C.tube("Ribbon", [rp, rp + Vector((0.02, 0.03, -0.08)) * s, rp + Vector((0.01, 0.05, -0.2)) * s],
                            [0.012 * s, 0.01 * s, 0.006 * s], rib, segs=5, flatten=0.3, flat_axis=(1, 0, 0)))
        rig.staff_tip = crystal_c
    else:
        bottom = grip + Vector((0, -0.02, -0.86 * s))
        top = grip + Vector((0, 0, 0.06 * s))
        parts.append(C.tube("Cane", [bottom, top], [0.013 * s, 0.015 * s], C.mat("M_Wood_Cane", "#5e3f2a", 0.6), segs=8))
        parts.append(C.tube("CaneHandle", [top, top + Vector((0, -0.05, 0.03)) * s, top + Vector((0, -0.09, 0.0)) * s],
                            [0.016 * s, 0.016 * s, 0.014 * s], C.mat("M_Wood_Cane", "#5e3f2a", 0.6), segs=8))
        rig.staff_tip = top
    ob = C.join(parts, "Staff" if kind == "staff" else "Cane")
    rig.add(ob, rigid="hand.R")


# ---------------------------------------------------------------------------
# Armature & weights
# ---------------------------------------------------------------------------

def build_armature(rig):
    s = rig.s
    arm_data = bpy.data.armatures.new("Armature")
    arm = bpy.data.objects.new("Armature", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    defs = list(BONES)
    for name, h, t, parent in BONES:
        if ".L" in name:
            defs.append((name.replace(".L", ".R"), h, t, parent.replace(".L", ".R") if parent and ".L" in parent else parent))
    if rig.spec.get("hair_style", "long") in ("long", "long2"):
        defs += HAIR_BONES
    created = {}
    for name, h, t, parent in defs:
        side = -1 if name.endswith(".R") else 1
        b = eb.new(name)
        b.head = rig.p(h, side)
        b.tail = rig.p(t, side)
        b.roll = 0.0
        created[name] = b
    for name, h, t, parent in defs:
        if parent:
            created[name].parent = created[parent]
            created[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.arm = arm
    # Head/hair positions depend on head_scale: shift head-attached bones.
    return arm


def _seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def skin_all(rig, falloff=4.0, max_inf=3):
    arm = rig.arm
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
    for ob, allowed, rigid in rig.objects:
        ob.parent = arm
        mod = ob.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        if rigid:
            g = ob.vertex_groups.new(name=rigid)
            g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
            continue
        bones = [b for b in (allowed or segs.keys()) if b in segs]
        groups = {b: ob.vertex_groups.new(name=b) for b in bones}
        for v in ob.data.vertices:
            p = v.co
            ws = []
            for b in bones:
                d = _seg_dist(p, *segs[b])
                ws.append((1.0 / (max(d, 0.004) ** falloff), b))
            ws.sort(reverse=True)
            ws = ws[:max_inf]
            tot = sum(w for w, _ in ws)
            for w, b in ws:
                if w / tot > 0.02:
                    groups[b].add([v.index], w / tot, "REPLACE")


# ---------------------------------------------------------------------------
# Animation helpers
# ---------------------------------------------------------------------------

def _q_arm(pb, rx=0.0, ry=0.0, rz=0.0):
    R = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()
    M = pb.bone.matrix_local.to_3x3()
    return (M.inverted() @ R @ M).to_quaternion()


class Animator:
    def __init__(self, rig):
        self.rig = rig
        self.arm = rig.arm
        self.pb = self.arm.pose.bones
        for p in self.pb:
            p.rotation_mode = "QUATERNION"
        if self.arm.animation_data is None:
            self.arm.animation_data_create()
        self.base = {}

    def names(self):
        return [p.name for p in self.pb]

    def reset(self):
        for p in self.pb:
            p.matrix_basis = Matrix.Identity(4)

    def rot(self, bone, rx=0.0, ry=0.0, rz=0.0):
        if bone in self.pb:
            self.pb[bone].rotation_quaternion = _q_arm(self.pb[bone], rx, ry, rz)

    def hips_offset(self, dz=0.0, dy=0.0):
        pb = self.pb["hips"]
        M = pb.bone.matrix_local.to_3x3()
        pb.location = M.inverted() @ Vector((0, dy, dz))

    def staff_upright(self, tilt_x=0.0, tilt_y=0.0):
        """Orient hand.R so the gripped staff/cane points up, tilted slightly."""
        if not getattr(self.rig, "staff_tip", None) or "hand.R" not in self.pb:
            return
        bpy.context.view_layer.update()
        pb = self.pb["hand.R"]
        rest = pb.bone.matrix_local.to_3x3()
        R = Euler((math.radians(tilt_x), math.radians(tilt_y), 0), "XYZ").to_matrix()
        loc = pb.matrix.translation.copy()
        pb.matrix = Matrix.Translation(loc) @ (R @ rest).to_4x4()
        bpy.context.view_layer.update()

    def key(self, frame):
        for p in self.pb:
            p.keyframe_insert("rotation_quaternion", frame=frame, group=p.name)
            if p.name == "hips":
                p.keyframe_insert("location", frame=frame, group=p.name)

    def action(self, name, frames, pose_fn, loop=True):
        act = bpy.data.actions.new(name)
        self.arm.animation_data.action = act
        n = frames
        last = n if loop else n
        for f in range(0, last + 1):
            self.reset()
            t = (f % n) / n if loop else f / n
            pose_fn(self, t, f)
            self.key(f)
        # Linear interpolation keeps sampled curves faithful.
        try:
            for fc in act.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
        except AttributeError:
            pass
        track = self.arm.animation_data.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, act)
        strip.name = name
        self.arm.animation_data.action = None
        return act


def smooth_pulse(t, a, b):
    if t <= a:
        return 0.0
    if t >= b:
        return 1.0
    x = (t - a) / (b - a)
    return x * x * (3 - 2 * x)


def lerp(a, b, t):
    return a + (b - a) * t
