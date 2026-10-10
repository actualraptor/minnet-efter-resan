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


def rebuild_hair(objs, body_objs):
    """Remove the twin-tails' ties; re-hang rigid copies of the tail strands
    behind the back as a long loose curtain (keeps the sculpted strand quality)."""
    tails = find(objs, "Object_7_")
    if tails is None:
        return
    z_top = 1.42 * TARGET_H / 1.586
    bm = bmesh.new()
    bm.from_mesh(tails.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z >= z_top], context="VERTS")
    # Split into left and right tails.
    left = bmesh.new()
    right = bmesh.new()
    bm.to_mesh(tails.data)
    bm.free()
    halves = []
    for side in (-1, 1):
        o = tails.copy()
        o.data = tails.data.copy()
        bpy.context.scene.collection.objects.link(o)
        b2 = bmesh.new()
        b2.from_mesh(o.data)
        bmesh.ops.delete(b2, geom=[v for v in b2.verts if (v.co.x > 0) != (side > 0)], context="VERTS")
        b2.to_mesh(o.data)
        b2.free()
        halves.append((side, o))
    bpy.data.objects.remove(tails, do_unlink=True)
    copies = []
    # (source side, x offset, y-rotation degrees, length scale, depth)
    # The last two are an underlayer just inside the curtain so a parting in
    # the middle shows more hair rather than the coat.
    layout = [(-1, -0.08, 7, 1.32, 0.06), (1, 0.08, -7, 1.32, 0.06), (-1, -0.03, 3, 1.42, 0.06),
              (1, 0.03, -3, 1.4, 0.06), (-1, 0.0, 0, 1.25, 0.06),
              (1, -0.014, 1, 1.36, 0.045), (-1, 0.014, -1, 1.36, 0.045)]
    for k, (side, dx, rot_y, ls, depth) in enumerate(layout):
        src = [o for sd, o in halves if sd == side][0]
        o = src.copy()
        o.data = src.data.copy()
        bpy.context.scene.collection.objects.link(o)
        v = np.array([vv.co[:] for vv in o.data.vertices])
        top = v[:, 2] > v[:, 2].max() - 0.04
        root = v[top].mean(axis=0)
        tip = v[v[:, 2] < v[:, 2].min() + 0.04].mean(axis=0)
        d = Vector(tip - root).normalized()
        target = Vector((0.0, 0.1, -1.0)).normalized()
        R = d.rotation_difference(target).to_matrix()
        R = Matrix.Rotation(math.radians(rot_y), 3, "Y") @ R
        local = v - root
        local[:, 2] *= ls
        rotated = (np.array(R) @ local.T).T
        new_root = np.array([dx, depth, z_top - 0.02])
        o.data.vertices.foreach_set("co", (rotated + new_root).ravel())
        o.data.update()
        copies.append(o)
    for sd, o in halves:
        bpy.data.objects.remove(o, do_unlink=True)
    joined = C.join(copies, "HairBackV3")
    print("HAIR back curtain built", len(joined.data.vertices))
    return joined


def preview(tag):
    objs = mesh_objects()
    out = os.path.join(ROOT, "art", "previews", f"freyja_v3_{tag}.png")
    C.render_preview(out, objs, views=((0, "front"), (35, "tq"), (90, "side"), (180, "back")), height=TARGET_H * 1.12, look_z=TARGET_H * 0.55, size=(1800, 900))


def build(stage="look"):
    objs = load_and_clean()
    body = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    recolor(objs)
    rebuild_hair(objs, body)
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
