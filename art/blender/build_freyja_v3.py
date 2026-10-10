"""Freyja v3: built on a CC-BY-4.0 anime base model, turned into Freyja.

Base: "Frieren — 3D Anime Character Model" by SammyCAnimations (Sketchfab),
CC-BY-4.0. We keep only generic parts (body, head, face, hair cap and bangs)
and change everything that identifies the original character: the twin-tails
become long loose hair with a flower circlet, the white/gold outfit and
striped shirt are recoloured to Freyja's sage/cream/plum, the staff is
replaced, and Freyja's own accessories are added. The base file stays out of
git (art/source/ is ignored); only the derived, credited result is shipped.

    blender -b --factory-startup --python art/blender/build_freyja_v3.py -- <repo_root> [stage]
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_common as C  # noqa: E402

ROOT = os.path.abspath(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else os.getcwd()
SRC = os.path.join(ROOT, "art", "source", "base_model", "base.glb")
TARGET_H = 1.68

KEEP_PREFIX = ("Body01_defaultMat_0", "Boots_", "Leggings_", "Panties_Panties_0", "Dress Skirt_",
               "Object_3_", "Object_4_", "Object_6_", "Object_7_", "FrierenEyes_FrierenIris_0_")

SAGE = np.array([0.56, 0.68, 0.49])
SAGE_DARK = np.array([0.42, 0.53, 0.38])
CREAM = np.array([0.94, 0.9, 0.82])


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lin_to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.clip(c, 0, None) ** (1 / 2.4) - 0.055)


def image_np(img):
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    return a


def set_image(img, a):
    img.pixels.foreach_set(a.astype(np.float32).ravel())
    img.pack()


def recolor_cloth(img, white_to, stripes=True):
    """White cloth -> white_to (keeps shading); gold trim untouched; dark stripes
    sitting inside white areas are painted over so the shirt is plain."""
    a = image_np(img)
    rgb = a[..., :3]  # Blender stores linear float pixels for 8-bit images? treat as display values
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    white = (lum > 0.55) & (sat < 0.12)
    if stripes:
        # Dark, unsaturated pixels whose neighbourhood is mostly white are stripes.
        dark = (lum < 0.35) & (sat < 0.15)
        k = 27
        pad = np.pad(white.astype(np.float32), k, mode="edge")
        acc = np.zeros_like(lum)
        for dy in range(-k, k + 1, 9):
            for dx in range(-k, k + 1, 9):
                acc += pad[k + dy:k + dy + lum.shape[0], k + dx:k + dx + lum.shape[1]]
        acc /= ((2 * k) // 9 + 1) ** 2
        stripe = dark & (acc > 0.35)
        rgb[stripe] = np.array([0.93, 0.93, 0.93])
        lum = rgb.mean(axis=2)
        white = white | stripe
    red = (rgb[..., 0] > 0.18) & (rgb[..., 0] > rgb[..., 1] * 2.4) & (rgb[..., 0] > rgb[..., 2] * 2.4)
    # Gem centres are a duller red inside teal rims; a looser test would catch
    # reddish leather, so only accept it right next to teal gem pixels.
    teal = (rgb[..., 1] > rgb[..., 0] * 1.5) & (rgb[..., 2] > rgb[..., 0] * 1.2) & (rgb[..., 1] > 0.2)
    near = teal.copy()
    for _ in range(8):
        near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
    red |= near & (rgb[..., 0] > 0.15) & (rgb[..., 0] > rgb[..., 1] * 1.4) & (rgb[..., 0] > rgb[..., 2] * 1.25)
    rgb[red] = np.stack([rgb[red][:, 0] * 0.25, rgb[red][:, 0] * 0.95, rgb[red][:, 0] * 0.8], axis=1)
    shade = np.clip(lum / 0.92, 0.55, 1.05)
    rgb[white] = white_to[None, :] * shade[white][:, None]
    a[..., :3] = rgb
    set_image(img, a)


def tint_image(img, color, strength=1.0):
    a = image_np(img)
    lum = a[..., :3].mean(axis=2, keepdims=True)
    a[..., :3] = a[..., :3] * (1 - strength) + lum * color[None, None, :] * 1.6 * strength
    set_image(img, a)


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def world_bbox(o):
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    return Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb))), Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))


def apply_transforms(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def decimate(o, ratio):
    if ratio >= 1.0:
        return
    m = o.modifiers.new("Dec", "DECIMATE")
    m.ratio = ratio
    m.use_collapse_triangulate = False
    # Keep the head (face, ears, hair cap) at full detail: decimate only below the neck.
    if any(v.co.z > 1.38 for v in o.data.vertices):
        g = o.vertex_groups.new(name="_decimate")
        g.add([v.index for v in o.data.vertices if v.co.z < 1.36], 1.0, "REPLACE")
        m.vertex_group = g.name
        m.vertex_group_factor = 1.0
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=m.name)
    if "_decimate" in o.vertex_groups:
        o.vertex_groups.remove(o.vertex_groups["_decimate"])


def load_and_clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    # Unparent everything and keep only the dressed copy's generic parts.
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        keep = o.type == "MESH" and o.name.startswith(KEEP_PREFIX) and ".001" not in o.name.split("_0")[0]
        if keep:
            mn, mx = world_bbox(o)
            keep = (mn.x + mx.x) / 2 < 0.35
        if not keep:
            bpy.data.objects.remove(o, do_unlink=True)
    objs = mesh_objects()
    apply_transforms(objs)
    # Normalise: feet on the ground, centred, scaled to Freyja's height.
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in objs:
        a, b = world_bbox(o)
        mn = Vector(map(min, mn, a))
        mx = Vector(map(max, mx, b))
    s = TARGET_H / (mx.z - mn.z)
    for o in objs:
        o.location = (-(mn.x + mx.x) / 2 * s, -0.0 * s, -mn.z * s)
        o.scale = (s, s, s)
    bpy.context.view_layer.update()
    for o in objs:
        o.location.x += 0.0
    apply_transforms(objs)
    print("SCALED by", round(s, 3), "height", round(TARGET_H, 3))
    return {o.name: o for o in mesh_objects()}


def find(objs, prefix):
    for n, o in objs.items():
        if n.startswith(prefix):
            return o
    return None


def recolor(objs):
    done = set()
    for o in objs.values():
        for m in o.data.materials:
            if not m or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type != "TEX_IMAGE" or not n.image or n.image.name in done:
                    continue
                img = n.image
                done.add(img.name)
                if m.name in ("M_Frieren_001", "M_Frieren_001_Skirt", "M_Frieren_002"):
                    if m.name != "M_Frieren_002":
                        # Paint out the shirt-panel bars (lower-left of this atlas) before tinting.
                        a = image_np(img)
                        h, w = a.shape[:2]
                        reg = a[int(h * 0.05):int(h * 0.45), :int(w * 0.42), :3]
                        lum = reg.mean(axis=2)
                        sat = reg.max(axis=2) - reg.min(axis=2)
                        bars = (lum < 0.4) & (sat < 0.15)
                        # only bars inside the white panel (not the black background)
                        col_white = (reg.mean(axis=2) > 0.7).mean(axis=0) > 0.2
                        bars &= col_white[None, :]
                        reg[bars] = 0.95
                        a[int(h * 0.05):int(h * 0.45), :int(w * 0.42), :3] = reg
                        set_image(img, a)
                    recolor_cloth(img, SAGE)
                elif m.name == "FrierenBoots":
                    recolor_cloth(img, CREAM)
                    a = image_np(img)
                    h, w = a.shape[:2]
                    reg = a[int(h * 0.42):, int(w * 0.2):int(w * 0.8), :3]
                    lum = reg.mean(axis=2)
                    sat = reg.max(axis=2) - reg.min(axis=2)
                    m2 = (sat < 0.3) & ~((reg[..., 0] > reg[..., 2] + 0.12) & (reg[..., 1] > reg[..., 2]))  # keep gold
                    shade = np.clip(0.75 + lum * 0.3, 0.8, 1.02)
                    reg[m2] = CREAM[None, :] * shade[m2][:, None]
                    a[int(h * 0.42):, int(w * 0.2):int(w * 0.8), :3] = reg
                    set_image(img, a)
                elif m.name == "FrierenIris":
                    tint_image(img, np.array([0.18, 0.62, 0.52]), 0.85)
        if m := (o.data.materials[0] if o.data.materials else None):
            if m.name == "Leggings":
                bsdf = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
                if bsdf:
                    for lk in list(bsdf.inputs["Base Color"].links) + list(bsdf.inputs["Emission Color"].links):
                        m.node_tree.links.remove(lk)
                    bsdf.inputs["Base Color"].default_value = (0.035, 0.025, 0.03, 1)
                    bsdf.inputs["Emission Strength"].default_value = 0.0
                    bsdf.inputs["Roughness"].default_value = 0.85
            if m.name == "M_Frieren_001_Glass" and m.use_nodes:
                bsdf = m.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    for lk in list(bsdf.inputs["Base Color"].links):
                        m.node_tree.links.remove(lk)
                    bsdf.inputs["Base Color"].default_value = (0.08, 0.6, 0.45, 1)
                    m.diffuse_color = (0.08, 0.6, 0.45, 1)  # workbench previews


def _hair_colour(cap):
    """Median lit colour of the hair cap's texture under its UVs (so new strands match)."""
    m = cap.data.materials[0]
    img = next((n.image for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None) if m.use_nodes else None
    if img is None:
        return np.array([0.78, 0.76, 0.86])
    a = image_np(img)
    h, w = a.shape[:2]
    uv = np.array([d.uv[:] for d in cap.data.uv_layers.active.data])
    px = a[np.clip((uv[:, 1] * h).astype(int), 0, h - 1), np.clip((uv[:, 0] * w).astype(int), 0, w - 1), :3]
    lum = px.mean(1)
    px = px[lum > np.percentile(lum, 40)]
    return np.median(px, axis=0)


def _strand_texture(base):
    """Anime strand texture: lengthwise streaks, darker root, soft lighter tips."""
    W, H = 128, 512
    rng = np.random.default_rng(7)
    u = np.linspace(0, 1, W)
    streak = np.zeros(W)
    for f, amp in ((7, 0.06), (17, 0.05), (41, 0.035)):
        streak += amp * np.sin(u * math.tau * f + rng.uniform(0, math.tau))
    lines = np.zeros(W)
    for c in rng.uniform(0.08, 0.92, 9):
        lines -= 0.09 * np.exp(-((u - c) / 0.012) ** 2)
    v = np.linspace(0, 1, H)[:, None]                      # 0 = root (bottom row), 1 = tip
    shade = 0.86 + 0.14 * np.clip(v * 1.6, 0, 1) + streak[None, :] + lines[None, :]
    edge = 1.0 - 0.18 * np.abs(u * 2 - 1)[None, :] ** 3   # strand edges a touch darker
    rgb = np.clip(base[None, None, :] * (shade * edge)[..., None], 0, 1)
    a = np.ones((H, W, 4), np.float32)
    a[..., :3] = rgb
    img = bpy.data.images.new("freyja_hair_strands", W, H)
    set_image(img, a)
    return img


def _hair_material(cap):
    base = _hair_colour(cap)
    mat = bpy.data.materials.new("M_HairLong_freyja")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = _strand_texture(base)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    mat.diffuse_color = (float(base[0]), float(base[1]), float(base[2]), 1.0)
    return mat


def _strand(bm, uvl, pts, outward, half_w, half_t, segs=8):
    """Lens-section strand along pts, flat against the `outward` normals; UV u across, v along."""
    L = [0.0]
    for i in range(1, len(pts)):
        L.append(L[-1] + (pts[i] - pts[i - 1]).length)
    rings = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = (outward[i] - d * outward[i].dot(d)).normalized()
        side = d.cross(nrm).normalized()
        ring = []
        for k in range(segs):
            a = math.tau * k / segs
            ring.append(bm.verts.new(p + side * math.cos(a) * half_w[i] + nrm * math.sin(a) * half_t[i]))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(segs):
            f = bm.faces.new((rings[j][k], rings[j][(k + 1) % segs], rings[j + 1][(k + 1) % segs], rings[j + 1][k]))
            for loop, (kk, jj) in zip(f.loops, ((k, j), (k + 1, j), (k + 1, j + 1), (k, j + 1))):
                uu = 1.0 - abs((kk / segs) * 2 - 1)
                loop[uvl].uv = (uu, L[jj] / L[-1])
    tip = bm.verts.new(pts[-1] + (pts[-1] - pts[-2]).normalized() * 0.004)
    for k in range(segs):
        f = bm.faces.new((rings[-1][k], rings[-1][(k + 1) % segs], tip))
        for loop in f.loops:
            loop[uvl].uv = (0.5, 1.0)


def _smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def generate_hair(objs):
    """Long loose hair (Freyja's sheet): strands rooted under the back of the hair
    cap that drape over the skull, shoulders and capelet and then hang, in two
    overlapping layers so there are no gaps. Replaces the twin-tails."""
    tails = find(objs, "Object_7_")
    if tails is not None:
        bpy.data.objects.remove(tails, do_unlink=True)
    cap = find(objs, "Object_6_")
    drape_src = [o for o in mesh_objects() if o.name.startswith(("Body01_", "Dress Skirt_", "Leggings_", "Panties_", "Object_6_"))]
    def pts_of(o):
        q = np.array([o.matrix_world @ v.co for v in o.data.vertices])
        if o.name.startswith("Body01_"):
            q = q[~((q[:, 2] > 1.42) & (np.abs(q[:, 0]) > 0.075))]   # elf ears: hair falls behind them
        return q
    P = np.concatenate([pts_of(o) for o in drape_src])
    # Hair drapes over head, shoulders and torso, never along the A-posed arms.
    P = P[(np.abs(P[:, 0]) < 0.2) | (P[:, 2] > 1.47)]
    torso = P[(np.abs(P[:, 2] - 1.15) < 0.1) & (np.abs(P[:, 0]) < 0.18)]
    cy = float(np.percentile(torso[:, 1], 3) + np.percentile(torso[:, 1], 97)) / 2
    Q = P - np.array([0.0, cy, 0.0])
    ang = np.degrees(np.arctan2(Q[:, 1], Q[:, 0])) % 360
    rad = np.hypot(Q[:, 0], Q[:, 1])
    capP = np.array([cap.matrix_world @ v.co for v in cap.data.vertices]) - np.array([0.0, cy, 0.0])
    cap_ang = np.degrees(np.arctan2(capP[:, 1], capP[:, 0])) % 360
    cap_rad = np.hypot(capP[:, 0], capP[:, 1])
    # Outer surface radius on a (z, angle) grid around the torso axis.
    zs = np.arange(0.5, 1.75, 0.015)
    angs = np.arange(0, 360, 4.0)
    S = np.zeros((len(zs), len(angs)))
    for i, z in enumerate(zs):
        mz = np.abs(P[:, 2] - z) < 0.018
        za, zr = ang[mz], rad[mz]
        for j, a in enumerate(angs):
            m = np.abs(((za - a) + 180) % 360 - 180) < 7
            S[i, j] = np.percentile(zr[m], 97) if m.sum() > 3 else 0.0

    def surf(z, a):
        i = int(np.clip(round((z - zs[0]) / 0.015), 0, len(zs) - 1))
        j = int(round((a % 360) / 4.0)) % len(angs)
        return S[i, j]

    mat = _hair_material(cap)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rng = np.random.default_rng(3)
    BACK = 90.0
    layers = ((20, 100.0, 0.004, 0.0), (19, 92.0, 0.015, 0.5))   # (count, half-spread deg, clearance, phase)
    for (count, spread, clear, phase) in layers:
        for k in range(count):
            t = (k + phase) / (count - 1 + (1 if phase else 0))
            a0 = BACK + (t * 2 - 1) * spread
            off_c = abs(a0 - BACK) / spread                       # 0 at the centre, 1 at the sides
            z_root = 1.575 - 0.085 * off_c ** 1.4
            mr = (np.abs(capP[:, 2] - z_root) < 0.015) & (np.abs(((cap_ang - a0) + 180) % 360 - 180) < 8)
            r_root = float(np.percentile(cap_rad[mr], 60)) - 0.012 if mr.sum() > 3 else surf(z_root, a0) - 0.012
            z_end = 0.7 + 0.12 * off_c ** 1.6 + rng.uniform(-0.03, 0.03)
            pts, outs = [], []
            r = r_root
            z = z_root
            first = True
            while z > z_end:
                # Below the shoulders the side strands gather toward the back.
                gather = _smoothstep(1.42, 1.12, z)
                a = BACK + (a0 - BACK) * (1.0 - 0.25 * gather)
                # Extra room over the corset and belt (added later, ~2.5 cm proud of the coat).
                belt = _smoothstep(0.9, 0.96, z) * (1.0 - _smoothstep(1.15, 1.2, z))
                want = surf(z, a) + clear + 0.008 + 0.028 * belt
                # Hug the skull and shoulders on the way down; below them hang
                # freely (drift inward slowly, never into her).
                if first:
                    r = want
                elif want > r:
                    r = min(want, r + 0.011)    # ease out over the shoulders: no collar flare
                else:
                    r = max(want, r - (0.012 if z > 1.3 else 0.006))
                first = False
                ar = math.radians(a)
                pts.append(Vector((math.cos(ar) * r, cy + math.sin(ar) * r, z)))
                outs.append(Vector((math.cos(ar), math.sin(ar), 0.0)))
                z -= 0.02
            if len(pts) < 4:
                continue
            pts[0] = Vector((pts[0].x, pts[0].y, pts[0].z))
            for _ in range(6):
                pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
            n = len(pts)
            arc = math.radians(2 * spread / max(count - 1, 1)) * 0.13
            w = 0.036 * (0.92 + 0.16 * rng.random())
            # Narrow at the root (tucked under the cap), widening as it falls, soft tip.
            half_w = [w * (0.5 + 0.5 * _smoothstep(0, 0.18, i / n)) * (1 + 0.25 * _smoothstep(0.2, 0.6, i / n)) * (1 - 0.55 * _smoothstep(0.7, 1.0, i / n)) for i in range(n)]
            half_t = [0.0035 * (1 - 0.5 * _smoothstep(0.7, 1.0, i / n)) for i in range(n)]
            _strand(bm, uvl, pts, outs, half_w, half_t)
    me = bpy.data.meshes.new("HairBackV3")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("HairBackV3", me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(mat)
    for poly in me.polygons:
        poly.use_smooth = True
    print("HAIR long strands", len(me.vertices), "verts, torso centre y %.3f" % cy)
    return o


def preview(tag):
    objs = mesh_objects()
    out = os.path.join(ROOT, "art", "previews", f"freyja_v3_{tag}.png")
    C.render_preview(out, objs, views=((0, "front"), (35, "tq"), (90, "side"), (180, "back")), height=TARGET_H * 1.12, look_z=TARGET_H * 0.55, size=(1800, 900))


def build(stage="look"):
    objs = load_and_clean()
    body = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    recolor(objs)
    generate_hair(objs)
    for o in mesh_objects():
        n = len(o.data.polygons)
        if n > 60000:
            decimate(o, 25000 / n)
        elif n > 15000:
            decimate(o, 0.45)
    total = sum(len(o.data.polygons) for o in mesh_objects())
    print("POLYS", total)
    if stage == "full":
        import freyja_v3_rig
        freyja_v3_rig.run(ROOT, mesh_objects, TARGET_H)
    else:
        preview(stage)


if __name__ == "__main__":
    stage = sys.argv[sys.argv.index("--") + 2] if len(sys.argv) > sys.argv.index("--") + 2 else "look"
    build(stage)
