"""Linnaea v2: hair, outfit and staff rebuilt against the owner's vision frames.

Design notes (from art/reference, kept local):
  hair      silver-lavender, to mid-thigh, voluminous and wavy, fanned ends;
            crown braid to the back of the head ending in white star-flowers,
            leaves and a plum ribbon bow with long tails.
  top       cream blouse, big puffed sleeves to the wrist, ruffled cuffs with
            dark bands; short sage capelet with gold trim and a frilled collar.
  waist     brown leather corset belt with gold buckles; satchel at the back
            right hip with a gold leaf emblem; green crystal dangles on chains.
  skirt     knee-length layers: sage panels (gold trim, pointed hems) with plum
            panels between, over cream ruffled petticoat tiers.
  legs      dark tights; tall brown boots to below the knee, folded cuffs,
            gold buckles.
  staff     twisted wood rising into a loop that cradles a large green gem,
            leaves on top, crystal dangles from the loop.
"""
import math
import random

import bmesh
from mathutils import Matrix, Vector

import lib_common as C
import lib_character as L

GOLD_HEX = "#d8b25a"


def mats(sp):
    cl = sp["colors"]
    return {
        "cream": C.mat("M_Cream_" + sp["name"], cl["cream"], 0.85),
        "cream2": C.mat("M_Petticoat_" + sp["name"], "#f6efdf", 0.85),
        "sage": C.mat("M_Tunic_" + sp["name"], cl["tunic"], 0.8),
        "sage_dark": C.mat("M_TunicDark_" + sp["name"], "#7d9f72", 0.8),
        "plum": C.mat("M_Plum_" + sp["name"], cl["plum"], 0.7),
        "gold": C.mat("M_Gold", GOLD_HEX, 0.35, 0.8),
        "leather": C.mat("M_Leather", "#7a5236", 0.65),
        "leather_dark": C.mat("M_LeatherDark", "#5a3b27", 0.6),
        "boot": C.mat("M_Boots_" + sp["name"], cl["boots"], 0.65),
        "crystal": C.mat("M_Crystal_Glow", "#5fe0a8", 0.1, emit=1.5),
        "hair": C.mat("M_Hair_" + sp["name"], cl["hair"], 0.55),
        "hair_shadow": C.mat("M_HairShade_" + sp["name"], "#cfcfe2", 0.55),
        "flower": C.mat("M_HairFlower", "#fbf6ea", 0.6),
        "flower_c": C.mat("M_HairFlowerCentre", "#e8b84a", 0.5),
        "leaf": C.mat("M_HairLeaf", "#6d9a52", 0.7),
        "ribbon": C.mat("M_Plum_Ribbon", "#7b3f5a", 0.7),
        "wood": C.mat("M_Wood_Staff", "#9a6a3e", 0.7),
    }


# ---------------------------------------------------------------------------
# Hair
# ---------------------------------------------------------------------------

def _wavy_strand(root, tip, r0, mat, wave_amp, wave_freq, phase, flat_axis, flatten=0.4, push=(0, 0.05, 0), n=12, segs=7):
    pts, radii = [], []
    root, tip = Vector(root), Vector(tip)
    side = Vector((1, 0, 0))
    for i in range(n):
        t = i / (n - 1)
        p = root.lerp(tip, t) + Vector(push) * math.sin(t * math.pi)
        p += side * math.sin(t * wave_freq * math.pi + phase) * wave_amp * t
        pts.append(p)
        radii.append(r0 * (1 - 0.88 * t ** 1.4) + 0.0015)
    return C.tube("Strand", pts, radii, mat, segs=segs, flatten=flatten, flat_axis=flat_axis)


def hair(rig, M):
    sp = rig.spec
    c = rig.head_center()
    r = rig.head_radii()
    s = rig.s
    hs = sp.get("head_scale", 1.0) * s
    rnd = random.Random(11)
    head_parts = [L._hair_cap(rig, M["hair"])]
    # Bangs: soft, slightly parted, covering the brows.
    n_b = 9
    for i in range(n_b):
        t = (i / (n_b - 1)) * 2 - 1
        x = t * r.x * 0.82
        root, _ = L._on_head(rig, x * 0.55, c.z + r.z * 0.8, 0.012)
        length = (0.07 + 0.025 * (1 - abs(t)) + 0.012 * rnd.random())
        tip, _ = L._on_head(rig, x * 1.08 + 0.012 * t, c.z + r.z * 0.8 - length * hs, 0.018)
        head_parts.append(L._strand(rig, "Bang", root, tip, (0, -0.012, 0), 0.021 * hs, M["hair"], flatten=0.35))
    # Face-framing locks behind the ears, falling to the chest.
    for side in (1, -1):
        for k in range(2):
            root = Vector((r.x * (0.9 - 0.08 * k) * side, c.y + r.y * (0.05 + 0.25 * k), c.z + r.z * 0.25))
            tip = Vector(((0.12 + 0.04 * k) * s * side, (-0.04 + 0.05 * k) * s, (1.18 - 0.08 * k) * s))
            head_parts.append(_wavy_strand(root, tip, 0.03 * hs, M["hair"], 0.02 * s, 3.0, k + side,
                                           (side, 0.4, 0), push=(0.03 * side, 0.0, 0)))
    rig.add(C.join(head_parts, "HairHead"), allowed=["head", "neck", "chest"])

    # Back fall: three layers of wavy ribbons fanning out to mid-thigh.
    back = []
    for layer, (count, depth, z_tip, spread, thick) in enumerate(
            ((17, 0.85, 0.66, 0.30, 0.066), (13, 0.62, 0.62, 0.34, 0.06), (9, 0.4, 0.74, 0.24, 0.05))):
        for i in range(count):
            t = (i / (count - 1)) * 2 - 1
            root = Vector((t * r.x * 0.92, c.y + r.y * depth, c.z + r.z * (0.4 - 0.12 * layer) - abs(t) * 0.05 * hs))
            tip = Vector((t * spread * s + (rnd.random() - 0.5) * 0.04, (0.17 - 0.03 * layer) * s + abs(t) * 0.03,
                          (z_tip + abs(t) * 0.1 + rnd.random() * 0.06) * s))
            back.append(_wavy_strand(root, tip, (thick - abs(t) * 0.014) * hs, M["hair"] if (i + layer) % 4 else M["hair_shadow"],
                                     0.025 * s, 2.5 + rnd.random(), rnd.random() * 6.0, (0, 1, 0),
                                     push=(0.02 * t, 0.07, 0), n=14, segs=8))
    rig.add(C.join(back, "HairBack"), allowed=["head", "hair.1", "hair.2", "hair.3", "hair.4"])

    # Crown braid: from the left temple over the crown to the back of the head.
    braid = []
    n = 18
    for k in range(n):
        t = k / (n - 1)
        a = math.radians(150 - 135 * t)              # sweep from front-left to back
        el = 0.62 - 0.25 * math.sin(t * math.pi * 0.9)  # height on the head
        p = c + Vector((math.cos(a) * r.x * 0.98 * math.cos(el * 0.5), math.sin(a) * r.y * 1.0, r.z * el)) * 1.04
        if t > 0.6:
            p = p.lerp(c + Vector((r.x * 0.15, r.y * 1.02, r.z * 0.2)), (t - 0.6) / 0.4 * 0.6)
        wob = Vector((0, 0, 0.007 * hs * (1 if k % 2 else -1)))
        braid.append(C.ellipsoid("Braid", p + wob, (0.02 * hs, 0.02 * hs, 0.015 * hs), M["hair"], segs=8, rings=6))
    # Flower cluster + leaves + ribbon bow at the back of the head.
    fc = c + Vector((r.x * 0.2, r.y * 1.04, r.z * 0.18))
    for j, (dx, dz, sc) in enumerate(((0.0, 0.0, 1.0), (0.04, -0.035, 0.75), (-0.035, -0.03, 0.7))):
        fp = fc + Vector((dx * hs, 0.012, dz * hs))
        for k in range(5):
            a = k * math.tau / 5 + j
            braid.append(C.ellipsoid("HairPetal", fp + Vector((math.cos(a) * 0.022 * sc, 0.004, math.sin(a) * 0.022 * sc)) * hs,
                                     (0.016 * sc * hs, 0.006 * hs, 0.016 * sc * hs), M["flower"], segs=8, rings=4))
        braid.append(C.ellipsoid("HairFlowerC", fp + Vector((0, 0.01, 0)), (0.007 * hs, 0.006 * hs, 0.007 * hs), M["flower_c"], segs=8, rings=4))
    for k, a in enumerate((0.4, 1.3, 2.4, 3.3)):
        braid.append(C.ellipsoid("HairLeaf", fc + Vector((math.cos(a) * 0.05, 0.004, math.sin(a) * 0.045)) * hs,
                                 (0.012 * hs, 0.004 * hs, 0.03 * hs), M["leaf"], segs=6, rings=4))
    bow = fc + Vector((0, 0.02, -0.06 * hs))
    for side in (1, -1):
        braid.append(C.tube("BowLoop", [bow, bow + Vector((0.04 * side, 0.01, 0.025)) * hs, bow + Vector((0.065 * side, 0.012, -0.005)) * hs, bow],
                            [0.01 * hs, 0.016 * hs, 0.012 * hs, 0.008 * hs], M["ribbon"], segs=5, flatten=0.3, flat_axis=(0, 1, 0), caps=False))
    braid.append(C.ellipsoid("BowKnot", bow, (0.012 * hs, 0.01 * hs, 0.012 * hs), M["ribbon"], segs=8, rings=5))
    rig.add(C.join(braid, "HairBraid"), rigid="head")
    tails = []
    for side in (1, -1):
        pts = [bow + Vector((0.008 * side, 0.008, -0.01)),
               bow + Vector((0.03 * side, 0.03, -0.14)) * 1.0,
               bow + Vector((0.025 * side, 0.05, -0.3)),
               bow + Vector((0.04 * side, 0.06, -0.42))]
        tails.append(C.tube("RibbonTail", pts, [0.012, 0.014, 0.014, 0.012], M["ribbon"], segs=5, flatten=0.22, flat_axis=(0, 1, 0)))
    rig.add(C.join(tails, "RibbonTails"), allowed=["head", "hair.1", "hair.2"])


# ---------------------------------------------------------------------------
# Outfit
# ---------------------------------------------------------------------------

def _panel(name, a_center, half_w, profile, hem_point, mat, s, sy=0.85, segs=10, rows=None):
    """A curved skirt panel between angles, following a (radius, z) profile from
    top to hem; the hem drops by hem_point at the panel centre (handkerchief point)."""
    bm = bmesh.new()
    grid = []
    nr = len(profile)
    for j in range(nr):
        rr, zz = profile[j]
        row = []
        for i in range(segs + 1):
            u = i / segs * 2 - 1
            a = math.radians(a_center + u * half_w)
            drop = hem_point * (1 - abs(u)) ** 1.2 * (j / (nr - 1)) ** 2
            row.append(bm.verts.new((math.cos(a) * rr * s, math.sin(a) * rr * s * sy, (zz - drop) * s)))
        grid.append(row)
    for j in range(nr - 1):
        for i in range(segs):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Gold trim following both sides and the pointed hem (read before bm is freed).
    hem = grid[-1]
    trim_pts = [grid[j][0].co.copy() for j in range(nr)] + [v.co.copy() for v in hem[1:]] + \
               [grid[j][-1].co.copy() for j in range(nr - 2, -1, -1)]
    ob = C.mesh_obj(name, bm, mat, smooth=True)
    return ob, trim_pts


def outfit(rig, M):
    sp = rig.spec
    s = rig.s
    torso = ["hips", "spine", "chest", "thigh.L", "thigh.R"]
    # Blouse body under everything.
    blouse = C.lathe("Blouse", L._scaled_profile(rig, [(0.06, 1.49), (0.1, 1.45), (0.13, 1.38), (0.134, 1.28), (0.118, 1.16), (0.114, 1.06)]),
                     32, M["cream"], scale_xy=(1.0, 0.8))
    rig.add(blouse, allowed=torso + ["neck"])
    # Petticoat tiers (cream ruffles), knee length.
    for k, (r_top, r_hem, z_top, z_hem, freq) in enumerate(((0.12, 0.315, 1.02, 0.545, 18), (0.12, 0.3, 1.0, 0.585, 15))):
        pet = C.lathe(f"Petticoat{k}", L._scaled_profile(rig, [(0.112, 1.06), (r_top + 0.03, 0.95), ((r_top + r_hem) * 0.55, 0.82), (r_hem, z_hem + 0.02), (r_hem + 0.008, z_hem)]),
                      64, M["cream2"] if k == 0 else M["cream"], scale_xy=(1.0, 0.82))
        L.ruffle(pet, (z_hem + 0.06) * s, 0.02 * s, 0.016 * s, freq)
        rig.add(pet, allowed=torso)
    # Outer skirt: sage panels with pointed hems and gold trim; plum panels between.
    trims = []
    sage_prof = [(0.13, 1.06), (0.175, 0.95), (0.245, 0.82), (0.31, 0.71), (0.335, 0.67)]
    plum_prof = [(0.126, 1.06), (0.168, 0.95), (0.236, 0.82), (0.3, 0.7), (0.322, 0.64)]
    n_sage = 5
    for i in range(n_sage):
        ac = 90 + i * 360 / n_sage
        if abs(((ac - 270) + 180) % 360 - 180) < 30:
            continue  # leave the front open so the petticoats show
        ob, tp = _panel("SkirtSage", ac, 360 / n_sage / 2 - 6, sage_prof, 0.09, M["sage"], s)
        rig.add(ob, allowed=torso)
        trims.append(C.tube("SkirtTrim", tp, [0.006 * s] * len(tp), M["gold"], segs=4, caps=False))
        pc = ac + 360 / n_sage / 2
        ob2, _ = _panel("SkirtPlum", pc, 13, plum_prof, 0.1, M["plum"], s, segs=5)
        rig.add(ob2, allowed=torso)
    # Gold embroidery dots along the sage panels' lower band.
    for i in range(40):
        a = math.radians(i * 9)
        if abs(((math.degrees(a) - 270) + 180) % 360 - 180) < 30:
            continue
        p = Vector((math.cos(a) * 0.283 * s, math.sin(a) * 0.283 * s * 0.85, 0.765 * s))
        trims.append(C.ellipsoid("Embroidery", p, (0.009 * s, 0.006 * s, 0.014 * s), M["gold"], segs=6, rings=4))
    rig.add(C.join(trims, "SkirtTrims"), allowed=torso)
    # Corset belt with buckles and straps.
    corset = C.lathe("Corset", L._scaled_profile(rig, [(0.14, 1.26), (0.124, 1.17), (0.118, 1.09), (0.128, 1.02)]), 32, M["leather"], scale_xy=(1.0, 0.82))
    belt_parts = [corset]
    for z in (1.21, 1.13, 1.05):
        belt_parts.append(C.box("Buckle", (0, -0.1 * s, z * s), (0.018 * s, 0.008 * s, 0.014 * s), M["gold"], bevel=0.003))
    belt_parts.append(L.trim_ring(rig, "BeltLow", 0.13, 1.015, 0.82, M["leather_dark"], thick=0.012))
    rig.add(C.join(belt_parts, "Corset"), allowed=["hips", "spine", "chest"])
    # Crystal dangles on chains from the belt.
    dang = []
    for k, a_deg in enumerate((205, 235, 300, 330, 20, 160)):
        a = math.radians(a_deg)
        top = Vector((math.cos(a) * 0.14 * s, math.sin(a) * 0.12 * s, 1.0 * s))
        length = (0.2 + 0.08 * (k % 3)) * s
        low = top + Vector((math.cos(a) * 0.07 * s, math.sin(a) * 0.06 * s, -length))
        dang.append(C.tube("Chain", [top, top.lerp(low, 0.5) + Vector((math.cos(a) * 0.03, math.sin(a) * 0.03, 0)), low], [0.003] * 3, M["gold"], segs=4))
        cr = C.ellipsoid("Dangle", low + Vector((0, 0, -0.035 * s)), (0.013 * s, 0.013 * s, 0.04 * s), M["crystal"], segs=6, rings=4)
        dang.append(cr)
    rig.add(C.join(dang, "BeltDangles"), allowed=["hips", "thigh.L", "thigh.R"])
    # Capelet with frilled collar.
    cape = C.lathe("Capelet", L._scaled_profile(rig, [(0.06, 1.47), (0.09, 1.455), (0.16, 1.43), (0.21, 1.38), (0.226, 1.33)]), 36, M["sage"], scale_xy=(1.0, 0.86))
    cape_trim = L.trim_ring(rig, "CapeTrim", 0.227, 1.33, 0.86, M["gold"], thick=0.008)
    collar = C.lathe("Collar", L._scaled_profile(rig, [(0.052, 1.47), (0.06, 1.5), (0.07, 1.52)]), 32, M["cream"], scale_xy=(1.0, 0.9))
    L.ruffle(collar, 1.53 * s, 0.006 * s, 0.005 * s, 14)
    clasp = C.ellipsoid("Clasp", (0, -0.078 * s, 1.44 * s), (0.016 * s, 0.008 * s, 0.016 * s), M["gold"], segs=10, rings=6)
    gem = C.ellipsoid("ClaspGem", (0, -0.087 * s, 1.44 * s), (0.009 * s, 0.006 * s, 0.011 * s), M["crystal"], segs=8, rings=6)
    rig.add(C.join([cape, cape_trim, collar, clasp, gem], "CapeletSet"), allowed=["chest", "neck", "shoulder.L", "shoulder.R", "spine"])
    # Big puffed sleeves to the wrist with ruffled cuffs and dark bands.
    sleeves = []
    for side in (1, -1):
        sh, el, wr = rig.p("shoulder", side), rig.p("elbow", side), rig.p("wrist", side)
        pts = [sh.lerp(el, 0.02), sh.lerp(el, 0.4), sh.lerp(el, 0.85), el, el.lerp(wr, 0.35), el.lerp(wr, 0.7), el.lerp(wr, 0.88)]
        radii = [0.05, 0.068, 0.058, 0.055, 0.064, 0.06, 0.04]
        sl = C.tube("Sleeve", pts, [x * s for x in radii], M["cream"], segs=14)
        C.displace_noise(sl, 0.004 * s, 7.0, 3 if side > 0 else 4)
        sleeves.append(sl)
        band = C.tube("CuffBand", [el.lerp(wr, 0.87), el.lerp(wr, 0.93)], [0.034 * s, 0.034 * s], M["leather_dark"], segs=12)
        frill = C.lathe("CuffFrill", [(0.03 * s, 0.0), (0.05 * s, -0.035 * s)], 24, M["cream2"])
        L.ruffle(frill, 0.0, 0.006 * s, 0.004 * s, 10)
        # orient the frill along the forearm direction at the wrist
        d = (wr - el).normalized()
        q = Vector((0, 0, -1)).rotation_difference(d)
        frill.data.transform(Matrix.Translation(el.lerp(wr, 0.92)) @ q.to_matrix().to_4x4())
        sleeves += [band, frill]
    rig.add(C.join(sleeves, "Sleeves"), allowed=["upper_arm.L", "upper_arm.R", "shoulder.L", "shoulder.R", "forearm.L", "forearm.R", "hand.L", "hand.R"])
    # Satchel at the back right hip, strap over the left shoulder.
    sat_c = Vector((-0.11 * s, 0.14 * s, 0.98 * s))
    sat = C.box("Satchel", sat_c, (0.075 * s, 0.035 * s, 0.06 * s), M["leather"], bevel=0.012 * s)
    flap = C.box("Flap", sat_c + Vector((0, 0.037 * s, 0.02 * s)), (0.077 * s, 0.006 * s, 0.045 * s), M["leather_dark"], bevel=0.004)
    emb = [C.ellipsoid("Emblem", sat_c + Vector((math.sin(a) * 0.015 * s, 0.045 * s, 0.012 * s + math.cos(a) * 0.018 * s)), (0.006 * s, 0.003 * s, 0.016 * s), M["gold"], segs=6, rings=4)
           for a in (-0.7, 0.0, 0.7)]
    strap_pts = [Vector((0.1, -0.09, 1.41)), Vector((0.0, -0.13, 1.28)), Vector((-0.1, -0.12, 1.14)), Vector((-0.16, -0.02, 1.02)), Vector((-0.12, 0.12, 1.0))]
    strap = C.tube("Strap", [p * s for p in strap_pts], [0.008 * s] * 5, M["leather"], segs=4, flatten=0.35, flat_axis=(0, -1, 0))
    back_pts = [Vector((0.1, 0.08, 1.41)), Vector((0.03, 0.13, 1.26)), Vector((-0.06, 0.15, 1.1)), Vector((-0.1, 0.15, 1.02))]
    strap2 = C.tube("Strap2", [p * s for p in back_pts], [0.008 * s] * 4, M["leather"], segs=4, flatten=0.35, flat_axis=(0, 1, 0))
    rig.add(C.join([sat, flap, strap, strap2] + emb, "Satchel"), allowed=["hips", "spine", "chest"])
    # Boots: folded cuffs and gold buckles just below the knee.
    bc = []
    for side in (1, -1):
        k = rig.p("knee", side)
        a = rig.p("ankle", side)
        p = k.lerp(a, 0.12)
        bc.append(C.tube("BootCuff", [p + Vector((0, 0, -0.045)), p + Vector((0, 0, 0.02))], [0.056 * s, 0.066 * s], M["boot"], segs=14))
        for z in (0.3, 0.55):
            q = k.lerp(a, z)
            bc.append(C.tube("BootStrap", [q, q + Vector((0, 0, 0.018))], [0.05 * s, 0.05 * s], M["leather_dark"], segs=14))
            bc.append(C.box("BootBuckle", q + Vector((0.045 * side * s, -0.015, 0.009)), (0.006, 0.012, 0.012), M["gold"]))
    rig.add(C.join(bc, "BootCuffs"), allowed=["shin.L", "shin.R"])


# ---------------------------------------------------------------------------
# Staff
# ---------------------------------------------------------------------------

def staff(rig, M):
    s = rig.s
    grip = rig.p("wrist", -1).lerp(rig.p("hand_tip", -1), 0.45)
    bottom = grip + Vector((0, 0, -0.86 * s))
    top = grip + Vector((0, 0, 0.82 * s))
    parts = []
    # Two intertwined wooden strands spiralling up the shaft.
    for k in range(2):
        pts, radii = [], []
        for i in range(25):
            t = i / 24
            ang = t * math.tau * 3.0 + k * math.pi
            rr = 0.008 * s * (1 if t < 0.92 else 1.6)
            pts.append(bottom.lerp(top, t) + Vector((math.cos(ang) * rr, math.sin(ang) * rr, 0)))
            radii.append((0.014 - 0.003 * t) * s)
        parts.append(C.tube("ShaftStrand", pts, radii, M["wood"], segs=7))
    for z in (0.18, 0.62, 0.95):
        parts.append(C.tube("GoldWrap", [bottom.lerp(top, z), bottom.lerp(top, z + 0.012)], [0.022 * s, 0.022 * s], M["gold"], segs=10))
    # The loop: two branches curling up and round to cradle the gem.
    ring_c = top + Vector((0, 0, 0.13 * s))
    ring_r = 0.085 * s
    for k, sgn in enumerate((1, -1)):
        pts = [top]
        for i in range(1, 15):
            a = math.radians(-90 + sgn * i * 13.5)
            pts.append(ring_c + Vector((math.cos(a) * ring_r * sgn * 0 + math.sin(math.radians(i * 13.5)) * ring_r * sgn, 0.006 * k, -math.cos(math.radians(i * 13.5)) * ring_r)))
        parts.append(C.tube("Loop", pts, [0.013 * s * (1 - 0.4 * i / 14) for i in range(len(pts))], M["wood"], segs=7))
    gem = C.ellipsoid("Gem", ring_c, (0.048 * s, 0.035 * s, 0.06 * s), M["crystal"], segs=8, rings=5)
    for v in gem.data.vertices:
        dz = (v.co.z - ring_c.z) / (0.06 * s)
        k = 1.0 - abs(dz) ** 1.5 * 0.5
        v.co.x = ring_c.x + (v.co.x - ring_c.x) * k
        v.co.y = ring_c.y + (v.co.y - ring_c.y) * k
    parts.append(gem)
    parts.append(C.tube("GemSetting", [ring_c + Vector((0, 0, -0.065 * s)), ring_c + Vector((0, 0, -0.05 * s))], [0.02 * s, 0.026 * s], M["gold"], segs=10))
    # Leaves sprouting from the top of the loop.
    for k, a in enumerate((-0.6, 0.0, 0.7)):
        lp = ring_c + Vector((math.sin(a) * 0.04 * s, 0, ring_r + 0.03 * s))
        lf = C.ellipsoid("StaffLeaf", lp + Vector((math.sin(a) * 0.02, 0, 0.02)), (0.014 * s, 0.006 * s, 0.04 * s), M["leaf"], segs=6, rings=4)
        lf.data.transform(Matrix.Translation(lp) @ Matrix.Rotation(a * 0.8, 4, "Y") @ Matrix.Translation(-lp))
        parts.append(lf)
    parts.append(C.ellipsoid("StaffFlower", ring_c + Vector((-0.05 * s, -0.02, ring_r * 0.7)), (0.014 * s, 0.006 * s, 0.014 * s), M["flower"], segs=8, rings=4))
    # Crystal dangles hanging from the loop.
    for i, a in enumerate((-1.6, -0.9, 0.9, 1.6)):
        hang = ring_c + Vector((math.sin(a) * ring_r, 0, -math.cos(a) * ring_r * 0.3))
        low = hang + Vector((0, 0, -(0.08 + 0.03 * (i % 2)) * s))
        parts.append(C.tube("DangleChain", [hang, low], [0.0025, 0.0025], M["gold"], segs=4))
        parts.append(C.ellipsoid("Dangle", low + Vector((0, 0, -0.028 * s)), (0.011 * s, 0.011 * s, 0.03 * s), M["crystal"], segs=6, rings=4))
    rib = ring_c + Vector((0, 0, -0.1 * s))
    parts.append(C.tube("StaffRibbon", [rib, rib + Vector((0.02, 0.03, -0.1)) * s, rib + Vector((0.01, 0.05, -0.24)) * s],
                        [0.012 * s, 0.01 * s, 0.006 * s], M["ribbon"], segs=5, flatten=0.3, flat_axis=(1, 0, 0)))
    rig.staff_tip = ring_c
    rig.add(C.join(parts, "Staff"), rigid="hand.R")


def build(rig):
    M = mats(rig.spec)
    hair(rig, M)
    outfit(rig, M)
    staff(rig, M)
