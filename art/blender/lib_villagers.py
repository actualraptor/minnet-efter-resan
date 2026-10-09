"""Villager outfits in the vision-frame style (Edda v2, Pippa v2).

Edda (from the interior frame): soft grey bun with loose curls, warm closed-eye
smile, rosy cheeks; cream blouse with puffed sleeves and a ribbon bow at the
collar; russet-brown dress with an embroidered bodice; patterned cream apron.
Pippa (original, same family of shapes): cream blouse with short puffed
sleeves, rust pinafore with a ruffled hem and white apron pocket, ribboned
auburn pigtails, her blue book of facts.
"""
import math
import random

from mathutils import Matrix, Vector

import lib_common as C
import lib_character as L

TORSO = ["hips", "spine", "chest", "thigh.L", "thigh.R"]


def puff_sleeves(rig, mat, cuff_mat, band_mat, length=1.0, name="Sleeves"):
    s = rig.s
    parts = []
    for side in (1, -1):
        sh, el, wr = rig.p("shoulder", side), rig.p("elbow", side), rig.p("wrist", side)
        if length >= 1.0:
            pts = [sh.lerp(el, 0.02), sh.lerp(el, 0.45), el, el.lerp(wr, 0.45), el.lerp(wr, 0.86)]
            radii = [0.05, 0.066, 0.052, 0.058, 0.038]
            end = el.lerp(wr, 0.88)
            d = (wr - el).normalized()
        else:
            pts = [sh.lerp(el, 0.02), sh.lerp(el, 0.4), sh.lerp(el, 0.7)]
            radii = [0.05, 0.07, 0.045]
            end = sh.lerp(el, 0.72)
            d = (el - sh).normalized()
        sl = C.tube("Sleeve", pts, [x * s for x in radii], mat, segs=14)
        C.displace_noise(sl, 0.004 * s, 7.0, 7 if side > 0 else 8)
        parts.append(sl)
        if band_mat:
            parts.append(C.tube("Band", [end - d * 0.012, end + d * 0.004], [0.036 * s, 0.036 * s], band_mat, segs=12))
        frill = C.lathe("Frill", [(0.03 * s, 0.0), (0.05 * s, -0.03 * s)], 24, cuff_mat)
        L.ruffle(frill, 0.0, 0.005 * s, 0.004 * s, 10)
        q = Vector((0, 0, -1)).rotation_difference(d)
        frill.data.transform(Matrix.Translation(end + d * 0.006) @ q.to_matrix().to_4x4())
        parts.append(frill)
    rig.add(C.join(parts, name), allowed=["upper_arm.L", "upper_arm.R", "shoulder.L", "shoulder.R", "forearm.L", "forearm.R", "hand.L", "hand.R"])


def bow(center, size, mat, s=1.0):
    parts = []
    for side in (1, -1):
        parts.append(C.tube("BowLoop", [center, center + Vector((0.6 * side, -0.15, 0.35)) * size, center + Vector((1.0 * side, -0.1, -0.05)) * size, center],
                            [size * 0.25, size * 0.4, size * 0.3, size * 0.2], mat, segs=5, flatten=0.3, flat_axis=(0, 1, 0), caps=False))
        parts.append(C.tube("BowTail", [center, center + Vector((0.3 * side, -0.1, -0.8)) * size, center + Vector((0.4 * side, -0.1, -1.5)) * size],
                            [size * 0.25, size * 0.25, size * 0.2], mat, segs=5, flatten=0.25, flat_axis=(0, 1, 0)))
    parts.append(C.ellipsoid("BowKnot", center, (size * 0.3, size * 0.25, size * 0.3), mat, segs=8, rings=5))
    return parts


def pattern_dots(rig, r, z0, z1, sy, mat, count, size, skip_back=True, seed=3):
    rnd = random.Random(seed)
    s = rig.s
    parts = []
    for i in range(count):
        a = rnd.random() * math.tau
        if skip_back and math.sin(a) > -0.5:
            continue  # apron only covers the front (-Y)
        z = z0 + rnd.random() * (z1 - z0)
        rr = r(z)
        p = Vector((math.cos(a) * (rr + 0.006) * s, math.sin(a) * (rr + 0.006) * s * sy, z * s))
        parts.append(C.ellipsoid("Motif", p, (size * s, size * 0.5 * s, size * s), mat, segs=6, rings=4))
    return parts


# ---------------------------------------------------------------------------
# Edda
# ---------------------------------------------------------------------------

def edda(rig):
    sp = rig.spec
    cl = sp["colors"]
    s = rig.s
    cream = C.mat("M_Cream_edda", "#f1e7d3", 0.85)
    russet = C.mat("M_Dress_edda", cl["dress"], 0.85)
    russet_dark = C.mat("M_DressTrim_edda", "#6e4430", 0.8)
    apron = C.mat("M_Apron_edda", cl["apron"], 0.85)
    motif_g = C.mat("M_ApronMotifGreen", "#7f9f78", 0.8)
    motif_r = C.mat("M_ApronMotifRose", "#c98a8a", 0.8)
    ribbon = C.mat("M_Ribbon_edda", "#6b3b2e", 0.7)
    gold = C.mat("M_Gold", "#d8b25a", 0.35, 0.8)
    # Blouse + dress.
    blouse = C.lathe("Blouse", L._scaled_profile(rig, [(0.05, 1.465), (0.085, 1.445), (0.135, 1.38), (0.145, 1.27)]), 32, cream, scale_xy=(1.0, 0.86))
    rig.add(blouse, allowed=TORSO + ["neck"])
    dress = C.lathe("Dress", L._scaled_profile(rig, [(0.142, 1.33), (0.15, 1.25), (0.138, 1.13), (0.162, 0.98), (0.21, 0.76), (0.245, 0.48), (0.258, 0.2), (0.26, 0.17)]),
                    40, russet, scale_xy=(1.0, 0.86))
    L.ruffle(dress, 0.26 * s, 0.01 * s, 0.006 * s, 12)
    rig.add(dress, allowed=TORSO + ["neck"])
    bodice = [L.trim_ring(rig, "BodiceTop", 0.146, 1.33, 0.86, russet_dark, thick=0.01),
              L.trim_ring(rig, "Waist", 0.14, 1.12, 0.86, russet_dark, thick=0.012)]
    for z in (1.29, 1.23, 1.17):
        bodice.append(C.ellipsoid("Lace", (0, -0.128 * s, z * s), (0.012 * s, 0.006 * s, 0.006 * s), gold, segs=6, rings=4))
    bodice += bow(Vector((0, -0.07 * s, 1.465 * s)), 0.018 * s, ribbon)
    rig.add(C.join(bodice, "Bodice"), allowed=["chest", "spine", "neck", "hips"])
    # Patterned apron over the front with a ruffled hem.
    ap = C.lathe("Apron", L._scaled_profile(rig, [(0.15, 1.11), (0.174, 0.98), (0.218, 0.76), (0.254, 0.48), (0.265, 0.32)]), 40, apron,
                 scale_xy=(1.0, 0.88), skip_angle=(90.0, 115.0, 2.0))
    L.ruffle(ap, 0.36 * s, 0.008 * s, 0.006 * s, 14)
    prof = lambda z: 0.15 + (1.11 - z) * 0.145 + 0.008
    motifs = pattern_dots(rig, prof, 0.4, 1.0, 0.88, motif_g, 70, 0.012, seed=5) + pattern_dots(rig, prof, 0.4, 1.0, 0.88, motif_r, 50, 0.01, seed=9)
    tie = bow(Vector((0, 0.15 * s, 1.1 * s)), 0.03 * s, apron)
    rig.add(C.join([ap] + motifs + tie, "Apron"), allowed=TORSO)
    puff_sleeves(rig, cream, cream, russet_dark)


def edda_hair(rig):
    c = rig.head_center()
    r = rig.head_radii()
    hs = rig.spec.get("head_scale", 1.0) * rig.s
    hair = C.mat("M_Hair_edda", rig.spec["colors"]["hair"], 0.6)
    parts = [L._hair_cap(rig, hair)]
    # Soft swept-back waves over the cap.
    rnd = random.Random(4)
    for i in range(14):
        a = math.radians(-160 + i * 23)
        root = c + Vector((math.cos(a) * r.x * 0.95, math.sin(a) * r.y * 0.6 - r.y * 0.3, r.z * 0.6))
        tip = c + Vector((math.cos(a) * r.x * 0.7, r.y * 0.85, r.z * 0.45))
        parts.append(L._strand(rig, "Wave", root, tip, (math.cos(a) * 0.02, 0, 0.02), 0.024 * hs, hair, flatten=0.5))
    # Bun of curls with a gold pin.
    bun_c = c + Vector((0, r.y * 0.8, r.z * 0.55))
    for k in range(7):
        a = k * math.tau / 7
        cc = bun_c + Vector((math.cos(a) * 0.03, 0.01 * math.sin(a * 2), math.sin(a) * 0.028)) * hs / max(rig.s, 1e-6)
        cu = C.ellipsoid("Curl", cc, (0.026 * hs, 0.024 * hs, 0.024 * hs), hair, segs=10, rings=6)
        C.displace_noise(cu, 0.003, 8.0, k)
        parts.append(cu)
    parts.append(C.ellipsoid("BunCore", bun_c, (0.045 * hs, 0.04 * hs, 0.042 * hs), hair, segs=12, rings=8))
    parts.append(C.cylinder("Pin", bun_c + Vector((-0.06 * hs, 0.01, 0.02)), bun_c + Vector((0.06 * hs, 0.02, 0.04)), 0.003,
                            material=C.mat("M_Pin", "#d8b25a", 0.3, 0.7), segs=6))
    # Loose curls at the temples.
    for side in (1, -1):
        p = c + Vector((r.x * 0.98 * side, -r.y * 0.1, -r.z * 0.05))
        parts.append(C.tube("TempleCurl", [p, p + Vector((0.01 * side, -0.01, -0.03)), p + Vector((0.0, -0.02, -0.05))],
                            [0.01 * hs, 0.008 * hs, 0.004 * hs], hair, segs=6))
    rig.add(C.join(parts, "HairEdda"), rigid="head")


# ---------------------------------------------------------------------------
# Pippa
# ---------------------------------------------------------------------------

def pippa(rig):
    sp = rig.spec
    cl = sp["colors"]
    s = rig.s
    cream = C.mat("M_Cream_pippa", "#f6f0e2", 0.85)
    pin = C.mat("M_Pinafore_pippa", cl["pinafore"], 0.85)
    pin_dark = C.mat("M_PinaforeTrim_pippa", "#8a3f2e", 0.8)
    white = C.mat("M_ApronWhite_pippa", "#fbf7ee", 0.85)
    ribbon = C.mat("M_Tie_pippa", cl.get("accent", "#d9604f"), 0.6)
    blouse = C.lathe("Blouse", L._scaled_profile(rig, [(0.05, 1.47), (0.085, 1.43), (0.125, 1.37), (0.13, 1.27)]), 32, cream, scale_xy=(1.0, 0.86))
    rig.add(blouse, allowed=TORSO + ["neck"])
    dress = C.lathe("Pinafore", L._scaled_profile(rig, [(0.085, 1.41), (0.125, 1.37), (0.132, 1.3), (0.128, 1.15), (0.145, 1.02), (0.2, 0.84), (0.25, 0.68), (0.256, 0.66)]),
                    48, pin, scale_xy=(1.0, 0.86))
    rig.add(dress, allowed=TORSO)
    under = C.lathe("Ruffle", L._scaled_profile(rig, [(0.2, 0.8), (0.26, 0.64), (0.27, 0.6)]), 56, white, scale_xy=(1.0, 0.86))
    L.ruffle(under, 0.66 * s, 0.014 * s, 0.012 * s, 16)
    rig.add(under, allowed=TORSO)
    trims = [L.trim_ring(rig, "HemTrim", 0.252, 0.675, 0.86, pin_dark, thick=0.01),
             L.trim_ring(rig, "WaistTrim", 0.13, 1.12, 0.86, pin_dark, thick=0.01)]
    ap = C.lathe("ApronFront", L._scaled_profile(rig, [(0.152, 1.04), (0.2, 0.86), (0.236, 0.74), (0.24, 0.72)]), 40, white,
                 scale_xy=(1.0, 0.9), skip_angle=(90.0, 130.0, 2.0))
    L.ruffle(ap, 0.76 * s, 0.006 * s, 0.006 * s, 12)
    pocket = C.box("Pocket", (0.045 * s, -0.188 * s, 0.86 * s), (0.035 * s, 0.006 * s, 0.03 * s), pin_dark, bevel=0.004)
    book = C.box("FactBook", (0.045 * s, -0.19 * s, 0.9 * s), (0.026 * s, 0.008 * s, 0.032 * s), C.mat("M_Book_Pippa", "#6c8fb5", 0.7), bevel=0.003)
    collar_bow = bow(Vector((0, -0.065 * s, 1.43 * s)), 0.016 * s, ribbon)
    rig.add(C.join(trims + [ap, pocket, book] + collar_bow, "PinaforeDetail"), allowed=TORSO + ["neck"])
    puff_sleeves(rig, cream, white, None, length=0.5)
    # Ribbons on the pigtails.
    c = rig.head_center()
    r = rig.head_radii()
    hs = sp.get("head_scale", 1.0) * s
    bows = []
    for side in (1, -1):
        tie = Vector((r.x * 0.92 * side, c.y + r.y * 0.35, c.z - r.z * 0.05))
        bows += bow(tie + Vector((0.012 * side, 0.01, 0.01)), 0.016 * hs, ribbon)
    rig.add(C.join(bows, "HairBows"), rigid="head")
