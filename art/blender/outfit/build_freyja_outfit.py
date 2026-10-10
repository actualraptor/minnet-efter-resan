"""Freyja's base outfit, tailored to a VRoid / VRM body.

    blender -b --factory-startup --python art/blender/outfit/build_freyja_outfit.py -- <repo_root> [body.vrm] [stage]

Design (her own look, Frieren-inspired travelling mage, palette from her sheet):
  tights      - dark plum-brown, fitted
  blouse      - cream, high collar, puffed sleeves gathered into fitted cuffs
  corset      - brown leather waist cincher with gold buckles (over the blouse)
  skirt       - sage A-line, above the knee, plum front/side inserts, gold hem trim
  petticoat   - cream ruffle peeking under the hem (shares the skirt's chains)
  capelet     - sage, rounded, to mid upper arm, gold trim, leaf clasp
  boots       - brown knee boots with a folded cuff
"""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(HERE))
import lib_common as C  # noqa: E402
import tailor as T  # noqa: E402
import rig_outfit as R  # noqa: E402

META = {}

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = os.path.abspath(ARGS[0]) if ARGS else os.getcwd()
_FREYJA = os.path.join(ROOT, "art", "source", "vroid", "freyja.glb")   # her VRM, copied as .glb
BODY = ARGS[1] if len(ARGS) > 1 and ARGS[1] != "-" else (_FREYJA if os.path.exists(_FREYJA) else os.path.join(ROOT, "art", "source", "vroid_ref", "base_female.glb"))
STAGE = ARGS[2] if len(ARGS) > 2 else "preview"

PAL = {
    "cream": "#f1efe9", "linen": "#e4e7ea", "sage": "#8fa781", "sage_dark": "#6f8763", "plum": "#6b3f63",
    "leather": "#6a4630", "leather_dark": "#4a3122", "gold": "#c9a24a", "tights": "#2c2229",
}


def mats():
    return {k: C.mat("M_Outfit_" + k, v, rough=0.35 if k == "gold" else 0.8, metal=0.6 if k == "gold" else 0.0) for k, v in PAL.items()}


def _paint(name, w, h, fn):
    """Small painted texture: fn(u, v) arrays (0..1, v=0 at top) -> rgb in sRGB."""
    import numpy as np
    u, v = np.meshgrid(np.linspace(0, 1, w), np.linspace(0, 1, h))
    rgb = fn(u, v)
    a = np.ones((h, w, 4), np.float32)
    a[..., :3] = rgb[::-1]  # byte images take sRGB values  # Blender images start at the bottom row
    img = bpy.data.images.new(name, w, h)
    img.pixels.foreach_set(a.ravel())
    img.pack()
    return img


def _hex(c):
    import numpy as np
    return np.array([int(c[i:i + 2], 16) / 255 for i in (1, 3, 5)])


def skirt_material():
    """Sage skirt with plum inserts (front and both sides) widening to the hem,
    gold hem band with a thin plum line above it. U runs around (0 = her left,
    0.75 = front), V from waist (0) to hem (1)."""
    import numpy as np
    sage, plum, gold, dark = _hex(PAL["sage"]), _hex(PAL["plum"]), _hex(PAL["gold"]), _hex(PAL["sage_dark"])

    def fn(u, v):
        rgb = np.ones(u.shape + (3,)) * sage
        ang = u * 360.0
        for c, hw in ((270, 13), (0, 9), (180, 9), (360, 9)):
            d = np.abs((ang - c + 180) % 360 - 180)
            width = hw * (0.25 + 0.75 * v ** 0.8)
            ins = d < width
            rgb[ins] = plum
            edge = (np.abs(d - width) < 0.9) & (v > 0.05)
            rgb[edge] = gold
        rgb[(v > 0.915) & (v < 0.975)] = gold
        rgb[(v > 0.885) & (v < 0.9)] = plum
        rgb[v < 0.035] = dark            # waistband
        rgb *= (0.97 + 0.03 * np.sin(u * np.pi * 2 * 14))[..., None]  # soft fold shading
        return rgb
    m = bpy.data.materials.new("M_Outfit_Skirt")
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = _paint("freyja_skirt", 1024, 256, fn)
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    return m


def build(body):
    M = mats()
    J = body.joint
    hips, spine, chest = J("Hips"), J("Spine"), J("Chest")
    upper = J("UpperChest") if body.has("UpperChest") else chest
    neck = J("Neck")
    waist_z = spine.z + 0.02
    crotch_z = (J("LeftUpperLeg").z + J("LeftLowerLeg").z) * 0.5 - 0.17  # just below the hip joints
    out = {}

    # --- tights: hips and legs, down into the boots ----------------------------------
    knee = J("LeftLowerLeg")
    out["Tights"] = T.fitted(
        body, "Tights",
        offset_fn=lambda p: 0.0015,
        keep_fn=lambda p: p.z < waist_z + 0.03 and abs(p.x) < 0.3,
        cuts=[((0, 0, waist_z), (0, 0, 1)), ((0, 0, J("LeftFoot").z - 0.02), (0, 0, -1))],
        smooth=0, material=M["tights"])
    T.subdivide(out["Tights"], 1)
    T.drape_relax(out["Tights"], body, 0.0025, rounds=2, smooth_iter=3, factor=0.4)
    body.add_layer(out["Tights"])

    # --- blouse: torso from the hip line up to a high collar, puffed sleeves ------------
    lw, rw = J("LeftHand"), J("RightHand")
    lua, rua = J("LeftUpperArm"), J("RightUpperArm")

    def blouse_offset(p):
        base = 0.004
        for ua, wr in ((lua, lw), (rua, rw)):
            t, d = T.seg_param(p, ua, wr)
            if -0.05 < t < 1.05 and abs(p.x) > abs(ua.x) - 0.02:
                # Puff: swell over the upper arm and forearm, gather at the cuff.
                puff = 0.026 * math.sin(math.pi * min(1.0, max(0.0, (t - 0.05) / 0.8))) ** 1.2
                cuff = T.smoothstep(0.8, 0.9, t)
                return base + puff * (1 - cuff) + 0.003 * cuff
        return base

    out["Blouse"] = T.fitted(
        body, "Blouse",
        offset_fn=blouse_offset,
        keep_fn=lambda p: p.z > waist_z - 0.1 and p.z < neck.z + 0.06,
        # Tucked in: the hem ends inside the skirt waistband.
        cuts=[((0, 0, waist_z - 0.075), (0, 0, -1)), ((0, 0, neck.z + 0.035), (0, 0, 1)),
              (lw + Vector((-0.012, 0, 0)), (1, 0, 0)), (rw + Vector((0.012, 0, 0)), (-1, 0, 0))],
        smooth=0, material=M["linen"])
    T.subdivide(out["Blouse"], 1)
    T.drape_relax(out["Blouse"], body, 0.005, rounds=5, smooth_iter=15)
    body.add_layer(out["Blouse"])

    # --- corset: waist cincher over the blouse, under-bust to high hip ---------------
    cz0, cz1 = waist_z - 0.075, chest.z + 0.015
    out["Corset"] = T.fitted(
        body, "Corset",
        offset_fn=lambda p: 0.013,
        keep_fn=lambda p: cz0 - 0.02 < p.z < cz1 + 0.02 and abs(p.x) < 0.2,
        cuts=[((0, 0, cz0), (0, 0, -1)), ((0, 0, cz1), (0, 0, 1))],
        smooth=0, material=M["leather"])
    T.drape_relax(out["Corset"], body, 0.012, rounds=3, smooth_iter=10)
    front_y = min(v.co.y for v in out["Corset"].data.vertices if abs(v.co.x) < 0.01)
    for k in range(4):
        z = cz0 + 0.022 + k * (cz1 - cz0 - 0.03) / 3
        out[f"Buckle{k}"] = C.box(f"Buckle{k}", (0.0, front_y - 0.004, z), (0.012, 0.004, 0.008), M["gold"], bevel=0.002)

    # --- skirt + petticoat: A-line around the hips, chain-driven ----------------------
    knee_z = J("LeftLowerLeg").z
    top_z = waist_z - 0.035
    hem_z = knee_z + 0.07
    ctr = T.centre_at(body, top_z)
    segs, rows = 128, 24   # fine enough that the toon ramp doesn't snap per quad
    # Widest leg/hip extent per angle at hip level -> hem radius clears the legs.
    def hip_r(a):
        return max((body.ring_radius(Vector((ctr.x, ctr.y, z)), (0, 0, 1), (1, 0, 0), a, start_r=0.45) or 0.15)
                   for z in (top_z - 0.08, top_z - 0.15, hips.z - 0.12))
    # Waistband sits over the blouse (5 mm) and under the corset (13 mm).
    top_r = [ (body.ring_radius(Vector((ctr.x, ctr.y, top_z)), (0, 0, 1), (1, 0, 0), 360 * i / segs, start_r=0.4) or 0.13) + 0.004
              for i in range(segs)]
    wide = [hip_r(360 * i / segs) for i in range(segs)]

    def skirt_rings(inset, extra_drop, folds, fold_amp):
        rings = []
        for j in range(rows + 1):
            t = j / rows
            z = top_z + (hem_z - extra_drop - top_z) * t
            ring = []
            for i in range(segs):
                a = math.tau * i / segs
                # Hug the waist, then flare (A-line) to clear the hips by 4-6 cm.
                flare = T.smoothstep(0.0, 0.4, t)
                r = top_r[i] * (1 - flare) + (wide[i] + 0.03 + 0.045 * t) * flare
                r += fold_amp * t ** 1.4 * math.sin(a * folds) - inset
                ring.append(Vector((ctr.x + math.cos(a) * r, ctr.y + math.sin(a) * r * 0.92, z)))
            rings.append(ring)
        return rings

    # Plum inserts: front centre and both sides (angles: 270 = front, 0 = her left).
    def skirt_mat(j, i):
        a = 360.0 * (i + 0.5) / segs
        if j >= rows - 1:
            return 2                         # gold hem band
        for c, hw in ((270, 12), (5, 9), (185, 9)):
            if abs((a - c + 180) % 360 - 180) < hw * (0.4 + 0.6 * j / rows):
                return 1
        return 0
    pet_rings = T.push_out(body, skirt_rings(0.008, 0.028, 23, 0.006), ctr, 0.006)
    out["Petticoat"] = T.revolve("Petticoat", pet_rings, segs, M["cream"])
    body.add_layer(out["Petticoat"])
    sk_rings = T.push_out(body, skirt_rings(0.0, 0.0, 14, 0.008), ctr, 0.005)
    out["Skirt"] = T.revolve("Skirt", sk_rings, segs, skirt_material())
    META.update(skirt_rings=sk_rings, skirt_centre=ctr, skirt_top=top_z, skirt_hem=hem_z)
    body.add_layer(out["Skirt"])
    body.add_layer(out["Corset"])

    # --- capelet: draped over the shoulders, short at the sides ----------------------
    nk = T.centre_at(body, neck.z - 0.012, x_max=0.12)
    # Sides end just past the shoulder joint (measured), front/back scale with her height.
    side_len = abs(lua.x - nk.x) * 0.95
    fb_len = 0.25 * body.height / 1.6
    def cape_len(a):
        side = abs(math.cos(math.radians(a))) ** 1.5      # 1 at her left/right
        return fb_len * (1 - side) + side_len * side
    rings = T.drop_cloth(body, nk, cape_len, segs=128, rows=20, clearance=0.008, r0=0.058, z_cap=neck.z + 0.01)
    rings = T.push_out(body, rings, nk, 0.008, rows_from=1, reach=0.06)
    rings = T.convexify(rings, nk, rows_from=4)
    META.update(cape_rings=rings, cape_centre=nk)
    def cape_mat(j, i):
        return 1 if j >= 19 else 0
    out["Capelet"] = T.revolve("Capelet", rings, 128, [M["sage"], M["gold"]], cape_mat)
    fy = min(p.y for p in rings[3])
    out["Clasp"] = C.ellipsoid("Clasp", (0.0, fy - 0.006, rings[3][54].z), (0.016, 0.006, 0.022), M["gold"], segs=10, rings=6)

    # --- boots: fitted over foot and calf, folded cuff --------------------------------
    boot_top = J("LeftLowerLeg").z - 0.1
    out["Boots"] = T.fitted(
        body, "Boots",
        offset_fn=lambda p: 0.006 + 0.01 * T.smoothstep(boot_top - 0.05, boot_top, p.z),
        keep_fn=lambda p: p.z < boot_top + 0.02,
        cuts=[((0, 0, boot_top), (0, 0, 1))],
        smooth=0, material=M["leather_dark"])
    T.subdivide(out["Boots"], 1)
    T.drape_relax(out["Boots"], body, 0.006, rounds=2, smooth_iter=4, factor=0.5)
    return out


def rig(body, g):
    arm = body.arm
    ctr = META["skirt_centre"]
    R.add_chains(arm, R.skirt_chains(META["skirt_rings"], ctr, n=16, rows=(4, 10, 16, 24)))
    # Capelet: chains on the front and back hems only (the sides ride the arms).
    cr, cc = META["cape_rings"], META["cape_centre"]
    segs = len(cr[0])
    cape = {}
    for k, ang in enumerate((60, 90, 120, 240, 270, 300)):
        i = int(round(ang / 360 * segs)) % segs
        pts = [cr[j][i] - (cr[j][i] - Vector((cc.x, cc.y, cr[j][i].z))).normalized() * 0.008 for j in (7, 14, len(cr) - 1)]
        cape[f"cape_{k}"] = ("UpperChest", pts)
    R.add_chains(arm, cape)
    torso = ["Hips", "Spine", "Chest", "UpperChest", "J_Sec_L_Bust1", "J_Sec_L_Bust2", "J_Sec_R_Bust1", "J_Sec_R_Bust2"]
    legs = ["Hips"] + [f"{s}{b}" for s in ("Left", "Right") for b in ("UpperLeg", "LowerLeg", "Foot", "Toes")]
    R.restrict(g["Tights"], legs + ["Spine"])
    R.restrict(g["Boots"], legs)
    R.restrict(g["Corset"], torso)
    for k in range(4):
        R.rigid(g[f"Buckle{k}"], "Spine" if k < 2 else "Chest")
    R.rigid(g["Clasp"], "UpperChest")
    R.weight_hanging(g["Skirt"], arm, ctr, META["skirt_top"], META["skirt_hem"], "skirt", 16)
    R.weight_hanging(g["Petticoat"], arm, ctr, META["skirt_top"], META["skirt_hem"], "skirt", 16)
    R.weight_capelet(g["Capelet"], arm, cc, (cr[4][0].z, cr[-1][int(segs * 0.75)].z))
    for k in ("Skirt", "Petticoat", "Capelet"):
        T.limit_and_normalise(g[k], 4)   # glTF: 4 influences per vertex
    for o in g.values():
        R.bind(o, arm)
    return arm


def main():
    body = T.Body(BODY)
    print("BODY height %.3f joints hips %s" % (body.height, tuple(round(c, 3) for c in body.joint("Hips"))))
    garments = build(body)
    for n, o in garments.items():
        print("GARMENT", n, len(o.data.vertices), "verts")
    arm = rig(body, garments)
    chars = os.path.join(ROOT, "game", "assets", "models", "characters")
    R.body_mask(body, [garments[k] for k in ("Tights", "Blouse", "Boots", "Corset")],
                os.path.join(chars, "freyja_outfit_bodymask.png"))
    for o in body.meshes:
        o.hide_set(False)
    helpers = [o for o in bpy.data.objects if o.name.startswith("_")]
    for o in helpers:
        o.hide_render = True
    C.export_glb(os.path.join(chars, "freyja_outfit.glb"), [arm] + list(garments.values()), animations=False)
    if body._remesh is not None:
        body._remesh.hide_render = True
    objs = body.meshes + list(garments.values())
    prev = os.path.join(ROOT, "art", "previews", "outfit_freyja.png")
    C.render_preview(prev, objs, views=((0, "front"), (35, "tq"), (90, "side"), (180, "back")),
                     height=body.height * 1.08, look_z=body.height * 0.52, size=(1800, 900))
    print("PREVIEW", prev)


if __name__ == "__main__":
    main()
