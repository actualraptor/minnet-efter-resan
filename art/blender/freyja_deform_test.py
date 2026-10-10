"""Repeatable deformation test for Freyja (clipping gate).

Loads the exported game model, plays every clip at several phases, and for each
layer pair (inner garment/skin under an outer garment) counts inner vertices
that are covered at rest but poke through the outer layer in the pose. Robust
to flipped normals: a vertex counts only if its side of the outer surface
changes between the rest pose and the test pose.

    blender -b --factory-startup --python art/blender/freyja_deform_test.py -- <repo_root> [out_dir]

Writes <out_dir>/deform_report.json and prints a table; exit code 1 if any pose
exceeds the budget. Spring-bone motion is runtime-only and not covered here.
"""
import json
import os
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
OUT = sys.argv[sys.argv.index("--") + 2] if len(sys.argv) > sys.argv.index("--") + 2 else os.path.join(ROOT, "art", "previews")
MODEL = os.environ.get("DEFORM_MODEL", "freyja.glb")
GLB = os.path.join(ROOT, "game", "assets", "models", "characters", MODEL)

# (label, inner prefix, outer prefix, z-range of inner verts or None,
#  bones the tested inner verts must mainly follow or None)
PAIRS = [
    ("skin through coat", "Body01_", "Outfit_M_Freyja_001_0", None, None),
    ("skin through tights", "Body01_", "Leggings_", (0.0, 0.95), None),
    ("tights through skirt", "Leggings_", "Outfit_M_Freyja_001_Skirt", (0.62, 1.0), None),
    ("coat through corset", "Outfit_M_Freyja_001_0", "Corset", (0.99, 1.13), None),
    ("coat through capelet", "Outfit_M_Freyja_001_0", "Outfit_M_Freyja_002", (1.15, 1.45),
     ("upper_arm.", "shoulder.", "chest", "spine", "neck")),
    ("petticoat through skirt", "Petticoat", "Outfit_M_Freyja_001_Skirt", (0.585, 1.0), None),
    ("tights through boots", "Leggings_", "Boots_", (0.0, 0.4), None),
]
# VRoid game model + reference outfit (fitted layers; the spring-driven skirt
# and its leg follow only exist at runtime, so skirt pairs are checked in game).
PAIRS_VROID = [
    ("skin through tights", "Body", "Tights", (0.12, 0.8), None),
    ("skin through blouse", "Body", "Blouse", (0.9, 1.25), ("Spine", "Chest", "UpperChest", "Hips")),
    ("skin through sleeves", "Body", ("LeftGatheredSleeve", "RightGatheredSleeve"), None,
     ("LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm")),
    ("tights through boots", "Tights", "Boots", (0.05, 0.35), None),
    ("blouse through corset", "Blouse", "Corset", None, None),
    ("sleeves through capelet", ("LeftGatheredSleeve", "RightGatheredSleeve"), "Capelet", None,
     ("LeftShoulder", "RightShoulder", "LeftUpperArm", "RightUpperArm", "UpperChest")),
]
if "vroid" in MODEL:
    PAIRS = PAIRS_VROID
SAME_PATCH = 0.05
RIM = 0.015        # ignore inner verts whose nearest outer point is this close to the outer layer's open edge  # the crossing must be through the fabric patch that covered it at rest
COVER = 0.035      # a vertex is "covered" if the outer layer is this close at rest
POKE = 0.002       # and counts as clipping once it is this far on the other side
BUDGET = 0.004     # max fraction of covered vertices allowed through, per pair and pose
SEAM_VERTS = 12    # ...or at most this many vertices (a few at a garment edge are invisible)
PHASES = (0.0, 0.2, 0.4, 0.6, 0.8)


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=GLB)
    arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
    if arm.animation_data:
        for tr in arm.animation_data.nla_tracks:
            tr.mute = True
    else:
        arm.animation_data_create()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.parent == arm]
    return arm, meshes


def posed_verts(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    out = {}
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        v = np.array([o.matrix_world @ vv.co for vv in me.vertices])
        tris = [tuple(p.vertices) for p in me.polygons]
        out[o.name] = (v, tris)
        ev.to_mesh_clear()
    return out


def signed(bvh, pts, faces=False):
    """Signed distance to the outer surface along its (possibly flipped) normal,
    plus the nearest outer face index (faces=True) or nearest point."""
    s = np.full(len(pts), np.nan)
    f = np.full(len(pts), -1, dtype=int)
    near = np.full((len(pts), 3), np.nan)
    for i, p in enumerate(pts):
        loc, nrm, idx, dist = bvh.find_nearest(Vector(p), COVER * 2)
        if loc is not None:
            s[i] = (Vector(p) - loc).dot(nrm)
            f[i] = idx
            near[i] = loc[:]
    return (s, f) if faces else (s, near)


def main_bone(o, i, names):
    best, bw = "?", 0.0
    for g in o.data.vertices[i].groups:
        if g.weight > bw:
            best, bw = names[g.group], g.weight
    return best


def run():
    arm, meshes = load()
    by = lambda pre: [o for o in meshes if o.name.startswith(pre)]
    # Rest pose reference.
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    rest = posed_verts(meshes)
    plan = []
    for label, ipre, opre, zr, bones in PAIRS:
        inner, outer = by(ipre), by(opre)
        if not inner or not outer:
            print("SKIP", label)
            continue
        ov = np.concatenate([rest[o.name][0] for o in outer])
        ot, off = [], 0
        for o in outer:
            ot += [tuple(i + off for i in t) for t in rest[o.name][1]]
            off += len(rest[o.name][0])
        bvh = BVHTree.FromPolygons([Vector(p) for p in ov], ot)
        # Open edges of the outer layer: near a rim "inside/outside" is undefined.
        from collections import Counter
        from mathutils.kdtree import KDTree
        ec = Counter()
        for t in ot:
            for k in range(len(t)):
                ec[tuple(sorted((t[k], t[(k + 1) % len(t)])))] += 1
        rim = {i for e, c in ec.items() if c == 1 for i in e}
        kd = KDTree(max(len(rim), 1))
        for i in rim:
            kd.insert(Vector(ov[i]), i)
        kd.balance()
        for o in inner:
            v = rest[o.name][0]
            sel = np.arange(len(v))
            if zr:
                sel = sel[(v[sel, 2] >= zr[0]) & (v[sel, 2] <= zr[1])]
            if bones:
                names = {g.index: g.name for g in o.vertex_groups}
                sel = np.array([i for i in sel if main_bone(o, int(i), names).startswith(bones)], dtype=int)
            s0, f0 = signed(bvh, v[sel], faces=True)
            ok = ~np.isnan(s0) & (np.abs(s0) < COVER)
            if rim:
                _, near0 = signed(bvh, v[sel])
                for k in np.where(ok)[0]:
                    if kd.find(Vector(near0[k]))[2] < RIM:
                        ok[k] = False
            plan.append((label, o, outer, sel[ok], np.sign(s0[ok]), f0[ok]))
    report = {"poses": [], "pairs": [p[0] for p in PAIRS]}
    fail = False
    crossers = {}   # label -> {"mesh:vertex": [max penetration, rest x, y, z]}
    for act in sorted(bpy.data.actions, key=lambda a: a.name):
        arm.animation_data.action = act
        f0, f1 = act.frame_range
        for ph in PHASES:
            f = f0 + (f1 - f0) * ph
            bpy.context.scene.frame_set(int(f), subframe=f - int(f))
            pv = posed_verts(meshes)
            row = {"clip": act.name, "phase": ph, "pairs": {}}
            for label, o, outer, idx, side, rest_face in plan:
                ov = np.concatenate([pv[x.name][0] for x in outer])
                ot, off = [], 0
                for x in outer:
                    ot += [tuple(i + off for i in t) for t in pv[x.name][1]]
                    off += len(pv[x.name][0])
                bvh = BVHTree.FromPolygons([Vector(p) for p in ov], ot)
                s, near = signed(bvh, pv[o.name][0][idx])
                # Only crossings through the patch that covered the vertex at rest.
                cen = np.array([ov[list(ot[fi])].mean(axis=0) for fi in rest_face]) if len(rest_face) else np.zeros((0, 3))
                same = np.linalg.norm(near - cen, axis=1) < SAME_PATCH
                bad = ~np.isnan(s) & same & (np.sign(s) != side) & (np.abs(s) > POKE)
                frac = float(bad.sum()) / max(len(idx), 1)
                names = {g.index: g.name for g in o.vertex_groups}
                regions = {}
                cr = crossers.setdefault(label, {})
                for k in np.where(bad)[0]:
                    key = "%s:%d" % (o.name, int(idx[k]))
                    d = float(abs(s[k]))
                    if key not in cr or cr[key][0] < d:
                        rv = rest[o.name][0][int(idx[k])]
                        cr[key] = [d, float(rv[0]), float(rv[1]), float(rv[2])]
                for i in idx[bad]:
                    b = main_bone(o, int(i), names)
                    regions[b] = regions.get(b, 0) + 1
                cur = row["pairs"].setdefault(label, {"bad": 0, "covered": 0, "regions": {}})
                cur["bad"] += int(bad.sum())
                cur["covered"] += int(len(idx))
                for k, c in regions.items():
                    cur["regions"][k] = cur["regions"].get(k, 0) + c
            for label, cur in row["pairs"].items():
                cur["frac"] = cur["bad"] / max(cur["covered"], 1)
                if cur["frac"] > BUDGET and cur["bad"] > SEAM_VERTS:
                    fail = True
            report["poses"].append(row)
            worst = sorted(((c["frac"], l, c) for l, c in row["pairs"].items()), key=lambda t: t[0], reverse=True)[:2]
            print("POSE %-12s %.1f  " % (act.name, ph) + "  ".join(
                "%s %.2f%% %s" % (l, fr * 100, sorted(c["regions"].items(), key=lambda kv: -kv[1])[:3]) for fr, l, c in worst if fr > 0))
    # Totals per pair.
    print("SUMMARY (worst pose per pair)")
    for label in report["pairs"]:
        rows = [(r["pairs"][label]["bad"], r["pairs"][label]["frac"], r["clip"], r["phase"]) for r in report["poses"] if label in r["pairs"]]
        if rows:
            bad, fr, clip, ph = max(rows)
            ok = fr <= BUDGET or bad <= SEAM_VERTS
            print("  %-24s worst %d verts / %.2f%% (%s @ %.1f)  %s" % (label, bad, fr * 100, clip, ph, "ok" if ok else "FAIL"))
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "deform_report.json"), "w") as fh:
        json.dump(report, fh, indent=1)
    with open(os.path.join(OUT, "deform_crossers.json"), "w") as fh:
        json.dump(crossers, fh, indent=1)
    print("RESULT", "FAIL" if fail else "PASS")
    return fail


if __name__ == "__main__":
    failed = run()
    sys.exit(1 if failed else 0)
