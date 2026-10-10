"""Tailor: measures a humanoid body and builds garments around it.

Works on any VRM / glTF humanoid (VRoid naming `J_Bip_*` or Godot humanoid
names). The body is normalised to: Z up, facing -Y, character's left = +X, and
bones renamed to Godot's SkeletonProfileHumanoid names, so the outfit binds to
the imported VRM skeleton by name.

Garment kinds (see docs/design/CLOTHING_PIPELINE.md):
  fitted  - grown from a watertight remesh of the body, offset outward by a
            per-point clearance, cut with planes, weights copied from the body
  hanging - revolution surfaces (skirt, petticoat, capelet) driven by chains
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

VROID_TO_HUMANOID = {
    "J_Bip_C_Hips": "Hips", "J_Bip_C_Spine": "Spine", "J_Bip_C_Chest": "Chest",
    "J_Bip_C_UpperChest": "UpperChest", "J_Bip_C_Neck": "Neck", "J_Bip_C_Head": "Head",
}
for side, S in (("L", "Left"), ("R", "Right")):
    VROID_TO_HUMANOID.update({
        f"J_Bip_{side}_Shoulder": f"{S}Shoulder", f"J_Bip_{side}_UpperArm": f"{S}UpperArm",
        f"J_Bip_{side}_LowerArm": f"{S}LowerArm", f"J_Bip_{side}_Hand": f"{S}Hand",
        f"J_Bip_{side}_UpperLeg": f"{S}UpperLeg", f"J_Bip_{side}_LowerLeg": f"{S}LowerLeg",
        f"J_Bip_{side}_Foot": f"{S}Foot", f"J_Bip_{side}_ToeBase": f"{S}Toes",
    })
    for f, F in (("Thumb", "Thumb"), ("Index", "Index"), ("Middle", "Middle"), ("Ring", "Ring"), ("Little", "Little")):
        names = ("Metacarpal", "Proximal", "Distal") if f == "Thumb" else ("Proximal", "Intermediate", "Distal")
        for k in range(3):
            VROID_TO_HUMANOID[f"J_Bip_{side}_{f}{k + 1}"] = f"{S}{F}{names[k]}"


def _select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


class Body:
    """A humanoid body, normalised. `joint(name)` gives a bone head position."""

    def __init__(self, path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)
        self.arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
        for o in list(bpy.context.scene.objects):
            if o.type == "MESH" and o.parent is None and not o.vertex_groups:
                bpy.data.objects.remove(o, do_unlink=True)  # importer helper spheres etc.
        self.meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        # Bare body: remove the avatar's own clothing (VRoid tags it *_CLOTH).
        for o in self.meshes:
            mats = [m.name.upper() if m else "" for m in o.data.materials]
            if not any("CLOTH" in m for m in mats):
                continue
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if "CLOTH" in mats[f.material_index]], context="FACES")
            bm.to_mesh(o.data)
            bm.free()
        for b in self.arm.data.bones:
            if b.name in VROID_TO_HUMANOID:
                b.name = VROID_TO_HUMANOID[b.name]  # vertex groups follow the rename
        bpy.context.view_layer.update()
        # Face -Y with the character's left on +X.
        toes = self.joint("LeftToes") if "LeftToes" in self.arm.data.bones else self.joint("LeftFoot")
        if toes.y - self.joint("LeftFoot").y > 0.0 or self.joint("LeftUpperLeg").x < 0:
            root = bpy.data.objects.new("_turn", None)
            bpy.context.scene.collection.objects.link(root)
            self.arm.parent = root
            root.rotation_euler = (0, 0, math.pi)
            bpy.context.view_layer.update()
            mw = self.arm.matrix_world.copy()
            self.arm.parent = None
            self.arm.matrix_world = mw
            bpy.data.objects.remove(root)
        _select_only([self.arm] + self.meshes, self.arm)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        bpy.context.view_layer.update()
        self.height = max((o.matrix_world @ Vector(c)).z for o in self.meshes for c in o.bound_box)
        self._bvh = None
        self._remesh = None

    def joint(self, name):
        return self.arm.matrix_world @ self.arm.data.bones[name].head_local

    def has(self, name):
        return name in self.arm.data.bones

    # --- surfaces ------------------------------------------------------------------
    def bvh(self):
        if self._bvh is None:
            bm = bmesh.new()
            for o in self.meshes:
                tmp = o.data.copy()
                tmp.transform(o.matrix_world)
                bm.from_mesh(tmp)
                bpy.data.meshes.remove(tmp)
            self._bvh = BVHTree.FromBMesh(bm)
            bm.free()
        return self._bvh

    def shell(self):
        """The body's skin as one welded, skinned mesh (cached): the base every
        fitted garment is cut from. Keeps the body's weights and topology."""
        if self._remesh is not None:
            return self._remesh
        parts = []
        for o in self.meshes:
            mats = [m.name.upper() if m else "" for m in o.data.materials]
            if not any(m.split(" (")[0].endswith("_SKIN") for m in mats):
                continue
            c = o.copy()
            c.data = o.data.copy()
            bpy.context.scene.collection.objects.link(c)
            if c.data.shape_keys:
                c.shape_key_clear()
            bm = bmesh.new()
            bm.from_mesh(c.data)
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if not mats[f.material_index].split(" (")[0].endswith("_SKIN")], context="FACES")
            bm.to_mesh(c.data)
            bm.free()
            c.modifiers.clear()
            if c.data.shape_keys:
                c.shape_key_clear()
            c.parent = None
            parts.append(c)
        _select_only(parts)
        if len(parts) > 1:
            bpy.ops.object.join()
        sh = bpy.context.view_layer.objects.active
        sh.name = "_BodyShell"
        bm = bmesh.new()
        bm.from_mesh(sh.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)  # weld UV seams so offsets don't crack
        bm.to_mesh(sh.data)
        bm.free()
        self._remesh = sh
        return sh

    layers = None

    def add_layer(self, obj):
        """Register a finished garment: later garments are measured against it."""
        if self.layers is None:
            self.layers = []
        self.layers.append(obj)
        self._below = {}

    def layers_object(self):
        """One mesh object of skin + registered layers (shrinkwrap target)."""
        n = len(self.layers or [])
        if getattr(self, "_lo_n", -1) == n:
            return self._lo
        me = bpy.data.meshes.new("_Layers")
        bm = bmesh.new()
        for o in [self.shell()] + (self.layers or []):
            tmp = o.data.copy()
            tmp.transform(o.matrix_world)
            bm.from_mesh(tmp)
            bpy.data.meshes.remove(tmp)
        bm.to_mesh(me)
        bm.free()
        lo = bpy.data.objects.new("_Layers", me)
        bpy.context.scene.collection.objects.link(lo)
        lo.hide_render = True
        if getattr(self, "_lo", None) is not None:
            bpy.data.objects.remove(self._lo, do_unlink=True)
        self._lo, self._lo_n = lo, n
        return lo

    def bvh_below(self, z_max=10.0):
        """BVH of skin + registered garment layers below a height (e.g. the
        shoulders without the head)."""
        key = round(z_max, 3)
        cache = getattr(self, "_below", {})
        if key not in cache:
            bm = bmesh.new()
            for o in [self.shell()] + (self.layers or []):
                part = bmesh.new()
                part.from_mesh(o.data)
                part.transform(o.matrix_world)
                if o is self.shell():
                    # Skin: drop the head and neck by their bone weights (a height
                    # cut would also remove raised shoulders and sleeve puffs).
                    head = {g.index for g in o.vertex_groups if g.name in ("Head", "Neck")}
                    dl = part.verts.layers.deform.active
                    if dl is not None and head and z_max < 9:
                        kill = [f for f in part.faces
                                if sum(sum(w for gi, w in v[dl].items() if gi in head) for v in f.verts) / len(f.verts) > 0.5]
                        bmesh.ops.delete(part, geom=kill, context="FACES")
                else:
                    bmesh.ops.delete(part, geom=[f for f in part.faces if f.calc_center_median().z > z_max], context="FACES")
                me = bpy.data.meshes.new("_tmp")
                part.to_mesh(me)
                part.free()
                bm.from_mesh(me)
                bpy.data.meshes.remove(me)
            cache[key] = BVHTree.FromBMesh(bm)
            bm.free()
            self._below = cache
        return cache[key]

    def ring_radius(self, centre, axis, ref, ang_deg, start_r=0.5):
        """Distance from the axis line to the body's outer surface at an angle
        (measured from `ref`, around `axis`), by casting a ray inward."""
        axis = Vector(axis).normalized()
        ref = (Vector(ref) - axis * Vector(ref).dot(axis)).normalized()
        side = axis.cross(ref)
        a = math.radians(ang_deg)
        d = ref * math.cos(a) + side * math.sin(a)
        o = Vector(centre) + d * start_r
        loc, n, i, dist = self.bvh_below().ray_cast(o, -d, start_r)
        return None if loc is None else start_r - dist


def transfer_weights(body, obj, max_bones=4):
    """Copy skin weights from the body to obj (nearest face, interpolated)."""
    src = [o for o in body.meshes if o.vertex_groups]
    for s in src:
        for g in s.vertex_groups:
            if g.name not in obj.vertex_groups:
                obj.vertex_groups.new(name=g.name)
    for s in src:
        dt = obj.modifiers.new("DT_" + s.name, "DATA_TRANSFER")
        dt.object = s
        dt.use_vert_data = True
        dt.data_types_verts = {"VGROUP_WEIGHTS"}
        dt.vert_mapping = "POLYINTERP_NEAREST"
        dt.layers_vgroup_select_src = "ALL"
        dt.layers_vgroup_select_dst = "NAME"
        dt.mix_mode = "ADD" if s is not src[0] else "REPLACE"
        _select_only([obj])
        bpy.ops.object.modifier_apply(modifier=dt.name)
    limit_and_normalise(obj, max_bones)


def limit_and_normalise(obj, max_bones=4, allowed=None):
    names = {g.index: g.name for g in obj.vertex_groups}
    for v in obj.data.vertices:
        ws = [(g.weight, g.group) for g in v.groups if g.weight > 1e-4 and (allowed is None or names[g.group] in allowed)]
        ws.sort(reverse=True)
        keep = ws[:max_bones]
        tot = sum(w for w, _ in keep)
        # Removing a weight reallocates Blender's deform array. Copy integer
        # indices first; retaining RNA group references can read freed memory.
        for group_index in [g.group for g in v.groups]:
            obj.vertex_groups[group_index].remove([v.index])
        if tot <= 1e-6:
            continue
        for w, gi in keep:
            obj.vertex_groups[names[gi]].add([v.index], w / tot, "REPLACE")
    for g in list(obj.vertex_groups):
        if not any(gg.group == g.index for v in obj.data.vertices for gg in v.groups):
            obj.vertex_groups.remove(g)


def fitted(body, name, offset_fn, keep_fn, cuts=(), smooth=3, material=None):
    """A fitted garment grown from the body shell.
    offset_fn(p) -> clearance in metres at world point p (0 = drop the vertex);
    keep_fn(p) -> True for points the garment covers;
    cuts: [(point, normal)] planes; the side the normal points to is removed."""
    sh = body.shell()
    o = sh.copy()
    o.data = sh.data.copy()
    o.name = name
    bpy.context.scene.collection.objects.link(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    kill = [v for v in bm.verts if not keep_fn(v.co)]
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    for (pt, nrm) in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        res = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(pt), plane_no=Vector(nrm), clear_outer=True)
    # Drop small disconnected islands left by the cuts.
    _keep_largest_islands(bm, min_faces=40)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset_fn(v.co)
    bm.to_mesh(o.data)
    bm.free()
    if smooth:
        sm = o.modifiers.new("Smooth", "LAPLACIANSMOOTH")
        sm.iterations = smooth
        sm.lambda_factor = 0.4
        sm.use_volume_preserve = True
        _select_only([o])
        bpy.ops.object.modifier_apply(modifier=sm.name)
    limit_and_normalise(o, 4)
    if material:
        o.data.materials.clear()
        o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def _keep_largest_islands(bm, min_faces=40):
    bm.faces.ensure_lookup_table()
    seen = set()
    islands = []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            c = stack.pop()
            isl.append(c)
            for e in c.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        islands.append(isl)
    for isl in islands:
        if len(isl) < min_faces:
            bmesh.ops.delete(bm, geom=isl, context="FACES")


def solidify(o, thickness=0.0015, rim=True):
    m = o.modifiers.new("Solidify", "SOLIDIFY")
    m.thickness = thickness
    m.offset = -1.0
    m.use_rim = rim
    m.use_even_offset = True
    _select_only([o])
    bpy.ops.object.modifier_apply(modifier=m.name)


def smoothstep(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def seg_param(p, a, b):
    """(t along a->b clamped to [0,1] unclamped too, distance to the segment)."""
    ab = b - a
    t = (p - a).dot(ab) / max(ab.length_squared, 1e-9)
    q = a + ab * min(1.0, max(0.0, t))
    return t, (p - q).length


def drape_relax(o, body, clearance, rounds=4, smooth_iter=12, factor=0.6, pin_group=None):
    """Cloth-like relaxation with Blender's own modifiers: smoothing makes the
    fabric span hollows (under the bust, small of the back) instead of following
    them; a shrinkwrap in OUTSIDE mode then keeps it at least `clearance` away
    from the body. Repeating the pair converges on a draped surface.
    pin_group: vertex group that should not move (e.g. collar, cuffs)."""
    target = body.layers_object()
    for _ in range(rounds):
        sm = o.modifiers.new("Relax", "SMOOTH")
        sm.factor, sm.iterations = factor, smooth_iter
        if pin_group:
            sm.vertex_group, sm.invert_vertex_group = pin_group, True
        sw = o.modifiers.new("Floor", "SHRINKWRAP")
        sw.target = target
        sw.wrap_method = "NEAREST_SURFACEPOINT"
        sw.wrap_mode = "OUTSIDE"
        sw.offset = clearance
        _select_only([o])
        bpy.ops.object.modifier_apply(modifier=sm.name)
        bpy.ops.object.modifier_apply(modifier=sw.name)


def subdivide(o, levels=1):
    m = o.modifiers.new("Subsurf", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    m.quality = 3
    _select_only([o])
    bpy.ops.object.modifier_apply(modifier=m.name)


def centre_at(body, z, x_max=0.25):
    """Centre (x, y) of the torso cross-section at height z (from the outer surface)."""
    rs = {}
    for a in (0, 90, 180, 270):
        rs[a] = body.ring_radius(Vector((0, 0, z)), (0, 0, 1), (1, 0, 0), a, start_r=x_max)
    cx = ((rs[0] or 0) - (rs[180] or 0)) / 2
    cy = ((rs[90] or 0) - (rs[270] or 0)) / 2
    return Vector((cx, cy, z))


def revolve(name, rings, segs, material=None, mat_fn=None, uv=True):
    """Surface from rings: rings[j] = list of segs points (closed loop), top to bottom.
    mat_fn(j, i) -> material slot index for face (j, i)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap") if uv else None
    vs = [[bm.verts.new(p) for p in ring] for ring in rings]
    nr = len(rings)
    for j in range(nr - 1):
        for i in range(segs):
            f = bm.faces.new((vs[j][i], vs[j][(i + 1) % segs], vs[j + 1][(i + 1) % segs], vs[j + 1][i]))
            if mat_fn:
                f.material_index = mat_fn(j, i)
            if uv:
                for loop, (ii, jj) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
                    loop[uvl].uv = (ii / segs, 1.0 - jj / (nr - 1))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for m in (material if isinstance(material, (list, tuple)) else [material] if material else []):
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return o


def drop_cloth(body, centre, length_fn, segs=72, rows=16, clearance=0.006, r0=0.07, z_cap=None, flare=0.12):
    """Stiff-fabric drop around a vertical axis (capelets, mantles).
    In each meridian plane (r, z) the body's top profile is sampled (rays cast
    down, head excluded); the cloth follows the upper convex hull of that
    profile from the neck (a taut string over shoulder or bust) and past the
    last support hangs straight down with a slight outward flare, until the
    meridian's length is used up. Returns rings (rows+1 x segs), top to bottom."""
    bvh = body.bvh_below(z_cap if z_cap is not None else centre.z + 0.03)
    merid = []
    for i in range(segs):
        a = math.tau * i / segs
        d = Vector((math.cos(a), math.sin(a), 0.0))
        L = length_fn(math.degrees(a) % 360)
        # Start just outside the neck surface in this direction.
        far = Vector(centre) + d * 0.3
        nh = bvh.ray_cast(far, -d, 0.3)
        r_start = ((nh[0] - Vector(centre)).dot(d) + clearance) if nh[0] is not None else r0
        prof = []
        r = r_start
        last_z = centre.z
        while r < r_start + L + 0.02:
            q = Vector(centre) + d * r
            hit = bvh.ray_cast(Vector((q.x, q.y, centre.z + 0.2)), Vector((0, 0, -1)), 0.7)
            if hit[0] is None or last_z - hit[0].z > 0.06:
                break           # past the body edge (or a jump down to something far below)
            last_z = hit[0].z
            prof.append((r, hit[0].z + clearance))
            r += 0.004
        if not prof:
            prof = [(r_start, centre.z)]
        # Upper hull from the start point outward (monotone chain).
        hull = [prof[0]]
        for pt in prof[1:]:
            while len(hull) >= 2:
                (r1, z1), (r2, z2) = hull[-2], hull[-1]
                if (r2 - r1) * (pt[1] - z1) - (z2 - z1) * (pt[0] - r1) >= 0:
                    hull.pop()
                else:
                    break
            hull.append(pt)
        # Walk the hull, then hang; stop where the slope would turn upward or at length.
        pts, s_len = [], 0.0
        prev = None
        for (rr, zz) in hull:
            if prev is not None and zz > prev[1] + 1e-4:
                continue
            p = Vector(centre) + d * rr
            p.z = zz
            if pts:
                s_len += (p - pts[-1]).length
                if s_len > L:
                    break
            pts.append(p)
            prev = (rr, zz)
        p = pts[-1].copy()
        step = 0.006
        while s_len < L:
            q = p + Vector((0, 0, -step)) + d * step * flare
            # Never hang inside the body (e.g. over the back): rest on it instead.
            far = Vector((centre.x, centre.y, q.z)) + d * 0.6
            hit = bvh.ray_cast(far, -d, 0.6)
            if hit[0] is not None:
                body_r = (hit[0] - Vector((centre.x, centre.y, q.z))).dot(d)
                cur_r = (q - Vector((centre.x, centre.y, q.z))).dot(d)
                if cur_r < body_r + clearance:
                    q += d * (body_r + clearance - cur_r)
            s_len += (q - p).length
            p = q
            pts.append(p.copy())
        merid.append(pts)
    rings = []
    for j in range(rows + 1):
        t = j / rows
        ring = []
        for pts in merid:
            acc = [0.0]
            for k in range(1, len(pts)):
                acc.append(acc[-1] + (pts[k] - pts[k - 1]).length)
            target = t * acc[-1]
            if len(pts) < 2:
                ring.append(pts[0].copy())
                continue
            k = next((kk for kk in range(1, len(acc)) if acc[kk] >= target), len(acc) - 1) - 1
            k = max(0, min(len(pts) - 2, k))
            seg = max(acc[k + 1] - acc[k], 1e-9)
            ring.append(pts[k].lerp(pts[k + 1], min(1.0, (target - acc[k]) / seg)))
        rings.append(ring)
    for _ in range(4):
        rings = [r if j == 0 else [(r[i - 1] + r[i] * 2 + r[(i + 1) % segs]) / 4 for i in range(segs)] for j, r in enumerate(rings)]
    return rings


def push_out(body, rings, centre, clearance, rows_from=0, reach=0.6):
    """Final guarantee for ring-built garments: every point stays at least
    `clearance` outside the body and all registered layers, measured along its
    own horizontal direction from the garment axis."""
    bvh = body.bvh_below()
    for j, ring in enumerate(rings):
        if j < rows_from:
            continue
        for i, p in enumerate(ring):
            c = Vector((centre.x, centre.y, p.z))
            d = p - c
            d.z = 0.0
            if d.length < 1e-6:
                continue
            d.normalize()
            cur = (p - c).dot(d)
            # Search from just outside the garment point inward: the first hit is
            # the outermost surface it must clear (a short reach ignores things far
            # outside, e.g. the other arm).
            start = cur + reach if reach < 0.6 else reach
            hit = bvh.ray_cast(c + d * start, -d, start)
            if hit[0] is None:
                continue
            need = (hit[0] - c).dot(d) + clearance
            if cur < need:
                ring[i] = p + d * (need - cur)
    return rings


def convexify(rings, centre, rows_from=0):
    """Stiff fabric bridges hollows: push every ring out onto its own 2-D convex
    hull (e.g. a capelet spans between the bust instead of following it)."""
    for j, ring in enumerate(rings):
        if j < rows_from:
            continue
        pts = [(p.x, p.y) for p in ring]
        hull = _hull2d(pts)
        n = len(hull)
        for i, p in enumerate(ring):
            d = Vector((p.x - centre.x, p.y - centre.y, 0.0))
            if d.length < 1e-6:
                continue
            d.normalize()
            best = None
            for k in range(n):
                ax, ay = hull[k]
                bx, by = hull[(k + 1) % n]
                ex, ey = bx - ax, by - ay
                den = d.x * ey - d.y * ex
                if abs(den) < 1e-12:
                    continue
                t = ((ax - centre.x) * ey - (ay - centre.y) * ex) / den
                u = ((ax - centre.x) * d.y - (ay - centre.y) * d.x) / den
                if t > 0 and -1e-6 <= u <= 1 + 1e-6:
                    best = t if best is None else max(best, t)
            cur = (p - Vector((centre.x, centre.y, p.z))).length
            if best is not None and best > cur:
                ring[i] = Vector((centre.x + d.x * best, centre.y + d.y * best, p.z))
    return rings


def _hull2d(pts):
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]
