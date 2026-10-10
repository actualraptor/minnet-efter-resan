"""Freyja's hands: finger and thumb bones, geometric skin weights, and the
staff placed in her right-hand grip.

The base mesh has clean, spread A-pose hands. For each hand we work in a local
frame (d = wrist->fingertips, n = palm normal, side = d x n), find the four
fingers by the gaps between them past the webbing, find the thumb on the
index side, and build 3-bone chains whose local X axis is the curl axis
(positive rotation about X curls toward the palm). Godot's HandPoser then
curls them procedurally (relaxed / grip / open), so every clip gets hands.
"""
import math

import bpy
import numpy as np
from mathutils import Matrix, Vector

FINGERS = ("index", "middle", "ring", "pinky")
PHALANX = (0.45, 0.30, 0.25)     # proximal / middle / distal share of MCP->tip
THUMB = (0.38, 0.34, 0.28)       # metacarpal / proximal / distal


def _pts(objs):
    return np.concatenate([np.array([o.matrix_world @ v.co for v in o.data.vertices]) for o in objs])


def analyze(body_objs, J, sgn):
    wrist = np.array([J["wrist"][0] * sgn, J["wrist"][1], J["wrist"][2]])
    tipj = np.array([J["hand_tip"][0] * sgn, J["hand_tip"][1], J["hand_tip"][2]])
    d = tipj - wrist
    hl = float(np.linalg.norm(d))
    d /= hl
    P = _pts(body_objs)
    rel = P - wrist
    a = rel @ d
    perp = np.linalg.norm(rel - np.outer(a, d), axis=1)
    H = P[(a > -0.03) & (a < hl + 0.04) & (perp < 0.07)]
    w, V = np.linalg.eigh(np.cov((H - H.mean(0)).T))
    n = V[:, 0]
    if n[2] > 0:
        n = -n                       # palm side (palms face down-in in the A-pose)
    n = n - d * (n @ d)
    n /= np.linalg.norm(n)
    side = np.cross(d, n)
    thumb_side = side if side[1] < 0 else -side   # the thumb is on the front (-y) side
    rH = H - wrist
    A, S, N = rH @ d, rH @ thumb_side, rH @ n     # S grows toward the thumb
    # Fingers: past the webbing they separate cleanly along S.
    fm = A > hl * 0.64
    # 1-D k-means into four fingers (robust to small gaps inside a finger).
    Sf = S[fm]
    cent = np.percentile(Sf, [12.5, 37.5, 62.5, 87.5])
    for _ in range(30):
        lab = np.argmin(np.abs(Sf[:, None] - cent[None, :]), axis=1)
        cent = np.array([Sf[lab == k].mean() if (lab == k).any() else cent[k] for k in range(4)])
    full_lab = np.full(len(S), -1)
    full_lab[np.where(fm)[0]] = lab
    fingers = []
    order = [(float(cent[k]), full_lab == k) for k in range(4)]
    order.sort(key=lambda t: -t[0])               # largest S (nearest thumb) first = index
    for name, (_, m) in zip(FINGERS, order):
        Pf = np.stack([A[m], S[m], N[m]], 1)
        tipA = float(np.percentile(Pf[:, 0], 99.5))
        # Centreline from slices; direction from a line fit of slice centres.
        cs = []
        for aa in np.linspace(Pf[:, 0].min() + 0.004, tipA - 0.006, 6):
            sl = Pf[np.abs(Pf[:, 0] - aa) < 0.003]
            if len(sl) > 5:
                cs.append(sl.mean(0))
        cs = np.array(cs)
        c0 = cs.mean(0)
        u, s_, vt = np.linalg.svd(cs - c0)
        dirf = vt[0] if vt[0][0] > 0 else -vt[0]
        mcpA = tipA * 0.44
        mcp = c0 + dirf * ((mcpA - c0[0]) / dirf[0])
        tip = c0 + dirf * ((tipA - c0[0]) / dirf[0])
        thick = float(np.percentile(Pf[:, 2], 95) - np.percentile(Pf[:, 2], 5))
        fingers.append({"name": name, "mcp": mcp, "tip": tip, "thick": thick})
    # Thumb: everything clearly beyond the index finger's edge on the thumb side.
    idx_s = fingers[0]["mcp"][1]
    tm = (S > idx_s + 0.024) & (A < hl * 0.7)
    Pt = np.stack([A[tm], S[tm], N[tm]], 1)
    far = Pt[Pt[:, 1] > np.percentile(Pt[:, 1], 40)]
    c0 = far.mean(0)
    u, s_, vt = np.linalg.svd(far - c0)
    tdir = vt[0] if vt[0][1] > 0 else -vt[0]
    proj = (far - c0) @ tdir
    t_tip = c0 + tdir * float(np.percentile(proj, 99.5))
    t_root = np.array([hl * 0.1, idx_s + 0.004, float(np.median(N))])
    to_local = lambda p: wrist + d * p[0] + thumb_side * p[1] + n * p[2]
    out = {"sgn": sgn, "wrist": wrist, "d": d, "n": n, "thumb_side": thumb_side, "hl": hl, "fingers": [], "thumb": None}
    for f in fingers:
        out["fingers"].append({"name": f["name"], "mcp": to_local(f["mcp"]), "tip": to_local(f["tip"]), "thick": f["thick"]})
    out["thumb"] = {"root": to_local(t_root), "tip": to_local(t_tip)}
    mean_mcp = np.mean([f["mcp"] for f in out["fingers"]], axis=0)
    mid_thick = float(np.mean([f["thick"] for f in fingers]))
    # Centre of the hole the fingers leave when curled to HandPoser.GRIP
    # (42/70/62 deg): solved in the finger's (d, n) plane, ~2.8 cm radius from the
    # finger centrelines, which fits the shaft (~2.2 cm) plus finger half-thickness.
    out["grip_centre"] = mean_mcp - d * 0.012 + n * 0.028
    g = thumb_side * math.cos(math.radians(20)) + d * math.sin(math.radians(20))
    out["grip_axis"] = g / np.linalg.norm(g)
    print("HAND", "LR"[sgn < 0], "hl %.3f" % hl, {f["name"]: tuple(np.round(f["tip"] - f["mcp"], 3)) for f in out["fingers"]})
    return out


def _chains(Hd):
    """[(bone_name, head, tail, z_axis)] for one hand."""
    sfx = "L" if Hd["sgn"] > 0 else "R"
    n = Hd["n"]
    res = []
    for f in Hd["fingers"]:
        mcp, tip = f["mcp"], f["tip"]
        L = tip - mcp
        t0 = 0.0
        for k, share in enumerate(PHALANX):
            h, t = mcp + L * t0, mcp + L * (t0 + share)
            res.append((f"f_{f['name']}_{k + 1}.{sfx}", h, t, n))
            t0 += share
    th = Hd["thumb"]
    L = th["tip"] - th["root"]
    tdir = L / np.linalg.norm(L)
    z = n * 0.75 - Hd["thumb_side"] * 0.65         # flex toward the palm and the fingers
    z = z - tdir * (z @ tdir)
    t0 = 0.0
    for k, share in enumerate(THUMB):
        res.append((f"thumb_{k + 1}.{sfx}", th["root"] + L * t0, th["root"] + L * (t0 + share), z / np.linalg.norm(z)))
        t0 += share
    return res


def add_bones(arm, hands):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for Hd in hands:
        sfx = "L" if Hd["sgn"] > 0 else "R"
        prev = None
        for name, h, t, z in _chains(Hd):
            b = eb.new(name)
            b.head, b.tail = Vector(h), Vector(t)
            b.align_roll(Vector(z))
            seg = int(name.split("_")[-1].split(".")[0])
            b.parent = eb[f"hand.{sfx}"] if seg == 1 else prev
            b.use_connect = False
            prev = b
    bpy.ops.object.mode_set(mode="OBJECT")


def _seg_param(p, h, t):
    v = t - h
    L2 = float(v @ v)
    s = float(np.clip(((p - h) @ v) / L2, -1.0, 2.0))
    q = h + v * np.clip(s, 0.0, 1.0)
    return s, float(np.linalg.norm(p - q))


def _smooth(e0, e1, x):
    t = min(1.0, max(0.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def weight(body_objs, arm, hands):
    """Split each body vertex's hand.X weight between the hand and its finger chains."""
    for Hd in hands:
        sfx = "L" if Hd["sgn"] > 0 else "R"
        hand_g = f"hand.{sfx}"
        chains = {}
        for name, h, t, z in _chains(Hd):
            key = name.rsplit("_", 1)[0]
            chains.setdefault(key, []).append((name, np.array(h), np.array(t)))
        for o in body_objs:
            if hand_g not in o.vertex_groups:
                continue
            gi = o.vertex_groups[hand_g].index
            for name in [nm for segs in chains.values() for nm, _, _ in segs]:
                if name not in o.vertex_groups:
                    o.vertex_groups.new(name=name)
            mw = o.matrix_world
            for v in o.data.vertices:
                wh = next((g.weight for g in v.groups if g.group == gi), 0.0)
                if wh <= 1e-4:
                    continue
                p = np.array(mw @ v.co)
                # Nearest chain by distance to its whole polyline (from a bit inside the palm).
                best = None
                for key, segs in chains.items():
                    h0, t1 = segs[0][1], segs[-1][2]
                    back = h0 - (t1 - h0) / np.linalg.norm(t1 - h0) * (0.012 if key.startswith("f_") else 0.0)
                    s, dist = _seg_param(p, back, t1)
                    if best is None or dist < best[1]:
                        best = (key, dist)
                key, dist = best
                segs = chains[key]
                if dist > (0.016 if key.startswith("thumb") else 0.014):
                    continue  # palm / back of hand stays on the hand bone
                # Arc-length position along the chain, measured from its first joint.
                h0 = segs[0][1]
                lens = [float(np.linalg.norm(t - h)) for _, h, t in segs]
                axis = (segs[-1][2] - h0) / np.linalg.norm(segs[-1][2] - h0)
                u = float((p - h0) @ axis)
                is_thumb = key.startswith("thumb")
                blend0 = (0.0, 0.016) if is_thumb else (-0.009, 0.004)
                w_chain = _smooth(blend0[0], blend0[1], u)
                ws = {hand_g: 1.0 - w_chain}
                j1, j2 = lens[0], lens[0] + lens[1]
                r = 0.005
                w2 = _smooth(j1 - r, j1 + r, u)
                w3 = _smooth(j2 - r, j2 + r, u)
                ws[segs[0][0]] = w_chain * (1 - w2)
                ws[segs[1][0]] = w_chain * w2 * (1 - w3)
                ws[segs[2][0]] = w_chain * w3
                o.vertex_groups[hand_g].add([v.index], wh * ws[hand_g], "REPLACE")
                for nm, _, _ in segs:
                    if ws[nm] > 1e-4:
                        o.vertex_groups[nm].add([v.index], wh * ws[nm], "REPLACE")


def grip_align(Hd):
    """World rotation that turns the rest-pose hand so the gripped staff points
    straight up with the palm facing her body."""
    g = Vector(Hd["grip_axis"])
    inward = Vector((-math.copysign(1.0, Hd["wrist"][0]), 0.0, 0.0))
    n = Vector(Hd["n"])
    n = (n - g * n.dot(g)).normalized()
    F = Matrix((g, n, g.cross(n))).transposed()
    T = Matrix((Vector((0, 0, 1)), inward, Vector((0, 0, 1)).cross(inward))).transposed()
    return T @ F.transposed()


def place_staff(staff_obj, tip_point, old_grip, Hd):
    """Move the (vertical) staff into the rest-pose grip: shaft across the palm."""
    Q = grip_align(Hd)
    M = Matrix.Translation(Vector(Hd["grip_centre"])) @ Q.inverted().to_4x4() @ Matrix.Translation(-Vector(old_grip))
    staff_obj.data.transform(staff_obj.matrix_world.inverted() @ M @ staff_obj.matrix_world)
    staff_obj.data.update()
    return M @ Vector(tip_point)
