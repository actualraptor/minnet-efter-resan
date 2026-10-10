"""Rigging for tailored outfits: chain bones, weights, body mask, export.

Bone names follow Godot's humanoid profile (see tailor.VROID_TO_HUMANOID) so the
outfit binds to an imported VRM skeleton by name. Extra bones for secondary
motion are named <group>_<k>_<n> (skirt_3_2, cape_1_1) and are created on the
character's skeleton at runtime by game/scripts/core/outfit.gd.
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import tailor as T


def add_chains(arm, chains):
    """chains: {prefix: (parent_bone, [Vector points])} -> bones prefix_1..n."""
    T._select_only([arm])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for prefix, (parent, pts) in chains.items():
        prev = eb[parent]
        for i in range(len(pts) - 1):
            b = eb.new(f"{prefix}_{i + 1}")
            b.head, b.tail = pts[i], pts[i + 1]
            b.roll = 0.0
            b.parent = prev
            b.use_connect = i > 0
            b.use_deform = True
            prev = b
    bpy.ops.object.mode_set(mode="OBJECT")


def skirt_chains(rings, centre, n=12, rows=(2, 5, 8, 12), inset=0.012, prefix="skirt"):
    """A ring of chains on the inner side of a ring-built skirt."""
    segs = len(rings[0])
    out = {}
    for k in range(n):
        i = int(round(k * segs / n)) % segs
        pts = []
        for j in rows:
            p = rings[min(j, len(rings) - 1)][i]
            d = Vector((p.x - centre.x, p.y - centre.y, 0.0)).normalized()
            pts.append(p - d * inset)
        out[f"{prefix}_{k}"] = ("Hips", pts)
    return out


def _clear(o):
    o.vertex_groups.clear()


def _set(o, vi, weights):
    tot = sum(w for w in weights.values() if w > 0)
    if tot <= 1e-9:
        return
    for name, w in weights.items():
        if w <= 1e-5:
            continue
        g = o.vertex_groups.get(name) or o.vertex_groups.new(name=name)
        g.add([vi], w / tot, "REPLACE")


def weight_hanging(o, arm, centre, top_z, hem_z, prefix, n_chains, root="Hips", band=0.12):
    """Shared weight function for every hanging layer on the same chains:
    the top band follows `root`, below it each vertex blends between the two
    nearest chains (by angle) and along their segments (by height)."""
    _clear(o)
    chains = []
    for k in range(n_chains):
        bones = sorted((b for b in arm.data.bones if b.name.startswith(f"{prefix}_{k}_")), key=lambda b: int(b.name.rsplit("_", 1)[1]))
        if bones:
            h = bones[0].head_local
            chains.append((math.atan2(h.y - centre.y, h.x - centre.x), bones))
    for v in o.data.vertices:
        p = v.co
        t = (top_z - p.z) / max(top_z - hem_z, 1e-6)
        follow = T.smoothstep(band * 0.4, band * 1.6, t)
        ws = {root: 1.0 - follow}
        if follow > 0:
            a = math.atan2(p.y - centre.y, p.x - centre.x)
            # Smooth falloff over ~1.6 chain spacings: each point follows 3-4
            # chains, so a chain pushed by a leg bends the cloth in a soft curve
            # instead of a crease.
            spacing = math.tau / max(len(chains), 1)
            cand = []
            for ca, bones in chains:
                dang = abs((a - ca + math.pi) % math.tau - math.pi)
                x = dang / (1.6 * spacing)
                if x < 1.0:
                    cand.append((0.5 + 0.5 * math.cos(math.pi * x), bones))
            tot_a = sum(w for w, _ in cand) or 1.0
            for wa, bones in cand:
                wa /= tot_a
                # Position along the chain by height.
                zs = [b.head_local.z for b in bones] + [bones[-1].tail_local.z]
                for bi, b in enumerate(bones):
                    z0, z1 = zs[bi], zs[bi + 1]
                    if bi == 0 and p.z > z0:
                        seg_w = 1.0
                    elif bi == len(bones) - 1 and p.z <= z1:
                        seg_w = 1.0
                    else:
                        mid0 = (zs[max(bi - 1, 0)] + z0) / 2 if bi > 0 else z0 + 1
                        seg_w = max(0.0, 1.0 - abs(p.z - (z0 + z1) / 2) / max(abs(z0 - z1), 1e-6))
                    if seg_w > 0:
                        ws[b.name] = ws.get(b.name, 0.0) + follow * wa * seg_w
        _set(o, v.index, ws)


def weight_capelet(o, arm, centre, rows_z, prefix="cape", n_chains=6):
    """Capelet: collar band on UpperChest/shoulders; the sides follow the
    upper arms (so the hem drops with lowered arms); front/back hems on chains."""
    _clear(o)
    chains = []
    for k in range(n_chains):
        bones = sorted((b for b in arm.data.bones if b.name.startswith(f"{prefix}_{k}_")), key=lambda b: int(b.name.rsplit("_", 1)[1]))
        if bones:
            h = bones[0].head_local
            chains.append((math.atan2(h.y - centre.y, h.x - centre.x), bones))
    top_z, low_z = rows_z
    for v in o.data.vertices:
        p = v.co
        a = math.atan2(p.y - centre.y, p.x - centre.x)
        side = abs(math.cos(a)) ** 2                       # 1 over the shoulders
        sgn = "Left" if p.x > 0 else "Right"
        r = math.hypot(p.x - centre.x, p.y - centre.y)
        t = T.smoothstep(0.0, 1.0, (r - 0.07) / 0.12) if side > 0.5 else T.smoothstep(0.0, 1.0, (top_z - p.z) / max(top_z - low_z, 1e-6))
        ws = {"UpperChest": (1 - t) * (1 - 0.5 * side), f"{sgn}Shoulder": (1 - t) * 0.5 * side}
        ws[f"{sgn}UpperArm"] = t * side * 0.7
        ws[f"{sgn}Shoulder"] = ws.get(f"{sgn}Shoulder", 0) + t * side * 0.3
        hang = t * (1 - side)
        if hang > 0 and chains:
            ds = sorted(((abs((a - ca + math.pi) % math.tau - math.pi), bones) for ca, bones in chains), key=lambda x: x[0])[:2]
            span = ds[0][0] + ds[1][0] + 1e-9
            for ang, bones in ds:
                wa = 1.0 - ang / span
                w_up = 1.0 - T.smoothstep(0.4, 0.9, t)
                ws[bones[0].name] = ws.get(bones[0].name, 0) + hang * wa * w_up
                ws[bones[-1].name] = ws.get(bones[-1].name, 0) + hang * wa * (1 - w_up)
        _set(o, v.index, ws)


def rigid(o, bone):
    _clear(o)
    g = o.vertex_groups.new(name=bone)
    g.add([v.index for v in o.data.vertices], 1.0, "REPLACE")


def restrict(o, allowed):
    T.limit_and_normalise(o, 4, allowed=set(allowed))


def bind(o, arm):
    o.parent = arm
    m = o.modifiers.new("Armature", "ARMATURE")
    m.object = arm


def body_mask(body, covering, path, size=1024, reach=0.03):
    """UV-space mask of the body: black where opaque fitted garments cover the
    skin (every vertex of the face has a garment within `reach` along its
    normal). The game drops those triangles so skin never pokes through."""
    from mathutils.bvhtree import BVHTree
    bm = bmesh.new()
    for o in covering:
        tmp = o.data.copy()
        tmp.transform(o.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    img = np.ones((size, size), np.float32)
    covered_total = 0
    for o in body.meshes:
        mats = [m.name.upper() if m else "" for m in o.data.materials]
        me = o.data
        uvl = me.uv_layers.active
        if uvl is None:
            continue
        me.calc_loop_triangles()
        cov_v = np.zeros(len(me.vertices), bool)
        for v in me.vertices:
            p = o.matrix_world @ v.co
            n = (o.matrix_world.to_3x3() @ v.normal).normalized()
            hit = bvh.ray_cast(p, n, reach)
            cov_v[v.index] = hit[0] is not None
        for tri in me.loop_triangles:
            if not (mats[tri.material_index].split(" (")[0].endswith("_SKIN") and "BODY" in mats[tri.material_index]):
                continue
            if not all(cov_v[vi] for vi in tri.vertices):
                continue
            covered_total += 1
            uv = np.array([uvl.data[li].uv[:] for li in tri.loops]) * (size - 1)
            _fill_tri(img, uv)
    out = np.ones((size, size, 4), np.float32)
    out[..., 0] = out[..., 1] = out[..., 2] = img
    im = bpy.data.images.new("bodymask", size, size)
    im.pixels.foreach_set(out.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    print("BODY MASK", covered_total, "triangles hidden ->", path)


def _fill_tri(img, uv):
    (x0, y0), (x1, y1), (x2, y2) = uv
    xmin, xmax = int(max(0, min(x0, x1, x2) - 1)), int(min(img.shape[1] - 1, max(x0, x1, x2) + 1))
    ymin, ymax = int(max(0, min(y0, y1, y2) - 1)), int(min(img.shape[0] - 1, max(y0, y1, y2) + 1))
    if xmax < xmin or ymax < ymin:
        return
    xs, ys = np.meshgrid(np.arange(xmin, xmax + 1) + 0.5, np.arange(ymin, ymax + 1) + 0.5)
    d = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    if abs(d) < 1e-9:
        return
    a = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) / d
    b = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) / d
    c = 1 - a - b
    inside = (a >= -0.02) & (b >= -0.02) & (c >= -0.02)
    sub = img[ymin:ymax + 1, xmin:xmax + 1]
    sub[inside] = 0.0
