"""Builds Edda's cottage: stone base, timber-and-plaster walls, thatch-like
shingle roof, chimney, windows, flower boxes and a furnished interior.
Exports cottage.glb (static, with -col collision hints) and door.glb.

Footprint is centred on the origin; the game places it at WorldLayout.COTTAGE_POS.
Front door faces -Y in Blender (= +Z in Godot), i.e. south toward the road.
Interior floor top sits at FLOOR (matches WorldLayout.COTTAGE_FLOOR)."""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_common as C  # noqa: E402

W, D = 9.0, 7.0          # outer width (X) and depth (Y)
T = 0.3                  # wall thickness
FLOOR = 0.45             # interior floor top height
WALL_H = 3.2             # wall top above floor
DOOR_W, DOOR_H = 1.15, 2.2
DOOR_X = 0.0


def M():
    return {
        "stone": C.mat("M_Stone", "#9a948a", 0.9),
        "stone_dark": C.mat("M_StoneDark", "#7d776f", 0.95),
        "plaster": C.mat("M_Plaster", "#f1e6cf", 0.95),
        "timber": C.mat("M_Timber", "#6e4b33", 0.8),
        "roof": C.mat("M_Roof", "#a5574a", 0.85),
        "roof_dark": C.mat("M_RoofDark", "#86463d", 0.85),
        "floor": C.mat("M_FloorWood", "#a8794f", 0.75),
        "wood": C.mat("M_Wood", "#8c6040", 0.75),
        "wood_light": C.mat("M_WoodLight", "#bf9466", 0.75),
        "glass": C.mat("M_GlassGlow", "#ffe2a8", 0.2, emit=0.6),
        "frame": C.mat("M_WindowFrame", "#5f7f6a", 0.7),
        "door": C.mat("M_DoorPaint", "#4f7a8f", 0.7),
        "iron": C.mat("M_Iron", "#3a3633", 0.5, 0.6),
        "fabric_red": C.mat("M_FabricRose", "#c46a6a", 0.95),
        "fabric_cream": C.mat("M_FabricCream", "#efe4cc", 0.95),
        "fabric_plum": C.mat("M_FabricPlum", "#7b4f7a", 0.95),
        "fabric_sage": C.mat("M_FabricSage", "#8fb08a", 0.95),
        "soil": C.mat("M_Soil", "#5e4330", 1.0),
        "leaf": C.mat("M_Leaf", "#5d8f45", 0.8),
        "flower_a": C.mat("M_FlowerPink", "#f08aa8", 0.7),
        "flower_b": C.mat("M_FlowerYellow", "#f6d24a", 0.7),
        "flower_c": C.mat("M_FlowerBlue", "#7c90e8", 0.7),
        "fire": C.mat("M_FireGlow", "#ffa64a", 0.5, emit=4.0),
        "ember": C.mat("M_EmberGlow", "#ff6a2a", 0.5, emit=3.0),
        "book1": C.mat("M_Book1", "#7b4f7a", 0.8),
        "book2": C.mat("M_Book2", "#4f7a8f", 0.8),
        "book3": C.mat("M_Book3", "#a5574a", 0.8),
        "book4": C.mat("M_Book4", "#d8b25a", 0.8),
        "ceramic": C.mat("M_Ceramic", "#e9e2d6", 0.4),
        "copper": C.mat("M_Copper", "#b8734a", 0.4, 0.7),
        "candle": C.mat("M_CandleGlow", "#fff1c8", 0.5, emit=2.0),
    }


def wall_segments_x(y, x0, x1, holes, z0, z1, mat, name, thick=T):
    """A wall running along X at depth y with rectangular holes [(xa, xb, za, zb)]."""
    parts = []
    xs = sorted({x0, x1} | {h[0] for h in holes} | {h[1] for h in holes})
    for i in range(len(xs) - 1):
        a, b = xs[i], xs[i + 1]
        mid = (a + b) / 2
        spans = [(z0, z1)]
        for h in holes:
            if h[0] <= mid <= h[1]:
                spans = [(z0, h[2]), (h[3], z1)]
        for (za, zb) in spans:
            if zb - za > 0.01:
                parts.append(C.box(name, ((a + b) / 2, y, (za + zb) / 2), ((b - a) / 2, thick / 2, (zb - za) / 2), mat))
    return parts


def wall_segments_y(x, y0, y1, holes, z0, z1, mat, name, thick=T):
    parts = []
    ys = sorted({y0, y1} | {h[0] for h in holes} | {h[1] for h in holes})
    for i in range(len(ys) - 1):
        a, b = ys[i], ys[i + 1]
        mid = (a + b) / 2
        spans = [(z0, z1)]
        for h in holes:
            if h[0] <= mid <= h[1]:
                spans = [(z0, h[2]), (h[3], z1)]
        for (za, zb) in spans:
            if zb - za > 0.01:
                parts.append(C.box(name, (x, (a + b) / 2, (za + zb) / 2), (thick / 2, (b - a) / 2, (zb - za) / 2), mat))
    return parts


def window(cx, cy, cz, w, h, axis, mats, out):
    """Window frame + glowing panes + flower box. axis 'x' = wall along X."""
    f = mats["frame"]
    t = 0.07
    if axis == "x":
        out.append(C.box("WinFrameT", (cx, cy, cz + h / 2), (w / 2 + t, T / 2 + 0.03, t / 2), f))
        out.append(C.box("WinFrameB", (cx, cy, cz - h / 2), (w / 2 + t, T / 2 + 0.06, t / 2), f))
        out.append(C.box("WinFrameL", (cx - w / 2, cy, cz), (t / 2, T / 2 + 0.03, h / 2), f))
        out.append(C.box("WinFrameR", (cx + w / 2, cy, cz), (t / 2, T / 2 + 0.03, h / 2), f))
        out.append(C.box("WinMullion", (cx, cy, cz), (0.025, 0.04, h / 2), f))
        out.append(C.box("WinTransom", (cx, cy, cz), (w / 2, 0.04, 0.025), f))
        out.append(C.box("WinGlass", (cx, cy, cz), (w / 2, 0.01, h / 2), mats["glass"]))
        sgn = -1 if cy < 0 else 1
        by = cy + sgn * (T / 2 + 0.16)
        out.append(C.box("FlowerBox", (cx, by, cz - h / 2 - 0.14), (w / 2 + 0.05, 0.14, 0.11), mats["wood"], bevel=0.015))
        out.append(C.box("FlowerSoil", (cx, by, cz - h / 2 - 0.04), (w / 2, 0.12, 0.02), mats["soil"]))
        for i in range(9):
            px = cx - w / 2 + 0.08 + i * (w - 0.16) / 8
            mm = [mats["flower_a"], mats["flower_b"], mats["flower_c"]][i % 3]
            out.append(C.ellipsoid("BoxLeaf", (px, by + 0.02 * math.sin(i), cz - h / 2 + 0.02), (0.08, 0.07, 0.07), mats["leaf"], segs=8, rings=5))
            out.append(C.ellipsoid("BoxFlower", (px + 0.03, by - 0.03, cz - h / 2 + 0.1 + 0.03 * (i % 2)), (0.04, 0.04, 0.03), mm, segs=8, rings=4))
    else:
        out.append(C.box("WinFrameT", (cx, cy, cz + h / 2), (T / 2 + 0.03, w / 2 + t, t / 2), f))
        out.append(C.box("WinFrameB", (cx, cy, cz - h / 2), (T / 2 + 0.06, w / 2 + t, t / 2), f))
        out.append(C.box("WinFrameL", (cx, cy - w / 2, cz), (T / 2 + 0.03, t / 2, h / 2), f))
        out.append(C.box("WinFrameR", (cx, cy + w / 2, cz), (T / 2 + 0.03, t / 2, h / 2), f))
        out.append(C.box("WinMullion", (cx, cy, cz), (0.04, 0.025, h / 2), f))
        out.append(C.box("WinTransom", (cx, cy, cz), (0.04, w / 2, 0.025), f))
        out.append(C.box("WinGlass", (cx, cy, cz), (0.01, w / 2, h / 2), mats["glass"]))


def build(root):
    C.reset_scene()
    C.clear_mat_cache()
    m = M()
    vis = []      # visual meshes
    col = []      # collision-only boxes (exported with -colonly suffix)
    hx, hy = W / 2, D / 2
    top = FLOOR + WALL_H

    # --- Stone plinth & floor -------------------------------------------------
    vis.append(C.box("Plinth", (0, 0, FLOOR / 2 - 0.15), (hx + 0.12, hy + 0.12, FLOOR / 2 + 0.15), m["stone"], bevel=0.06))
    # Irregular foundation stones along the base for a hand-built look.
    k = 0
    for side in range(4):
        n = 14 if side % 2 == 0 else 11
        for i in range(n):
            t = (i + 0.5) / n
            if side == 0:
                p = (-hx + t * W, -hy - 0.13)
            elif side == 1:
                p = (hx + 0.13, -hy + t * D)
            elif side == 2:
                p = (hx - t * W, hy + 0.13)
            else:
                p = (-hx - 0.13, hy - t * D)
            k += 1
            s = 0.17 + 0.05 * math.sin(k * 2.3)
            vis.append(C.ellipsoid("FoundStone", (p[0], p[1], 0.18 + 0.05 * math.cos(k * 1.7)), (s * 1.4, 0.09, s * 0.75),
                                   m["stone_dark"] if k % 3 == 0 else m["stone"], segs=8, rings=5))
    vis.append(C.box("Floor", (0, 0, FLOOR - 0.03), (hx - T, hy - T, 0.03), m["floor"]))
    # Floor boards (thin seams).
    for i in range(1, 18):
        x = -hx + T + i * (W - 2 * T) / 18
        vis.append(C.box("Seam", (x, 0, FLOOR + 0.001), (0.006, hy - T, 0.002), m["timber"]))
    # Door step stones
    vis.append(C.box("Step", (DOOR_X, -hy - 0.55, 0.12), (0.8, 0.35, 0.14), m["stone"], bevel=0.05))
    vis.append(C.box("Step2", (DOOR_X, -hy - 0.25, 0.3), (0.75, 0.22, 0.14), m["stone_dark"], bevel=0.04))
    col.append(("StepCol", (DOOR_X, -hy - 0.45, 0.18), (0.8, 0.42, 0.2)))
    col.append(("FloorCol", (0, 0, FLOOR / 2 - 0.1), (hx + 0.12, hy + 0.12, FLOOR / 2 + 0.1)))

    # --- Walls ------------------------------------------------------------------
    door_hole = (DOOR_X - DOOR_W / 2, DOOR_X + DOOR_W / 2, FLOOR - 0.01, FLOOR + DOOR_H)
    win_front = [(-2.9, -1.7, FLOOR + 1.0, FLOOR + 2.1), (1.7, 2.9, FLOOR + 1.0, FLOOR + 2.1)]
    win_back = [(-2.6, -1.2, FLOOR + 1.0, FLOOR + 2.2), (1.4, 2.6, FLOOR + 1.0, FLOOR + 2.1)]
    win_side = [(-0.7, 0.7, FLOOR + 1.0, FLOOR + 2.1)]
    walls = []
    walls += wall_segments_x(-hy + T / 2, -hx, hx, [door_hole] + win_front, FLOOR, top, m["plaster"], "WallFront")
    walls += wall_segments_x(hy - T / 2, -hx, hx, win_back, FLOOR, top, m["plaster"], "WallBack")
    walls += wall_segments_y(-hx + T / 2, -hy + T, hy - T, win_side, FLOOR, top, m["plaster"], "WallLeft")
    walls += wall_segments_y(hx - T / 2, -hy + T, hy - T, [], FLOOR, top, m["plaster"], "WallRight")
    vis += walls
    # Collision for walls (boxes per segment, generous height).
    for w in walls:
        bb = [w.matrix_world @ Vector(c) for c in w.bound_box]
        mn = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        mx = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        col.append(("WallCol", tuple((mn + mx) / 2), tuple((mx - mn) / 2)))
    # Timber framing: corner posts, sill and top beams, a few braces.
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.append(C.box("Post", (sx * (hx - 0.1), sy * (hy - 0.1), FLOOR + WALL_H / 2), (0.13, 0.13, WALL_H / 2 + 0.02), m["timber"]))
    for sy in (-1, 1):
        vis.append(C.box("BeamTop", (0, sy * (hy - 0.08), top - 0.1), (hx + 0.02, 0.12, 0.11), m["timber"]))
        vis.append(C.box("BeamMid", (0, sy * (hy - 0.08), FLOOR + 0.9), (hx, 0.11, 0.06), m["timber"]))
    for sx in (-1, 1):
        vis.append(C.box("BeamTopS", (sx * (hx - 0.08), 0, top - 0.1), (0.12, hy, 0.11), m["timber"]))
    for (x0, x1) in ((-4.3, -3.2), (3.2, 4.3)):
        for sy in (-1, 1):
            vis.append(C.cylinder("Brace", (x0, sy * (hy + 0.0), FLOOR + 0.95), (x1, sy * (hy + 0.0), top - 0.2), 0.06, material=m["timber"], segs=6))
    # Interior posts/ceiling beams.
    for i in (-2.2, 0.0, 2.2):
        vis.append(C.box("CeilBeam", (i, 0, top - 0.05), (0.1, hy - T, 0.1), m["timber"]))

    # --- Windows & door frame -------------------------------------------------------
    for (a, b, za, zb) in win_front:
        window((a + b) / 2, -hy + T / 2, (za + zb) / 2, b - a, zb - za, "x", m, vis)
    for (a, b, za, zb) in win_back:
        window((a + b) / 2, hy - T / 2, (za + zb) / 2, b - a, zb - za, "x", m, vis)
    for (a, b, za, zb) in win_side:
        window(-hx + T / 2, (a + b) / 2, (za + zb) / 2, b - a, zb - za, "y", m, vis)
    vis.append(C.box("DoorLintel", (DOOR_X, -hy + T / 2, FLOOR + DOOR_H + 0.08), (DOOR_W / 2 + 0.15, T / 2 + 0.05, 0.1), m["timber"]))
    for sx in (-1, 1):
        vis.append(C.box("DoorJamb", (DOOR_X + sx * (DOOR_W / 2 + 0.06), -hy + T / 2, FLOOR + DOOR_H / 2), (0.07, T / 2 + 0.04, DOOR_H / 2), m["timber"]))
    # Lantern by the door.
    lan = (DOOR_X + 0.95, -hy - 0.12, FLOOR + 2.0)
    vis.append(C.box("LanternBody", lan, (0.08, 0.08, 0.12), m["iron"]))
    vis.append(C.box("LanternGlow", lan, (0.065, 0.085, 0.09), m["candle"]))

    # --- Roof (gabled, ridge along X) -----------------------------------------------------
    overhang = 0.6
    rise = 2.7
    ridge_z = top + rise
    half_span = hy + overhang
    slope_len = math.hypot(half_span, rise + 0.35)
    ang = math.atan2(rise + 0.35, half_span)
    rows = 9
    for sy in (-1, 1):
        for r in range(rows):
            t0 = r / rows
            # shingle rows, staggered tones for a hand-laid look
            yy = sy * (half_span * (1 - t0) - half_span / rows * 0.5)
            zz = top - 0.35 + (rise + 0.35) * t0 + (rise + 0.35) / rows * 0.5
            mm = m["roof"] if r % 2 == 0 else m["roof_dark"]
            panel = C.box("RoofRow", (0, 0, 0), (hx + overhang, slope_len / rows / 2 + 0.03, 0.06), mm, bevel=0.02)
            rot = Matrix.Rotation(-sy * ang, 4, "X")
            panel.data.transform(rot)
            panel.data.transform(Matrix.Translation((0, yy, zz + 0.06 * r * 0.0)))
            vis.append(panel)
    vis.append(C.cylinder("Ridge", (-hx - overhang, 0, ridge_z + 0.02), (hx + overhang, 0, ridge_z + 0.02), 0.13, material=m["timber"], segs=8))
    # Gable triangles (plaster with timber).
    for sx in (-1, 1):
        import bmesh
        bm = bmesh.new()
        x = sx * (hx - T / 2)
        vs = [bm.verts.new((x - sx * T / 2, -hy, top)), bm.verts.new((x - sx * T / 2, hy, top)), bm.verts.new((x - sx * T / 2, 0, ridge_z)),
              bm.verts.new((x + sx * T / 2, -hy, top)), bm.verts.new((x + sx * T / 2, hy, top)), bm.verts.new((x + sx * T / 2, 0, ridge_z))]
        bm.faces.new((vs[0], vs[1], vs[2]))
        bm.faces.new((vs[3], vs[5], vs[4]))
        bm.faces.new((vs[0], vs[3], vs[4], vs[1]))
        bm.faces.new((vs[1], vs[4], vs[5], vs[2]))
        bm.faces.new((vs[2], vs[5], vs[3], vs[0]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        vis.append(C.mesh_obj("Gable", bm, m["plaster"], smooth=False))
        vis.append(C.cylinder("GableBeam", (x + sx * 0.17, -hy, top + 0.05), (x + sx * 0.17, 0, ridge_z), 0.07, material=m["timber"], segs=6))
        vis.append(C.cylinder("GableBeam", (x + sx * 0.17, hy, top + 0.05), (x + sx * 0.17, 0, ridge_z), 0.07, material=m["timber"], segs=6))
        vis.append(C.cylinder("GablePost", (x + sx * 0.17, 0, top), (x + sx * 0.17, 0, ridge_z), 0.06, material=m["timber"], segs=6))
    # Interior ceiling (so the roof reads from inside as a cosy loft).
    vis.append(C.box("Ceiling", (0, 0, top + 0.02), (hx - T, hy - T, 0.02), m["wood_light"]))
    col.append(("RoofCol", (0, 0, top + 0.6), (hx + 0.3, hy + 0.3, 0.5)))

    # --- Chimney & fireplace (right wall) ---------------------------------------------------
    cx = hx - 0.55
    cy = 1.2
    vis.append(C.box("Chimney", (cx + 0.35, cy, (ridge_z + 1.0) / 2 + 0.3), (0.5, 0.55, (ridge_z + 1.0) / 2 - 0.3 + 0.3), m["stone"], bevel=0.04))
    vis.append(C.box("ChimneyCap", (cx + 0.35, cy, ridge_z + 1.05), (0.58, 0.63, 0.08), m["stone_dark"], bevel=0.03))
    vis.append(C.box("Hearth", (cx - 0.35, cy, FLOOR + 0.06), (0.55, 0.85, 0.06), m["stone_dark"], bevel=0.03))
    vis.append(C.box("FireBack", (cx - 0.05, cy, FLOOR + 0.7), (0.25, 0.8, 0.7), m["stone"], bevel=0.04))
    vis.append(C.box("FireOpeningDark", (cx - 0.31, cy, FLOOR + 0.5), (0.02, 0.45, 0.4), C.mat("M_Soot", "#2a2422", 1.0)))
    vis.append(C.box("Mantel", (cx - 0.33, cy, FLOOR + 1.45), (0.18, 0.95, 0.06), m["timber"], bevel=0.02))
    vis.append(C.box("ChimneyBreast", (cx - 0.1, cy, FLOOR + 2.4), (0.25, 0.65, 0.9), m["stone"], bevel=0.03))
    for i, (dy, dz) in enumerate(((-0.12, 0.0), (0.1, 0.02), (0.0, 0.09))):
        vis.append(C.cylinder("Log", (cx - 0.45, cy + dy - 0.25, FLOOR + 0.18 + dz), (cx - 0.45, cy + dy + 0.25, FLOOR + 0.18 + dz), 0.07, material=m["wood"], segs=7))
    vis.append(C.ellipsoid("Flame", (cx - 0.45, cy, FLOOR + 0.42), (0.1, 0.28, 0.22), m["fire"], segs=8, rings=6))
    vis.append(C.ellipsoid("Embers", (cx - 0.45, cy, FLOOR + 0.16), (0.16, 0.32, 0.05), m["ember"], segs=8, rings=4))
    col.append(("FireCol", (cx - 0.1, cy, FLOOR + 1.2), (0.45, 0.9, 1.2)))
    # Mantel clutter: candles, jars, a small framed sketch (Jonas's daisies, of course).
    for i, dy in enumerate((-0.7, -0.45, 0.5, 0.75)):
        if i % 2 == 0:
            vis.append(C.cylinder("Candle", (cx - 0.33, cy + dy, FLOOR + 1.51), (cx - 0.33, cy + dy, FLOOR + 1.68), 0.025, material=m["fabric_cream"], segs=8))
            vis.append(C.ellipsoid("CandleFlame", (cx - 0.33, cy + dy, FLOOR + 1.71), (0.012, 0.012, 0.025), m["candle"], segs=6, rings=4))
        else:
            vis.append(C.cylinder("Jar", (cx - 0.33, cy + dy, FLOOR + 1.51), (cx - 0.33, cy + dy, FLOOR + 1.64), 0.045, material=m["copper"] if i == 1 else m["ceramic"], segs=10))
    vis.append(C.box("SketchFrame", (cx - 0.37, cy, FLOOR + 1.78), (0.015, 0.18, 0.14), m["timber"]))
    vis.append(C.box("Sketch", (cx - 0.385, cy, FLOOR + 1.78), (0.005, 0.15, 0.11), m["fabric_cream"]))
    for j in range(3):
        vis.append(C.ellipsoid("SketchDaisy", (cx - 0.392, cy - 0.07 + j * 0.07, FLOOR + 1.76 + 0.03 * (j % 2)), (0.003, 0.025, 0.025), m["flower_b"], segs=6, rings=4))
    # Kettle on a hook
    vis.append(C.ellipsoid("Kettle", (cx - 0.5, cy + 0.3, FLOOR + 0.55), (0.12, 0.12, 0.1), m["iron"], segs=10, rings=6))

    # --- Furniture ------------------------------------------------------------------------
    # Bed (back-left corner)
    bx, by = -hx + 1.2, hy - 1.25
    vis.append(C.box("BedFrame", (bx, by, FLOOR + 0.25), (0.85, 1.0, 0.18), m["wood"], bevel=0.03))
    vis.append(C.box("BedHead", (bx, hy - T - 0.08, FLOOR + 0.6), (0.9, 0.06, 0.45), m["wood"], bevel=0.03))
    vis.append(C.box("Mattress", (bx, by - 0.02, FLOOR + 0.5), (0.78, 0.93, 0.09), m["fabric_cream"], bevel=0.05, smooth=True))
    vis.append(C.box("Quilt", (bx, by - 0.3, FLOOR + 0.6), (0.82, 0.66, 0.035), m["fabric_red"], bevel=0.03, smooth=True))
    for qx in (-0.4, 0.0, 0.4):
        for qy in (-0.5, -0.1):
            vis.append(C.box("QuiltPatch", (bx + qx, by + qy - 0.2, FLOOR + 0.64), (0.17, 0.17, 0.006), m["fabric_plum"] if (qx + qy) > -0.2 else m["fabric_sage"]))
    vis.append(C.ellipsoid("Pillow", (bx, hy - T - 0.4, FLOOR + 0.64), (0.5, 0.2, 0.09), m["fabric_cream"], segs=12, rings=6))
    col.append(("BedCol", (bx, by, FLOOR + 0.35), (0.9, 1.05, 0.35)))
    # Table + chairs (centre-left)
    tx, ty = -1.3, -0.4
    vis.append(C.box("TableTop", (tx, ty, FLOOR + 0.76), (0.75, 0.48, 0.035), m["wood_light"], bevel=0.015))
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.append(C.box("TableLeg", (tx + sx * 0.66, ty + sy * 0.4, FLOOR + 0.37), (0.04, 0.04, 0.37), m["wood"]))
    vis.append(C.box("Runner", (tx, ty, FLOOR + 0.8), (0.55, 0.16, 0.004), m["fabric_sage"]))
    vis.append(C.cylinder("Vase", (tx + 0.1, ty, FLOOR + 0.8), (tx + 0.1, ty, FLOOR + 0.98), 0.05, 0.04, material=m["ceramic"], segs=10))
    for i in range(5):
        a = i * 1.25
        vis.append(C.ellipsoid("VaseFlower", (tx + 0.1 + math.cos(a) * 0.05, ty + math.sin(a) * 0.05, FLOOR + 1.04 + 0.03 * (i % 2)), (0.03, 0.03, 0.025),
                               [m["flower_a"], m["flower_b"], m["flower_c"]][i % 3], segs=8, rings=4))
    vis.append(C.cylinder("Cup", (tx - 0.35, ty + 0.1, FLOOR + 0.8), (tx - 0.35, ty + 0.1, FLOOR + 0.89), 0.04, material=m["ceramic"], segs=10))
    vis.append(C.cylinder("Teapot", (tx - 0.1, ty - 0.2, FLOOR + 0.8), (tx - 0.1, ty - 0.2, FLOOR + 0.96), 0.08, 0.06, material=m["fabric_plum"], segs=12))
    vis.append(C.box("Notebook", (tx + 0.4, ty + 0.15, FLOOR + 0.81), (0.11, 0.15, 0.015), m["book1"], bevel=0.005))
    col.append(("TableCol", (tx, ty, FLOOR + 0.4), (0.75, 0.48, 0.4)))
    for (chx, chy, yaw) in ((tx - 1.0, ty, 0), (tx + 1.0, ty + 0.1, math.pi)):
        ch = []
        ch.append(C.box("ChairSeat", (0, 0, FLOOR + 0.45), (0.22, 0.22, 0.03), m["wood"]))
        for sx in (-1, 1):
            for sy in (-1, 1):
                ch.append(C.box("ChairLeg", (sx * 0.18, sy * 0.18, FLOOR + 0.22), (0.025, 0.025, 0.22), m["wood"]))
        ch.append(C.box("ChairBack", (-0.2, 0, FLOOR + 0.75), (0.025, 0.22, 0.28), m["wood"]))
        ch.append(C.box("ChairCushion", (0, 0, FLOOR + 0.49), (0.19, 0.19, 0.02), m["fabric_red"], bevel=0.01))
        chair = C.join(ch, "Chair")
        chair.data.transform(Matrix.Rotation(yaw, 4, "Z"))
        chair.data.transform(Matrix.Translation((chx, chy, 0)))
        vis.append(chair)
        col.append(("ChairCol", (chx, chy, FLOOR + 0.45), (0.24, 0.24, 0.45)))
    # Armchair by the fire with a knitting basket.
    ax, ay = cx - 1.5, cy - 1.3
    ac = [C.box("ArmSeat", (ax, ay, FLOOR + 0.42), (0.38, 0.38, 0.12), m["fabric_plum"], bevel=0.05, smooth=True),
          C.box("ArmBack", (ax - 0.32, ay, FLOOR + 0.85), (0.1, 0.38, 0.38), m["fabric_plum"], bevel=0.05, smooth=True),
          C.box("ArmL", (ax, ay - 0.35, FLOOR + 0.62), (0.36, 0.07, 0.16), m["fabric_plum"], bevel=0.04, smooth=True),
          C.box("ArmR", (ax, ay + 0.35, FLOOR + 0.62), (0.36, 0.07, 0.16), m["fabric_plum"], bevel=0.04, smooth=True),
          C.box("ArmBase", (ax, ay, FLOOR + 0.16), (0.38, 0.4, 0.15), m["wood"], bevel=0.02)]
    vis.append(C.join(ac, "Armchair"))
    col.append(("ArmchairCol", (ax, ay, FLOOR + 0.5), (0.42, 0.44, 0.5)))
    vis.append(C.cylinder("Basket", (ax + 0.2, ay - 0.75, FLOOR), (ax + 0.2, ay - 0.75, FLOOR + 0.22), 0.18, 0.21, material=m["wood_light"], segs=12))
    vis.append(C.ellipsoid("Yarn", (ax + 0.15, ay - 0.75, FLOOR + 0.25), (0.08, 0.08, 0.07), m["fabric_sage"], segs=10, rings=6))
    vis.append(C.ellipsoid("Yarn2", (ax + 0.27, ay - 0.7, FLOOR + 0.24), (0.07, 0.07, 0.06), m["fabric_red"], segs=10, rings=6))
    # Rug
    vis.append(C.ellipsoid("Rug", (-0.2, 0.3, FLOOR + 0.005), (1.6, 1.1, 0.008), m["fabric_red"], segs=24, rings=4))
    vis.append(C.ellipsoid("RugInner", (-0.2, 0.3, FLOOR + 0.01), (1.25, 0.8, 0.008), m["fabric_cream"], segs=24, rings=4))
    # Shelves with books on the back wall.
    shx = 0.6
    for level in range(3):
        z = FLOOR + 1.1 + level * 0.45
        vis.append(C.box("Shelf", (shx, hy - T - 0.16, z), (0.75, 0.15, 0.025), m["wood"]))
        x = shx - 0.68
        i = 0
        while x < shx + 0.6:
            bw = 0.035 + 0.02 * ((i * 7) % 3) / 2
            bh = 0.16 + 0.06 * ((i * 5) % 4) / 3
            tilt = 0.0 if i % 9 else 0.25
            b = C.box("Book", (0, 0, bh / 2), (bw / 2, 0.11, bh / 2), [m["book1"], m["book2"], m["book3"], m["book4"]][i % 4])
            b.data.transform(Matrix.Rotation(tilt, 4, "Y"))
            b.data.transform(Matrix.Translation((x, hy - T - 0.16, z + 0.025)))
            vis.append(b)
            x += bw + 0.008 + (0.06 if i % 9 == 8 else 0)
            i += 1
        if level == 1:
            vis.append(C.cylinder("ShelfJar", (shx + 0.62, hy - T - 0.16, z + 0.03), (shx + 0.62, hy - T - 0.16, z + 0.2), 0.05, material=m["copper"], segs=10))
    for sx in (-1, 1):
        vis.append(C.box("ShelfBracket", (shx + sx * 0.7, hy - T - 0.12, FLOOR + 1.55), (0.02, 0.11, 0.5), m["timber"]))
    # Dresser / kitchen counter on the left of the door with plates.
    kx, ky = -hx + 0.6, -hy + 1.7
    vis.append(C.box("Counter", (kx, ky, FLOOR + 0.45), (0.28, 0.9, 0.45), m["wood"], bevel=0.02))
    vis.append(C.box("CounterTop", (kx, ky, FLOOR + 0.92), (0.31, 0.93, 0.025), m["wood_light"]))
    for j in range(4):
        vis.append(C.cylinder("Plate", (kx - 0.1, ky - 0.6 + j * 0.4, FLOOR + 1.12), (kx - 0.12, ky - 0.6 + j * 0.4, FLOOR + 1.12), 0.14, material=m["ceramic"], segs=16))
    vis.append(C.box("PlateRail", (kx - 0.08, ky, FLOOR + 1.0), (0.02, 0.92, 0.02), m["timber"]))
    vis.append(C.ellipsoid("Bread", (kx, ky + 0.5, FLOOR + 1.0), (0.14, 0.09, 0.06), m["wood_light"], segs=10, rings=6))
    col.append(("CounterCol", (kx, ky, FLOOR + 0.5), (0.32, 0.94, 0.5)))
    # Hanging herbs from a ceiling beam.
    for i in range(6):
        hxp = -2.2
        hyp = -1.8 + i * 0.32
        vis.append(C.cylinder("HerbString", (hxp, hyp, top - 0.15), (hxp, hyp, top - 0.45), 0.004, material=m["timber"], segs=4))
        vis.append(C.ellipsoid("Herb", (hxp, hyp, top - 0.55), (0.06, 0.06, 0.13), m["leaf"] if i % 2 else m["fabric_sage"], segs=8, rings=5))

    # --- Export ---------------------------------------------------------------------------
    for o in vis:
        C.set_origin_world(o)
    house = C.join(vis, "Cottage")
    col_objs = []
    for (name, c, h) in col:
        o = C.box(name + "-colonly", c, h)
        col_objs.append(o)
    out = os.path.join(root, "game", "assets", "models", "buildings")
    C.export_glb(os.path.join(out, "cottage.glb"), [house] + col_objs, animations=False)
    for o in col_objs:
        o.hide_render = True
    C.render_preview(os.path.join(root, "art", "previews", "cottage.png"), [house],
                     views=((20, "front"), (160, "back")), height=9.5, look_z=3.0, elevation=18, size=(1600, 700))
    for o in col_objs:
        bpy.data.objects.remove(o)

    # Door: separate GLB; hinge at the origin (left edge), panel extends +X.
    C.reset_scene()
    C.clear_mat_cache()
    m = M()
    parts = [C.box("DoorPanel", (DOOR_W / 2, 0, DOOR_H / 2), (DOOR_W / 2 - 0.01, 0.045, DOOR_H / 2 - 0.01), m["door"], bevel=0.015)]
    for z in (0.35, 1.1, 1.85):
        parts.append(C.box("DoorBrace", (DOOR_W / 2, -0.05, z), (DOOR_W / 2 - 0.06, 0.012, 0.05), m["timber"]))
    for z in (0.35, 1.85):
        parts.append(C.box("Hinge", (0.18, -0.06, z), (0.16, 0.008, 0.035), m["iron"]))
    parts.append(C.ellipsoid("Knob", (DOOR_W - 0.14, -0.08, 1.05), (0.035, 0.035, 0.035), m["copper"], segs=10, rings=6))
    parts.append(C.ellipsoid("KnobIn", (DOOR_W - 0.14, 0.08, 1.05), (0.035, 0.035, 0.035), m["copper"], segs=10, rings=6))
    parts.append(C.box("DoorWindow", (DOOR_W / 2, 0, 1.75), (0.14, 0.05, 0.12), m["glass"]))
    door = C.join(parts, "Door")
    C.export_glb(os.path.join(out, "door.glb"), [door], animations=False)
    print("BUILT cottage")


if __name__ == "__main__":
    build(C.repo_root())
