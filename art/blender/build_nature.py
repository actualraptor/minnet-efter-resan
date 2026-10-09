"""Builds stylised nature and garden props as individual GLBs.

Foliage meshes carry a vertex colour attribute: R = sway weight (0 at trunk,
1 at outer canopy), G = random tint, used by the Godot foliage shader.
Objects suffixed -colonly are exported as collision for Godot."""
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_common as C  # noqa: E402

OUT = None


def export(name, objs, cols=(), preview_h=None):
    for o in objs:
        C.set_origin_world(o)
    ob = C.join(objs, name) if len(objs) > 1 else objs[0]
    ob.name = name
    col_objs = []
    for (cname, kind, a, b) in cols:
        if kind == "box":
            col_objs.append(C.box(cname + "-colonly", a, b))
        else:
            col_objs.append(C.cylinder(cname + "-colonly", a[0], a[1], b, material=None, segs=8))
    C.export_glb(os.path.join(OUT, f"{name}.glb"), [ob] + col_objs, animations=False)
    for o in col_objs:
        bpy.data.objects.remove(o)
    return ob


def foliage_colors(ob, center, radius, seed):
    rnd = random.Random(seed)
    tint = {}

    def fn(co, n):
        d = (co - Vector(center)).length / max(radius, 1e-3)
        key = (round(co.x * 3), round(co.y * 3), round(co.z * 3))
        if key not in tint:
            tint[key] = rnd.random()
        return (min(1.0, 0.35 + d * 0.65), tint[key], 0.0, 1.0)
    C.vertex_color_fill(ob, fn)


def trunk_colors(ob, height):
    C.vertex_color_fill(ob, lambda co, n: (max(0.0, co.z / height) * 0.3, 0.5, 0.0, 1.0))


def canopy(name, center, radius, mat, seed, blobs=9, squash=0.8, spread=1.0):
    rnd = random.Random(seed)
    parts = []
    for i in range(blobs):
        a = rnd.random() * math.tau
        r = (0.25 + rnd.random() * 0.55) * radius * spread
        z = (rnd.random() - 0.35) * radius * 0.7
        c = Vector(center) + Vector((math.cos(a) * r, math.sin(a) * r, z))
        if i == 0:
            c = Vector(center) + Vector((0, 0, radius * 0.25))
        br = radius * (0.45 + rnd.random() * 0.3)
        b = C.ellipsoid("Blob", c, (br, br, br * squash), mat, segs=14, rings=9)
        C.displace_noise(b, br * 0.09, 2.2, seed + i)
        parts.append(b)
    ob = C.join(parts, name)
    foliage_colors(ob, center, radius * 1.4, seed)
    return ob


def tree_oak(name, seed, h=5.2, crown=2.6):
    rnd = random.Random(seed)
    bark = C.mat("M_Bark", "#6b4c38", 0.9)
    leaves = C.mat("M_Leaves_Oak", "#5f9a48", 0.8)
    lean = Vector(((rnd.random() - 0.5) * 0.4, (rnd.random() - 0.5) * 0.4, 0))
    pts = [Vector((0, 0, -0.3)), Vector((0, 0, h * 0.25)) + lean * 0.3, Vector((0, 0, h * 0.5)) + lean * 0.7, Vector((0, 0, h * 0.68)) + lean]
    trunk = C.tube("Trunk", pts, [0.42, 0.3, 0.24, 0.18], bark, segs=10)
    parts = [trunk]
    # Root flare
    for i in range(5):
        a = i * math.tau / 5 + rnd.random()
        parts.append(C.tube("Root", [Vector((0, 0, 0.35)), Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, -0.05))], [0.16, 0.05], bark, segs=6))
    top = pts[-1]
    for i in range(3):
        a = i * math.tau / 3 + rnd.random()
        end = top + Vector((math.cos(a) * crown * 0.55, math.sin(a) * crown * 0.55, crown * 0.35))
        parts.append(C.tube("Branch", [pts[2], top.lerp(end, 0.5) + Vector((0, 0, 0.2)), end], [0.15, 0.1, 0.05], bark, segs=7))
    for p in parts:
        trunk_colors(p, h)
    crown_c = top + Vector((0, 0, crown * 0.55))
    can = canopy("Canopy", crown_c, crown, leaves, seed, blobs=11, squash=0.78)
    return export(name, parts + [can], cols=[("TrunkCol", "cyl", ((0, 0, -0.2), (0, 0, h * 0.6)), 0.35)])


def tree_birch(name, seed, h=7.0):
    rnd = random.Random(seed)
    bark = C.mat("M_BarkBirch", "#e8e2d6", 0.8)
    mark = C.mat("M_BarkMark", "#3d3632", 0.9)
    leaves = C.mat("M_Leaves_Birch", "#8cbf5a", 0.8)
    lean = Vector(((rnd.random() - 0.5) * 0.6, (rnd.random() - 0.5) * 0.6, 0))
    pts = [Vector((0, 0, -0.3)), Vector((0, 0, h * 0.3)) + lean * 0.2, Vector((0, 0, h * 0.65)) + lean * 0.7, Vector((0, 0, h * 0.95)) + lean]
    parts = [C.tube("Trunk", pts, [0.2, 0.16, 0.12, 0.06], bark, segs=9)]
    for i in range(10):
        z = 0.4 + i * h * 0.075
        t = z / (h * 0.95)
        c = Vector((0, 0, z)) + lean * (t ** 1.4)
        a = rnd.random() * math.tau
        r = 0.2 - 0.12 * t
        parts.append(C.ellipsoid("Mark", c + Vector((math.cos(a) * r, math.sin(a) * r, 0)), (0.06, 0.06, 0.018), mark, segs=6, rings=4))
    for p in parts:
        trunk_colors(p, h)
    cans = []
    for k, (zf, rr) in enumerate(((0.62, 1.4), (0.8, 1.2), (0.95, 0.85))):
        c = Vector((0, 0, h * zf)) + lean * zf + Vector(((rnd.random() - 0.5) * 0.5, (rnd.random() - 0.5) * 0.5, 0))
        cans.append(canopy("Canopy", c, rr, leaves, seed + k * 13, blobs=6, squash=0.9, spread=0.8))
    return export(name, parts + cans, cols=[("TrunkCol", "cyl", ((0, 0, -0.2), (0, 0, h * 0.6)), 0.2)])


def tree_pine(name, seed, h=9.0):
    rnd = random.Random(seed)
    bark = C.mat("M_Bark", "#6b4c38", 0.9)
    needles = C.mat("M_Leaves_Pine", "#3f6f4a", 0.85)
    parts = [C.tube("Trunk", [Vector((0, 0, -0.3)), Vector((0, 0, h * 0.9))], [0.32, 0.08], bark, segs=8)]
    trunk_colors(parts[0], h)
    tiers = 5
    for i in range(tiers):
        t = i / tiers
        z0 = h * (0.18 + t * 0.7)
        r = 1.9 * (1 - t * 0.78)
        cone = C.lathe("Tier", [(r, z0), (r * 0.7, z0 + 0.35), (0.05, z0 + h * 0.26)], 12, needles,
                       scale_xy=(1.0 + rnd.random() * 0.1, 1.0), cap_bottom=True)
        C.displace_noise(cone, 0.08, 1.8, seed + i)
        foliage_colors(cone, (0, 0, z0), r * 1.6, seed + i)
        parts.append(cone)
    return export(name, parts, cols=[("TrunkCol", "cyl", ((0, 0, -0.2), (0, 0, h * 0.5)), 0.3)])


def bush(name, seed, r=0.8, flowers=None):
    leaves = C.mat("M_Leaves_Bush", "#5a8f45", 0.8)
    parts = [canopy("Bush", (0, 0, r * 0.55), r, leaves, seed, blobs=6, squash=0.75)]
    if flowers:
        rnd = random.Random(seed + 1)
        fm = C.mat("M_BushFlower_" + flowers, flowers, 0.6)
        for i in range(22):
            a = rnd.random() * math.tau
            z = r * (0.3 + rnd.random() * 0.8)
            rr = r * (0.95 - 0.3 * abs(z / r - 0.6))
            f = C.ellipsoid("Bloom", (math.cos(a) * rr, math.sin(a) * rr, z), (0.06, 0.06, 0.05), fm, segs=8, rings=4)
            C.vertex_color_fill(f, lambda co, n: (1.0, 0.5, 0.0, 1.0))
            parts.append(f)
    return export(name, parts)


def rock(name, seed, size=(1.0, 0.8, 0.6), moss=True):
    stone = C.mat("M_Rock", "#9a958c", 0.95)
    ob = C.ellipsoid("Rock", (0, 0, size[2] * 0.35), size, stone, segs=12, rings=8)
    C.displace_noise(ob, min(size) * 0.18, 1.4, seed)
    for v in ob.data.vertices:
        if v.co.z < 0:
            v.co.z *= 0.5
        v.co.x += math.sin(v.co.z * 4 + seed) * 0.03
    parts = [ob]
    if moss:
        mm = C.mat("M_Moss", "#6f9a4c", 0.95)
        mo = C.ellipsoid("Moss", (size[0] * 0.15, 0, size[2] * 0.9), (size[0] * 0.6, size[1] * 0.55, size[2] * 0.25), mm, segs=10, rings=6)
        C.displace_noise(mo, 0.04, 2.0, seed + 3)
        parts.append(mo)
    for p in parts:
        p.data.polygons.foreach_set("use_smooth", [False] * len(p.data.polygons))
    return export(name, parts, cols=[("RockCol", "box", (0, 0, size[2] * 0.4), (size[0] * 0.8, size[1] * 0.8, size[2] * 0.6))])


def standing_stone(name, seed, h=1.5):
    stone = C.mat("M_Rock", "#9a958c", 0.95)
    ob = C.ellipsoid("Stone", (0, 0, h * 0.45), (0.35, 0.28, h * 0.55), stone, segs=10, rings=8)
    C.displace_noise(ob, 0.06, 1.5, seed)
    mm = C.mat("M_Moss", "#6f9a4c", 0.95)
    mo = C.ellipsoid("Moss", (0.05, -0.05, h * 0.95), (0.28, 0.24, 0.12), mm, segs=10, rings=5)
    C.displace_noise(mo, 0.03, 2.0, seed + 2)
    lichen = C.mat("M_Lichen", "#c9b87a", 0.95)
    li = C.ellipsoid("Lichen", (0.0, -0.27, h * 0.5), (0.12, 0.03, 0.1), lichen, segs=8, rings=4)
    return export(name, [ob, mo, li], cols=[("StoneCol", "box", (0, 0, h * 0.5), (0.3, 0.25, h * 0.5))])


def fence(name, length=2.4):
    wood = C.mat("M_FenceWood", "#8a6a4c", 0.85)
    parts = []
    for x in (0.0, length):
        parts.append(C.box("Post", (x, 0, 0.45), (0.06, 0.06, 0.6), wood, bevel=0.015))
        parts.append(C.box("PostCap", (x, 0, 1.07), (0.075, 0.075, 0.03), wood, bevel=0.01))
    for z in (0.45, 0.82):
        rail = C.box("Rail", (length / 2, 0, z), (length / 2, 0.035, 0.05), wood, bevel=0.01)
        rail.data.transform(Matrix.Translation((0, 0, 0)))
        parts.append(rail)
    return export(name, parts, cols=[("FenceCol", "box", (length / 2, 0, 0.55), (length / 2 + 0.05, 0.08, 0.55))])


def bench(name):
    wood = C.mat("M_BenchWood", "#946a48", 0.8)
    dark = C.mat("M_BenchDark", "#6e4b33", 0.8)
    parts = []
    for i in range(3):
        parts.append(C.box("Slat", (0, -0.15 + i * 0.15, 0.45), (0.85, 0.06, 0.025), wood, bevel=0.01))
    for i in range(2):
        parts.append(C.box("BackSlat", (0, 0.2, 0.68 + i * 0.18), (0.85, 0.025, 0.05), wood, bevel=0.01))
    for x in (-0.7, 0.7):
        parts.append(C.box("Leg", (x, -0.12, 0.22), (0.045, 0.045, 0.22), dark))
        parts.append(C.box("LegB", (x, 0.2, 0.45), (0.045, 0.045, 0.45), dark))
        parts.append(C.box("Arm", (x, 0.0, 0.63), (0.05, 0.25, 0.03), dark, bevel=0.01))
        parts.append(C.box("ArmPost", (x, -0.2, 0.55), (0.035, 0.035, 0.09), dark))
    return export(name, parts, cols=[("BenchCol", "box", (0, 0.0, 0.4), (0.9, 0.3, 0.4))])


def woodpile(name):
    wood = C.mat("M_Log", "#8c6040", 0.85)
    end = C.mat("M_LogEnd", "#d9b07a", 0.8)
    parts = []
    rows = [(5, 0.0), (4, 0.22), (3, 0.43), (2, 0.63)]
    for (n, z) in rows:
        for i in range(n):
            x = (i - (n - 1) / 2) * 0.24
            r = 0.1 + 0.015 * math.sin(i * 3 + z * 10)
            parts.append(C.cylinder("Log", (x, -0.55, z + 0.11), (x, 0.55, z + 0.11), r, material=wood, segs=8))
            parts.append(C.cylinder("LogEnd", (x, -0.56, z + 0.11), (x, -0.55, z + 0.11), r * 0.92, material=end, segs=8))
    parts.append(C.cylinder("Stump", (0.9, 0, 0.0), (0.9, 0, 0.45), 0.28, material=wood, segs=10))
    parts.append(C.cylinder("StumpTop", (0.9, 0, 0.45), (0.9, 0, 0.46), 0.26, material=end, segs=10))
    axe_h = C.mat("M_AxeHandle", "#b08860", 0.8)
    parts.append(C.cylinder("AxeHandle", (0.95, 0.05, 0.46), (1.1, 0.3, 0.95), 0.02, material=axe_h, segs=6))
    parts.append(C.box("AxeHead", (0.94, 0.03, 0.5), (0.02, 0.08, 0.06), C.mat("M_Iron", "#3a3633", 0.5, 0.6)))
    return export(name, parts, cols=[("PileCol", "box", (0.2, 0, 0.45), (0.85, 0.6, 0.45))])


def garden_bed(name):
    wood = C.mat("M_FenceWood", "#8a6a4c", 0.85)
    soil = C.mat("M_Soil", "#5e4330", 1.0)
    leaf = C.mat("M_Leaves_Veg", "#6aa64a", 0.8)
    parts = [C.box("BedSoil", (0, 0, 0.12), (1.2, 0.6, 0.1), soil, bevel=0.04)]
    for sy in (-1, 1):
        parts.append(C.box("BedPlankX", (0, sy * 0.62, 0.12), (1.25, 0.03, 0.13), wood))
    for sx in (-1, 1):
        parts.append(C.box("BedPlankY", (sx * 1.22, 0, 0.12), (0.03, 0.62, 0.13), wood))
    rnd = random.Random(5)
    for row in range(3):
        for i in range(7):
            # Pippa's carrots: some are, admittedly, upside down.
            x = -1.0 + i * 0.33 + rnd.random() * 0.06
            y = -0.35 + row * 0.35
            for k in range(3):
                a = k * 2.1 + rnd.random()
                tip = (x + math.cos(a) * 0.06, y + math.sin(a) * 0.06, 0.38 + rnd.random() * 0.08)
                l = C.tube("Sprout", [Vector((x, y, 0.2)), Vector(tip)], [0.012, 0.004], leaf, segs=4)
                C.vertex_color_fill(l, lambda co, n: (min(1.0, (co.z - 0.2) * 5), 0.5, 0.0, 1.0))
                parts.append(l)
    can_m = C.mat("M_Copper", "#b8734a", 0.4, 0.7)
    parts.append(C.cylinder("CanBody", (1.6, 0.2, 0.0), (1.6, 0.2, 0.28), 0.13, 0.11, material=can_m, segs=12))
    parts.append(C.tube("CanSpout", [Vector((1.5, 0.2, 0.1)), Vector((1.32, 0.2, 0.3))], [0.025, 0.018], can_m, segs=6))
    parts.append(C.tube("CanHandle", [Vector((1.6, 0.08, 0.28)), Vector((1.6, 0.2, 0.4)), Vector((1.6, 0.32, 0.28))], [0.012] * 3, can_m, segs=5))
    return export(name, parts, cols=[("BedCol", "box", (0, 0, 0.15), (1.25, 0.65, 0.15))])


def signpost(name):
    wood = C.mat("M_FenceWood", "#8a6a4c", 0.85)
    paint = C.mat("M_SignPaint", "#efe4cc", 0.8)
    parts = [C.box("Pole", (0, 0, 0.9), (0.06, 0.06, 1.0), wood, bevel=0.01)]
    for i, (yaw, z) in enumerate(((0.3, 1.6), (-2.6, 1.35))):
        b = C.box("Board", (0.42, 0, 0), (0.42, 0.025, 0.1), wood, bevel=0.01)
        t = C.box("Text", (0.42, -0.028, 0), (0.33, 0.004, 0.045), paint)
        for o in (b, t):
            o.data.transform(Matrix.Rotation(yaw, 4, "Z"))
            o.data.transform(Matrix.Translation((0, 0, z)))
        parts += [b, t]
    return export(name, parts, cols=[("SignCol", "box", (0, 0, 0.9), (0.08, 0.08, 0.9))])


def build(root):
    global OUT
    OUT = os.path.join(root, "game", "assets", "models", "nature")
    C.reset_scene()
    C.clear_mat_cache()
    built = []
    built.append(tree_oak("tree_oak_a", 1))
    built.append(tree_oak("tree_oak_b", 7, h=4.6, crown=2.3))
    built.append(tree_oak("tree_oak_c", 13, h=5.8, crown=3.0))
    built.append(tree_birch("tree_birch_a", 3))
    built.append(tree_birch("tree_birch_b", 9, h=6.2))
    built.append(tree_pine("tree_pine_a", 4))
    built.append(tree_pine("tree_pine_b", 11, h=7.5))
    built.append(bush("bush_a", 21))
    built.append(bush("bush_b", 22, r=0.6))
    built.append(bush("bush_rose", 23, r=0.7, flowers="#f08aa8"))
    built.append(bush("bush_white", 24, r=0.65, flowers="#fbf3e4"))
    built.append(rock("rock_a", 31))
    built.append(rock("rock_b", 32, (0.6, 0.5, 0.45)))
    built.append(rock("rock_c", 33, (1.6, 1.1, 0.9)))
    built.append(standing_stone("stone_standing_a", 41))
    built.append(standing_stone("stone_standing_b", 42, h=1.1))
    built.append(fence("fence_segment"))
    built.append(bench("bench"))
    built.append(woodpile("woodpile"))
    built.append(garden_bed("garden_bed"))
    built.append(signpost("signpost"))
    # Preview line-up
    x = 0.0
    for ob in built:
        ob.location.x = x
        x += 4.0
    C.render_preview(os.path.join(root, "art", "previews", "nature.png"), built, views=((15, "lineup"),),
                     height=12, look_z=3, elevation=12, size=(2400, 600), ortho=True)
    print("BUILT nature", len(built))


if __name__ == "__main__":
    build(C.repo_root())
