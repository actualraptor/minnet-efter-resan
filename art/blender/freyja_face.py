"""Freyja's expressive face: texture cleanup, eyelids, anime mouth, shape keys.

Shape keys (exported as glTF morph targets, driven by FaceController in Godot):
  blink        upper lid (skin) closes over the eye, lashes come down with it
  mouth_open   anime mouth opens (dark inner mouth, tongue)
  mouth_smile  mouth corners lift
  mouth_o      small round "oh"
  brow_up      brows lift (surprise / delight)
Plus bones iris.L / iris.R (children of eye.L / eye.R) for gaze and saccades.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

import lib_common as C


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _pts(objs):
    return np.concatenate([np.array([v.co[:] for v in o.data.vertices]) for o in objs])


def _surface_y(kd, x, z, fallback):
    hits = kd.find_n(Vector((x, -0.3, z)), 1)
    # nearest in xz: search a line of candidates and keep the most forward point near (x,z)
    best = fallback
    for (co, _, _) in kd.find_range(Vector((x, -0.16, z)), 0.012):
        if abs(co.x - x) < 0.004 and abs(co.z - z) < 0.004:
            best = min(best, co.y)
    return best


def _key(o, name, positions):
    if not o.data.shape_keys:
        o.shape_key_add(name="Basis")
    k = o.shape_key_add(name=name, from_mix=False)
    for i, p in enumerate(positions):
        k.data[i].co = p
    return k


def _key_fn(o, name, fn):
    if not o.data.shape_keys:
        o.shape_key_add(name="Basis")
    k = o.shape_key_add(name=name, from_mix=False)
    for i, v in enumerate(o.data.vertices):
        d = fn(v.co)
        k.data[i].co = v.co + d if d is not None else v.co
    return k


def _vcol(o, fn):
    me = o.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        attr.data[i].color = fn(v.co)
    me.color_attributes.active_color = attr


# ---------------------------------------------------------------------------
# Face texture cleanup
# ---------------------------------------------------------------------------

def clean_face_texture(heads):
    """Removes the dark streaks / dots baked on the face (they read as cracks),
    by inpainting dark marks inside the face's UV area with smoothed skin."""
    img = None
    for o in heads:
        for m in o.data.materials:
            if m and m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and n.image.size[0] >= 2048:
                        img = n.image
    if img is None:
        return None
    W, H = img.size
    mask = np.zeros((H, W), dtype=bool)
    for o in heads:
        me = o.data
        uv = me.uv_layers.active.data
        for poly in me.polygons:
            c = poly.center
            if not (c.y < -0.09 and 1.39 < c.z < 1.56 and abs(c.x) < 0.085):
                continue
            us = [uv[li].uv for li in poly.loop_indices]
            xs = [u.x * (W - 1) for u in us]
            ys = [(1 - u.y) * (H - 1) for u in us]
            x0, x1 = int(max(0, min(xs))), int(min(W - 1, max(xs) + 1))
            y0, y1 = int(max(0, min(ys))), int(min(H - 1, max(ys) + 1))
            mask[y0:y1 + 1, x0:x1 + 1] = True
    if mask.sum() < 50:
        return None
    a = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1]
    rgb = a[..., :3]
    lum = rgb.mean(axis=2)
    skin_lum = np.median(lum[mask])
    dark = mask & (lum < skin_lum * 0.86)
    good = mask & ~dark
    # Normalised box blur of good skin (via integral images) to fill dark marks.
    def box(arr, r):
        c = np.cumsum(np.cumsum(np.pad(arr, ((1, 0), (1, 0))), 0), 1)
        h, w = arr.shape
        y0 = np.clip(np.arange(h) - r, 0, h)
        y1 = np.clip(np.arange(h) + r + 1, 0, h)
        x0 = np.clip(np.arange(w) - r, 0, w)
        x1 = np.clip(np.arange(w) + r + 1, 0, w)
        return c[y1][:, x1] - c[y0][:, x1] - c[y1][:, x0] + c[y0][:, x0]
    wsum = box(good.astype(np.float32), 18)
    fill = np.zeros_like(rgb)
    for ch in range(3):
        fill[..., ch] = box(rgb[..., ch] * good, 18) / np.maximum(wsum, 1e-3)
    # Feather the replacement slightly so there are no hard edges.
    soft = np.clip(box(dark.astype(np.float32), 2) / 25.0 * 1.6, 0, 1)
    soft *= mask
    rgb[:] = rgb * (1 - soft[..., None]) + fill * soft[..., None]
    a[..., :3] = rgb
    img.pixels.foreach_set(a[::-1].ravel())
    img.pack()
    skin = np.median(rgb[good], axis=0)
    print("FACE texture cleaned: %d dark px, skin=%s" % (int(dark.sum()), np.round(skin, 3)))
    return tuple(float(c) for c in skin)


# ---------------------------------------------------------------------------
# Eye regions
# ---------------------------------------------------------------------------

def eye_regions(heads, eyes):
    """Per eye: x-sampled upper/lower socket arcs (z, y) and eye front y."""
    regions = {}
    E = _pts(eyes)
    for sfx, sgn in (("L", 1), ("R", -1)):
        bnd = []
        for o in heads:
            bm = bmesh.new()
            bm.from_mesh(o.data)
            for v in bm.verts:
                if v.is_boundary and 0.018 < sgn * v.co.x < 0.09 and 1.48 < v.co.z < 1.55 and v.co.y < -0.09:
                    bnd.append(v.co[:])
            bm.free()
        B = np.array(bnd)
        ex = E[np.sign(E[:, 0]) == sgn]
        x_lo, x_hi = B[:, 0].min(), B[:, 0].max()
        xs = np.linspace(x_lo, x_hi, 14)
        up, lo = [], []
        for i, x in enumerate(xs):
            m = np.abs(B[:, 0] - x) < (x_hi - x_lo) / 18 + 0.0015
            if not m.any():
                m = np.argsort(np.abs(B[:, 0] - x))[:3]
            col = B[m]
            iu, il = np.argmax(col[:, 2]), np.argmin(col[:, 2])
            em = np.abs(ex[:, 0] - x) < 0.004
            front = ex[em, 1].min() if em.any() else col[:, 1].mean()
            up.append((x, col[iu, 2], col[iu, 1], front))
            lo.append((x, col[il, 2], col[il, 1], front))
        up, lo = np.array(up), np.array(lo)
        # Smooth the arcs (rim sampling is noisy) and make the corners meet.
        for arr in (up, lo):
            for col in (1, 2):
                v = arr[:, col].copy()
                for _ in range(3):
                    v[1:-1] = (v[:-2] + 2 * v[1:-1] + v[2:]) / 4
                arr[:, col] = v
        for k in (0, -1):
            mz = (up[k, 1] + lo[k, 1]) / 2
            up[k, 1] = lo[k, 1] = mz
        regions[sfx] = {"up": up, "lo": lo}
    return regions


def _borrow_skin(ob, positions, heads):
    """Give the lid the face material and UVs of the nearest face skin, so it
    matches the surrounding skin exactly."""
    pts, uvs, nrm = [], [], []
    for h in heads:
        uvd = h.data.uv_layers.active.data
        for poly in h.data.polygons:
            for li in poly.loop_indices:
                co = h.data.vertices[h.data.loops[li].vertex_index].co
                if co.y < -0.09 and 1.47 < co.z < 1.56:
                    pts.append(co.copy())
                    uvs.append(uvd[li].uv.copy())
                    nrm.append(h.data.vertices[h.data.loops[li].vertex_index].normal.copy())
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    ob.data.materials.clear()
    ob.data.materials.append(heads[0].data.materials[0])
    uvl = ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for li in poly.loop_indices:
            vi = ob.data.loops[li].vertex_index
            p = positions[vi]
            # sample just above the socket rim so the lid takes the brow-side skin tone
            _, idx, _ = kd.find(Vector((p.x, p.y, p.z + 0.002)))
            uvl.data[li].uv = uvs[idx]
    # Shade like the face around it: copy the nearest face normals.
    norms = []
    for v in ob.data.vertices:
        _, idx, _ = kd.find(Vector(positions[v.index]) + Vector((0, 0, 0.002)))
        norms.append(tuple(nrm[idx]))
    ob.data.normals_split_custom_set_from_vertices(norms)


def build_lids(regions, skin_rgb, rows=6, skin_src=None):
    """Skin lids: basis collapsed to the upper socket arc (hidden under the
    lashes); 'blink' spreads them down over the socket to the lower arc."""
    lids = []
    mat = C.mat("M_Skin_Lid_freyja", "#%02x%02x%02x" % tuple(int(255 * min(1, max(0, c)) ** (1 / 2.2)) for c in skin_rgb), 0.6)
    for sfx, R in regions.items():
        up, lo = R["up"], R["lo"]
        n = len(up)
        bm = bmesh.new()
        grid_basis, grid_blink = [], []
        for j in range(rows + 1):
            t = j / rows
            rb, rk = [], []
            for i in range(n):
                x = up[i, 0]
                zu, yu, zl, yl = up[i, 1], up[i, 2], lo[i, 1], lo[i, 2]
                front = min(up[i, 3], lo[i, 3]) - 0.0012
                bulge = math.sin(math.pi * t) * (0.6 + 0.4 * math.sin(math.pi * i / (n - 1)))
                z = zu + (zl - zu) * t
                y = yu + (yl - yu) * t
                y = min(y, front * bulge + y * (1 - bulge)) - 0.0004
                rk.append(Vector((x, y, z)))
                rb.append(Vector((x, yu - 0.0003, zu)))
            grid_basis.append(rb)
            grid_blink.append(rk)
        verts = [[bm.verts.new(p) for p in row] for row in grid_basis]
        for j in range(rows):
            for i in range(n - 1):
                bm.faces.new((verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = C.mesh_obj(f"EyeLid.{sfx}", bm, mat, smooth=True)
        if skin_src is not None:
            _borrow_skin(ob, [p for row in grid_blink for p in row], skin_src)
        flat_blink = [p for row in grid_blink for p in row]
        _key(ob, "blink", flat_blink)
        # A gentle, upward-curved "happy" squint: lids close ~65% with a smile curve.
        happy = []
        for j, row in enumerate(grid_blink):
            for i, p in enumerate(row):
                b = grid_basis[j][i]
                t = 0.62 - 0.12 * math.sin(math.pi * i / (n - 1))
                happy.append(b.lerp(p, t))
        _key(ob, "squint", happy)
        lids.append(ob)
    return lids


def lash_keys(lash, regions):
    """Upper lash + crease line ride down with the lid; brows can lift."""
    def arcs(x):
        R = regions["L" if x > 0 else "R"]
        up, lo = R["up"], R["lo"]
        zu = np.interp(x, up[:, 0], up[:, 1])
        zl = np.interp(x, lo[:, 0], lo[:, 1])
        return zu, zl

    def blink(co, amount=1.0):
        if 0.014 < abs(co.x) < 0.085 and 1.503 <= co.z <= 1.534 and co.y < -0.12:
            zu, zl = arcs(co.x)
            drop = (zu - zl) * 0.93 * amount
            return Vector((0, -0.0015 * amount, -drop))
        return None
    _key_fn(lash, "blink", blink)

    def squint(co):
        d = blink(co, 0.62)
        if d is None:
            return None
        bend = 0.12 * (1 - min(1.0, abs(abs(co.x) - 0.05) / 0.03))
        return d + Vector((0, 0, 0.004 * bend))
    _key_fn(lash, "squint", squint)
    _key_fn(lash, "brow_up", lambda co: Vector((0, -0.0006, 0.0055)) if 1.536 <= co.z <= 1.56 and co.y < -0.13 else None)


def eye_keys(eyes, regions):
    for o in eyes:
        def blink(co):
            R = regions["L" if co.x > 0 else "R"]
            zl = float(np.mean(R["lo"][:, 1]))
            return Vector((0, 0.0025, (zl + 0.002 - co.z) * 0.9))
        _key_fn(o, "blink", blink)

        def squint(co):
            R = regions["L" if co.x > 0 else "R"]
            zl = float(np.mean(R["lo"][:, 1]))
            return Vector((0, 0.0012, (zl + 0.002 - co.z) * 0.55))
        _key_fn(o, "squint", squint)


# ---------------------------------------------------------------------------
# Mouth
# ---------------------------------------------------------------------------

def build_mouth(heads, center_z=1.457):
    P = _pts(heads)
    kd = KDTree(len(P))
    for i, p in enumerate(P):
        kd.insert(Vector(p), i)
    kd.balance()
    near = P[(np.abs(P[:, 0]) < 0.01) & (np.abs(P[:, 2] - center_z) < 0.006) & (P[:, 1] < -0.1)]
    face_y = float(near[:, 1].min()) if len(near) else -0.166

    def surf(x, z):
        best = None
        for (co, _, _) in kd.find_range(Vector((x, face_y, z)), 0.015):
            if abs(co.x - x) < 0.0035 and abs(co.z - z) < 0.0035 and co.y < -0.1:
                best = co.y if best is None else min(best, co.y)
        return (best if best is not None else face_y) - 0.0011

    cols, rows = 13, 5
    width = 0.0105

    def shape(open_amt, smile, oh):
        pts = []
        for j in range(rows + 1):
            v = j / rows * 2 - 1          # -1 top lip .. +1 bottom
            for i in range(cols):
                u = i / (cols - 1) * 2 - 1
                w = width * (1 - 0.45 * oh)
                x = u * w
                edge = math.sqrt(max(0.0, 1 - u * u))
                curve = -0.0012 * (1 - u * u) + smile * 0.0022 * u * u  # resting slight downturn vs smile
                top = 0.00045 + 0.0012 * open_amt * edge + 0.0035 * oh * edge
                bot = 0.00045 + 0.0062 * open_amt * edge ** 0.8 + 0.0035 * oh * edge
                z = center_z + curve * (1 - oh) + (top if v < 0 else -bot) * abs(v)
                pts.append(Vector((x, surf(x, z), z)))
        return pts

    base = shape(0, 0, 0)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in base]
    for j in range(rows):
        for i in range(cols - 1):
            a = j * cols + i
            bm.faces.new((vs[a], vs[a + 1], vs[a + cols + 1], vs[a + cols]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = C.mesh_obj("Mouth", bm, C.mat("M_Mouth_freyja", "#ffffff", 0.7), smooth=True)
    inner = (0.36, 0.11, 0.14, 1.0)
    tongue = (0.86, 0.45, 0.48, 1.0)
    lip = (0.55, 0.26, 0.28, 1.0)
    cz = center_z

    def col(co):
        dz = co.z - cz
        u = abs(co.x) / width
        if dz < -0.002 and u < 0.6:
            return tongue
        if abs(dz) < 0.0006:
            return lip
        return inner
    _vcol(ob, col)
    _key(ob, "mouth_open", shape(1, 0, 0))
    _key(ob, "mouth_smile", shape(0, 1, 0))
    _key(ob, "mouth_o", shape(0, 0, 1))
    return ob


def build(arm, objs, rig):
    """Adds lids, mouth, keys and iris bones. Call after skinning, before export."""
    heads = [o for n, o in objs.items() if n.startswith("Body01_defaultMat_0")]
    eyes = [o for n, o in objs.items() if n.startswith("FrierenEyes")]
    lash = [o for n, o in objs.items() if n.startswith("Object_4_")][0]
    skin = clean_face_texture(heads) or (0.98, 0.86, 0.8)
    regions = eye_regions(heads, eyes)
    lids = build_lids(regions, skin, skin_src=heads)
    lash_keys(lash, regions)
    eye_keys(eyes, regions)
    mouth = build_mouth(heads)
    for o in lids + [mouth]:
        o.parent = arm
        g = o.vertex_groups.new(name="head")
        g.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
        m = o.modifiers.new("Armature", "ARMATURE")
        m.object = arm
        rig.objects.append((o, None, "head"))
    # Iris bones for gaze, children of the eye bones.
    iris_objs = [o for o in eyes if "Iris_0_FrierenIris" in o.name or o.name.endswith("FrierenIris_0")]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for sfx, sgn in (("L", 1), ("R", -1)):
        sel = _pts(iris_objs or eyes)
        sel = sel[np.sign(sel[:, 0]) == sgn]
        c = Vector(sel.mean(axis=0))
        b = arm.data.edit_bones.new(f"iris.{sfx}")
        b.head, b.tail, b.roll = c, c + Vector((0, 0, 0.01)), 0.0
        b.parent = arm.data.edit_bones[f"eye.{sfx}"]
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in iris_objs:
        o.vertex_groups.clear()
        gl, gr = o.vertex_groups.new(name="iris.L"), o.vertex_groups.new(name="iris.R")
        gl.add([v.index for v in o.data.vertices if v.co.x > 0], 1.0, "REPLACE")
        gr.add([v.index for v in o.data.vertices if v.co.x <= 0], 1.0, "REPLACE")
    print("FACE built: lids", len(lids), "mouth", len(mouth.data.vertices), "iris objs", len(iris_objs))
