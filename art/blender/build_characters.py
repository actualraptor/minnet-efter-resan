"""Builds the milestone-001 characters as rigged, animated GLBs.

    blender -b --factory-startup --python art/blender/build_characters.py -- <repo_root> [names...]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib_common as C  # noqa: E402
import lib_character as L  # noqa: E402
import lib_freyja  # noqa: E402
import lib_villagers  # noqa: E402
from lib_character import smooth_pulse as sp_  # noqa: E402

SPECS = {
    "freyja": {
        "name": "freyja", "height": 1.68, "ears": "elf", "hair_style": "long2", "bangs": 7,
        "outfit": "mage2", "staff": None, "eye_size": 1.22, "face_texture": True, "head_scale": 1.1, "ear_color": "#f3c3bb", "smile": 0.25, "boot_top": 0.47, "anim_set": "mage",
        "colors": {
            "skin": "#f7e1d6", "hair": "#ebe8f2", "brow": "#c9c4d8", "eyes": "#2fae94", "lash": "#4a3b52",
            "tunic": "#9cbc8a", "cream": "#efe5cc", "mantle": "#5f8b83", "plum": "#7b4f7a",
            "legs": "#3a2e33", "boots": "#7a5236", "sleeve": "#efe5cc", "torso": "#efe5cc", "mouth": "#c07a7a",
        },
    },
    "edda": {
        "name": "edda", "height": 1.55, "ears": "human", "hair_style": "bun", "bangs": 0,
        "outfit": "elder2", "anim_set": "elder", "staff": "cane", "eye_size": 0.8, "eyes_closed_smile": True, "blush": True,
        "wrinkles": True, "smile": 0.9,
        "body_width": 1.15, "head_radii": (0.1, 0.104, 0.112), "boot_top": 0.2, "head_scale": 1.1,
        "radii": {"chest": (0.13, 0.095), "spine": (0.118, 0.09), "pelvis": (0.135, 0.1)},
        "colors": {
            "skin": "#efcfbf", "hair": "#dcd9d4", "brow": "#bdb8b2", "eyes": "#6b7f9a", "lash": "#5a4a4e",
            "dress": "#8a5a3c", "apron": "#efe4cc", "shawl": "#8e5d86", "legs": "#8a5a3c", "boots": "#4e3626",
            "sleeve": "#f1e7d3", "torso": "#f1e7d3", "mouth": "#a8686a",
        },
    },
    "pippa": {
        "name": "pippa", "height": 1.30, "head_scale": 1.2, "ears": "human", "hair_style": "pigtails", "bangs": 5,
        "outfit": "child2", "anim_set": "child", "staff": None, "eye_size": 1.18, "freckles": True, "blush": True, "smile": 0.9,
        "boot_top": 0.27, "radii": {"chest": (0.105, 0.08), "pelvis": (0.115, 0.09), "hip": (0.075, 0.07)},
        "colors": {
            "skin": "#f8dcc8", "hair": "#b5643a", "brow": "#97502e", "eyes": "#5b8a3c", "lash": "#5a3528",
            "pinafore": "#c0643f", "accent": "#7b9f6a", "legs": "#8f6684", "boots": "#7a4a2e",
            "sleeve": "#f6f0e2", "torso": "#f6f0e2", "mouth": "#c26a62",
        },
    },
}


# ---------------------------------------------------------------------------
# Poses
# ---------------------------------------------------------------------------

def relaxed(a, staff=True, spread=0.0):
    a.rot("upper_arm.L", rx=-4, ry=38 - spread)
    a.rot("forearm.L", rx=-12)
    if staff:
        a.rot("upper_arm.R", rx=-18, ry=-26 + spread)
        a.rot("forearm.R", rx=-38)
    else:
        a.rot("upper_arm.R", rx=-4, ry=-38 + spread)
        a.rot("forearm.R", rx=-12)


def hair(a, h1, h2=None, h3=None):
    a.rot("hair.1", rx=h1)
    a.rot("hair.2", rx=h2 if h2 is not None else h1 * 0.6)
    h3 = h3 if h3 is not None else h1 * 0.5
    a.rot("hair.3", rx=h3)
    a.rot("hair.4", rx=h3 * 1.1)


def mage_idle_free(a, t, f):
    """Staff away: relaxed arms, gentle breathing and a slow weight shift."""
    p = math.tau * t
    b = math.sin(p)
    relaxed(a, staff=False)
    a.rot("upper_arm.L", rx=-3 + 1.0 * b, ry=40 + 1.2 * math.sin(p + 0.5))
    a.rot("upper_arm.R", rx=-3 - 1.0 * b, ry=-40 - 1.2 * math.sin(p + 1.1))
    a.rot("forearm.L", rx=-10)
    a.rot("forearm.R", rx=-10)
    a.rot("hips", rz=1.5 * b, ry=1.2 * b)
    a.hips_offset(dz=-0.004 * abs(b), dy=0.0)
    a.rot("spine", rx=1.0 * b)
    a.rot("chest", rx=-1.2 * b, rz=-1.2 * b)
    a.rot("neck", rx=2)
    a.rot("head", rx=-3 + 1.5 * math.sin(p + 1.0), ry=2.5 * math.sin(p))


def mage_summon(a, t, f):
    """Pull the staff out of thin air: right hand sweeps up and out, fingers open,
    then closes around the staff as it materialises (at ~55%) and settles."""
    reach = sp_(t, 0.0, 0.45) * (1 - sp_(t, 0.6, 1.0))
    settle = sp_(t, 0.5, 1.0)
    relaxed(a, staff=False)
    a.rot("upper_arm.R", rx=-3 - 70 * reach - 15 * settle, ry=-40 + 30 * reach + 14 * settle)
    a.rot("forearm.R", rx=-10 - 20 * reach - 28 * settle)
    a.rot("hand.R", rx=-25 * reach, rz=-20 * reach)
    a.rot("upper_arm.L", rx=-3 - 12 * reach, ry=40 - 10 * reach)
    a.rot("chest", rz=-8 * reach, rx=-3 * reach)
    a.rot("head", rz=-10 * reach, rx=-6 * reach)
    # Keep the (still invisible) staff upright so it materialises standing.
    a.staff_upright(tilt_x=6 - 2 * settle, tilt_y=-4 * settle)


def _ease_back(x):
    """0..1 with a small overshoot, for snappy-but-soft settles."""
    c1, c3 = 1.4, 2.4
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def mage_summon_flick(a, t, f):
    """Casual: a quick downward-outward wrist flick at her side; the staff is just there."""
    wind = sp_(t, 0.0, 0.25) * (1 - sp_(t, 0.25, 0.42))
    flick = sp_(t, 0.25, 0.42)
    settle = _ease_back(min(1.0, max(0.0, (t - 0.4) / 0.6)))
    relaxed(a, staff=False)
    a.rot("upper_arm.R", rx=-3 + 8 * wind - 22 * flick * 0.6 - 15 * settle, ry=-40 + 6 * wind + 18 * flick * 0.4 + 14 * settle)
    a.rot("forearm.R", rx=-10 - 35 * wind + 10 * flick * (1 - settle) - 28 * settle)
    a.rot("hand.R", rx=30 * wind - 25 * flick * (1 - settle), rz=15 * wind)
    a.rot("head", rz=-4 * wind, rx=-2 * flick)
    a.staff_upright(tilt_x=6 - 2 * settle, tilt_y=-4 * settle)


def mage_summon_reach(a, t, f):
    """Reaches up into the air above her and draws the staff down out of nothing."""
    up = sp_(t, 0.0, 0.4)
    down = sp_(t, 0.5, 0.95)
    relaxed(a, staff=False)
    lift = up * (1 - down)
    a.rot("upper_arm.R", rx=-3 - 165 * lift - 15 * down, ry=-40 + 12 * lift + 14 * down)
    a.rot("forearm.R", rx=-10 - 10 * lift - 28 * down)
    a.rot("hand.R", rx=-20 * lift)
    a.rot("upper_arm.L", rx=-3 - 10 * lift, ry=40 - 8 * lift)
    a.rot("spine", rx=-4 * lift)
    a.rot("chest", rx=-4 * lift, rz=-5 * lift)
    a.rot("head", rx=-16 * lift, rz=-6 * lift)
    a.hips_offset(dz=0.012 * lift * a.rig.s)
    a.staff_upright(tilt_x=6 - 2 * down, tilt_y=-4 * down)


def mage_summon_twirl(a, t, f):
    """Left palm opens, the staff appears lying across her right hand and she spins it upright."""
    show = sp_(t, 0.0, 0.3)
    spin = sp_(t, 0.35, 0.8)
    settle = sp_(t, 0.75, 1.0)
    relaxed(a, staff=False)
    a.rot("upper_arm.L", rx=-3 - 40 * show * (1 - settle), ry=40 - 20 * show * (1 - settle))
    a.rot("forearm.L", rx=-10 - 50 * show * (1 - settle))
    a.rot("hand.L", rx=-40 * show * (1 - settle))
    a.rot("upper_arm.R", rx=-3 - 40 * show - 5 * spin, ry=-40 + 28 * show - 14 * spin + 14 * settle)
    a.rot("forearm.R", rx=-10 - 50 * show + 22 * spin - 28 * settle * 0.0)
    a.rot("chest", rz=-6 * show * (1 - settle))
    a.rot("head", rx=-6 * show * (1 - settle))
    # Staff lies sideways (90 deg) then twirls upright through a full turn.
    a.staff_upright(tilt_x=6 * settle, tilt_y=-90 * (1 - spin) - 360 * spin * (1 - settle) * 0.0 - 4 * settle)


def mage_cast2(a, t, f):
    """Field of Flowers: anticipation, staff sweeps up overhead with the free hand
    opening out, a held gather, then the staff is planted in front with a step
    while the free hand sweeps outward to spread the wave, and a soft settle."""
    antic = sp_(t, 0.0, 0.12) * (1 - sp_(t, 0.12, 0.3))
    rise = sp_(t, 0.1, 0.45) * (1 - sp_(t, 0.6, 0.67))
    gather = sp_(t, 0.42, 0.6) * (1 - sp_(t, 0.6, 0.66))
    strike = sp_(t, 0.6, 0.68) * (1 - sp_(t, 0.82, 1.0))
    breathe = math.sin(t * math.tau * 3) * gather
    # Arms
    a.rot("upper_arm.R", rx=-18 + 8 * antic - 120 * rise - 40 * strike, ry=-26 + 18 * rise + 8 * strike)
    a.rot("forearm.R", rx=-38 - 20 * antic - 6 * rise - 25 * strike)
    a.rot("upper_arm.L", rx=-4 - 35 * rise - 40 * strike, ry=38 - 55 * rise - 70 * strike + 3 * breathe)
    a.rot("forearm.L", rx=-12 - 30 * rise + 10 * strike)
    a.rot("hand.L", rx=-30 * rise - 15 * strike, rz=25 * strike)
    # Body: rise onto the toes for the gather, then step and dip into the strike.
    a.rot("spine", rx=4 * antic - 9 * rise + 12 * strike)
    a.rot("chest", rx=2 * antic - 7 * rise + 6 * strike, rz=6 * strike)
    a.rot("neck", rx=-4 * rise + 2 * strike)
    a.rot("head", rx=-14 * rise + 6 * strike, rz=-4 * strike)
    a.hips_offset(dz=(0.015 * rise - 0.06 * strike - 0.01 * antic) * a.rig.s, dy=-0.03 * strike * a.rig.s)
    a.rot("thigh.R", rx=-28 * strike)
    a.rot("shin.R", rx=34 * strike)
    a.rot("foot.R", rx=-6 * strike)
    a.rot("thigh.L", rx=10 * strike)
    a.rot("shin.L", rx=18 * strike)
    a.rot("foot.L", rx=-14 * strike + 10 * rise)
    a.staff_upright(tilt_x=4 - 18 * rise + 34 * strike, tilt_y=-4)


def mage_talk_free(a, t, f):
    """Conversational gestures without the staff: small, understated."""
    p = math.tau * t
    relaxed(a, staff=False)
    a.rot("upper_arm.L", rx=-14 + 5 * math.sin(p), ry=32)
    a.rot("forearm.L", rx=-48 + 10 * math.sin(2 * p))
    a.rot("hand.L", rz=8 * math.sin(2 * p))
    a.rot("upper_arm.R", rx=-6 + 3 * math.sin(p + 1.4), ry=-38)
    a.rot("forearm.R", rx=-22 + 6 * math.sin(2 * p + 1.0))
    a.rot("head", rx=-2 + 2.5 * math.sin(2 * p), ry=3 * math.sin(p), rz=2 * math.sin(p + 0.7))
    a.rot("spine", rx=1.0 * math.sin(p))
    a.rot("hips", rz=1.2 * math.sin(p))
    a.staff_upright(tilt_x=5, tilt_y=-4)


def mage_idle(a, t, f):
    p = math.tau * t
    b = math.sin(p)
    relaxed(a)
    a.rot("upper_arm.L", rx=-4 + 1.0 * b, ry=38 + 1.5 * math.sin(p + 0.5))
    a.rot("spine", rx=1.0 * b)
    a.rot("chest", rx=-1.2 * b)
    a.rot("neck", rx=2)
    a.rot("head", rx=-3 + 1.5 * math.sin(p + 1.0), ry=2.0 * math.sin(p))
    hair(a, 6 + 2 * math.sin(p + 0.5), 4 + 2 * math.sin(p + 1.2), 3 + 2 * math.sin(p + 2.0))
    a.staff_upright(tilt_x=4 + 1.0 * b, tilt_y=-4)


def walk_legs(a, p, amp, knee, foot_k=0.8, bob=0.02):
    s = math.sin(p)
    for side, sign in (("L", -1), ("R", 1)):
        th = sign * amp * s
        swing = max(0.0, math.cos(p) * (1 if side == "L" else -1))
        kn = 6 + knee * swing ** 1.2
        a.rot(f"thigh.{side}", rx=th - 3)
        a.rot(f"shin.{side}", rx=kn)
        a.rot(f"foot.{side}", rx=-(th + kn) * foot_k * 0.6)
    a.hips_offset(dz=-bob * abs(s) * a.rig.s)
    a.rot("hips", rz=-5 * s)
    a.rot("chest", rz=4 * s)
    return s


def mage_walk(a, t, f):
    p = math.tau * t
    s = walk_legs(a, p, 27, 40)
    a.rot("spine", rx=3)
    a.rot("upper_arm.L", rx=-4 + 18 * s, ry=38)
    a.rot("forearm.L", rx=-14 - 10 * max(0, -s))
    a.rot("upper_arm.R", rx=-18 - 6 * s, ry=-26)
    a.rot("forearm.R", rx=-38)
    a.rot("head", rx=-2, rz=-2 * s)
    hair(a, 10 + 3 * math.sin(2 * p), 6 + 4 * math.sin(2 * p + 1), 5 + 5 * math.sin(2 * p + 2))
    a.staff_upright(tilt_x=9 + 4 * s, tilt_y=-4)


def mage_run(a, t, f):
    p = math.tau * t
    s = math.sin(p)
    for side, sign in (("L", -1), ("R", 1)):
        th = sign * 42 * s - 8
        swing = max(0.0, math.cos(p) * (1 if side == "L" else -1))
        kn = 18 + 78 * swing
        a.rot(f"thigh.{side}", rx=th)
        a.rot(f"shin.{side}", rx=kn)
        a.rot(f"foot.{side}", rx=-(th + kn) * 0.45)
    a.hips_offset(dz=(0.03 * abs(math.cos(p)) - 0.03) * a.rig.s)
    a.rot("hips", rz=-7 * s)
    a.rot("spine", rx=10)
    a.rot("chest", rx=4, rz=6 * s)
    a.rot("head", rx=-9, rz=-3 * s)
    a.rot("upper_arm.L", rx=-10 + 38 * s, ry=30)
    a.rot("forearm.L", rx=-75)
    a.rot("upper_arm.R", rx=-30 - 14 * s, ry=-20)
    a.rot("forearm.R", rx=-62)
    hair(a, 26 + 4 * math.sin(2 * p), 16 + 5 * math.sin(2 * p + 1), 12 + 6 * math.sin(2 * p + 2))
    a.staff_upright(tilt_x=38 + 5 * s, tilt_y=-8)


def mage_jump(a, t, f):
    """Free-armed take-off: knees tuck, both arms lift and open for balance
    (the summoned staff, when out, simply rides along in the right hand)."""
    tuck = sp_(t, 0.0, 0.45)
    relaxed(a, staff=False)
    a.rot("thigh.L", rx=-45 * tuck)
    a.rot("shin.L", rx=70 * tuck)
    a.rot("thigh.R", rx=-18 * tuck)
    a.rot("shin.R", rx=45 * tuck)
    a.rot("upper_arm.L", rx=-4 - 30 * tuck, ry=40 - 24 * tuck)
    a.rot("forearm.L", rx=-12 - 30 * tuck)
    a.rot("upper_arm.R", rx=-4 - 22 * tuck, ry=-40 + 26 * tuck)
    a.rot("forearm.R", rx=-12 - 34 * tuck)
    a.rot("spine", rx=4 * tuck)
    a.rot("head", rx=-4 * tuck)
    hair(a, 4 + 14 * tuck, 10 * tuck, 8 * tuck)
    a.staff_upright(tilt_x=12, tilt_y=-6)  # wrist only: keeps a summoned staff clear of the legs


def mage_fall(a, t, f):
    """Free-armed fall: arms out and fluttering a little, legs reaching for ground."""
    p = math.tau * t
    relaxed(a, staff=False)
    a.rot("thigh.L", rx=-18 + 5 * math.sin(p))
    a.rot("thigh.R", rx=-6 - 5 * math.sin(p))
    a.rot("shin.L", rx=32)
    a.rot("shin.R", rx=22)
    a.rot("upper_arm.L", rx=-14 + 3 * math.sin(p), ry=22 + 4 * math.sin(p))
    a.rot("upper_arm.R", rx=-12 - 3 * math.sin(p), ry=-24 - 4 * math.sin(p + 0.7))
    a.rot("forearm.L", rx=-24)
    a.rot("forearm.R", rx=-26)
    hair(a, 24 + 5 * math.sin(p), 14 + 4 * math.sin(p + 1), 10 + 4 * math.sin(p + 2))
    a.staff_upright(tilt_x=14, tilt_y=-6)


def mage_cast(a, t, f):
    raise_ = sp_(t, 0.06, 0.48) * (1 - sp_(t, 0.6, 0.68))
    strike = sp_(t, 0.6, 0.68) * (1 - sp_(t, 0.8, 1.0))
    a.rot("upper_arm.R", rx=-18 - 84 * raise_ - 30 * strike, ry=-26 + 16 * raise_ + 6 * strike)
    a.rot("forearm.R", rx=-38 - 14 * raise_ - 22 * strike)
    a.rot("upper_arm.L", rx=-4 - 52 * raise_ - 22 * strike, ry=38 - 26 * raise_ - 40 * strike)
    a.rot("forearm.L", rx=-12 - 38 * raise_ + 8 * strike)
    a.rot("hand.L", rx=-25 * raise_)
    a.rot("spine", rx=-6 * raise_ + 10 * strike)
    a.rot("chest", rx=-5 * raise_ + 5 * strike)
    a.rot("head", rx=-12 * raise_ + 9 * strike)
    a.hips_offset(dz=-0.05 * strike * a.rig.s)
    for side in ("L", "R"):
        a.rot(f"thigh.{side}", rx=-12 * strike)
        a.rot(f"shin.{side}", rx=22 * strike)
        a.rot(f"foot.{side}", rx=-10 * strike)
    hair(a, 6 + 10 * raise_ + 16 * strike, 4 + 6 * raise_ + 10 * strike, 3 + 5 * raise_ + 8 * strike)
    a.staff_upright(tilt_x=4 - 10 * raise_ + 30 * strike, tilt_y=-4)


def mage_talk(a, t, f):
    p = math.tau * t
    relaxed(a)
    a.rot("upper_arm.L", rx=-20 + 6 * math.sin(p), ry=30)
    a.rot("forearm.L", rx=-58 + 12 * math.sin(2 * p))
    a.rot("hand.L", rz=10 * math.sin(2 * p))
    a.rot("head", rx=-2 + 3 * math.sin(2 * p), ry=3 * math.sin(p))
    a.rot("spine", rx=1.0 * math.sin(p))
    hair(a, 6 + 2 * math.sin(p), 4 + 2 * math.sin(p + 1), 3 + 2 * math.sin(p + 2))
    a.staff_upright(tilt_x=5, tilt_y=-4)


# Edda ------------------------------------------------------------------------

def elder_base(a, t):
    p = math.tau * t
    a.rot("spine", rx=9 + 0.8 * math.sin(p))
    a.rot("chest", rx=7)
    a.rot("neck", rx=-6)
    a.rot("head", rx=-8 + 2 * math.sin(p + 1))
    for side in ("L", "R"):
        a.rot(f"thigh.{side}", rx=-6)
        a.rot(f"shin.{side}", rx=10)
        a.rot(f"foot.{side}", rx=-4)
    a.hips_offset(dz=-0.012 * a.rig.s)
    a.rot("upper_arm.R", rx=-10, ry=-32)
    a.rot("forearm.R", rx=-22)


def elder_idle(a, t, f):
    elder_base(a, t)
    p = math.tau * t
    a.rot("upper_arm.L", rx=-16, ry=40)
    a.rot("forearm.L", rx=-58 + 2 * math.sin(p))
    a.staff_upright(tilt_x=10, tilt_y=-3)


def elder_talk(a, t, f):
    elder_base(a, t)
    p = math.tau * t
    a.rot("upper_arm.L", rx=-26 + 8 * math.sin(p), ry=32)
    a.rot("forearm.L", rx=-62 + 16 * math.sin(2 * p))
    a.rot("hand.L", rz=12 * math.sin(2 * p))
    a.rot("head", rx=-8 + 4 * math.sin(2 * p), ry=4 * math.sin(p))
    a.staff_upright(tilt_x=10, tilt_y=-3)


def elder_sit(a, t, f, talk=False):
    p = math.tau * t
    s = a.rig.s
    a.hips_offset(dz=-(0.925 * s - 0.5), dy=0.04)
    for side in ("L", "R"):
        a.rot(f"thigh.{side}", rx=-84, rz=4 if side == "L" else -4)
        a.rot(f"shin.{side}", rx=84)
        a.rot(f"foot.{side}", rx=0)
    a.rot("spine", rx=6 + 0.8 * math.sin(p))
    a.rot("chest", rx=5)
    a.rot("neck", rx=-4)
    if talk:
        a.rot("head", rx=-6 + 4 * math.sin(2 * p), ry=4 * math.sin(p))
        a.rot("upper_arm.L", rx=-36 + 6 * math.sin(p), ry=30)
        a.rot("forearm.L", rx=-60 + 14 * math.sin(2 * p))
    else:
        a.rot("head", rx=-5 + 2 * math.sin(p + 1))
        a.rot("upper_arm.L", rx=-30, ry=36)
        a.rot("forearm.L", rx=-46)
    a.rot("upper_arm.R", rx=-22, ry=-30)
    a.rot("forearm.R", rx=-40)
    a.staff_upright(tilt_x=-4, tilt_y=12)


# Pippa -----------------------------------------------------------------------

def child_idle(a, t, f):
    p = math.tau * t
    s = math.sin(p)
    a.rot("hips", rz=3 * s, ry=2 * s)
    a.rot("chest", rz=-3 * s)
    a.hips_offset(dz=0.006 * math.sin(2 * p) * a.rig.s)
    for side, sign in (("L", 1), ("R", -1)):
        a.rot(f"upper_arm.{side}", rx=24, ry=34 * sign)
        a.rot(f"forearm.{side}", rx=-38)
        a.rot(f"thigh.{side}", rx=0, ry=2 * s * sign)
    a.rot("head", rx=-3, ry=5 * math.sin(p + 0.7), rz=4 * s)


def child_talk(a, t, f):
    p = math.tau * t
    s = math.sin(p)
    a.hips_offset(dz=0.012 * abs(math.sin(2 * p)) * a.rig.s)
    a.rot("upper_arm.L", rx=-30 + 16 * math.sin(2 * p), ry=26)
    a.rot("forearm.L", rx=-60 + 14 * math.sin(2 * p + 1))
    a.rot("upper_arm.R", rx=-24 + 16 * math.sin(2 * p + 2), ry=-26)
    a.rot("forearm.R", rx=-58 + 14 * math.sin(2 * p + 3))
    a.rot("head", rx=-4 + 5 * math.sin(2 * p), ry=6 * s)
    a.rot("chest", rx=-3 * math.sin(2 * p))


def child_hop(a, t, f):
    p = math.tau * t
    h = abs(math.sin(p))
    a.hips_offset(dz=0.07 * h * a.rig.s)
    for side, sign in (("L", 1), ("R", -1)):
        a.rot(f"upper_arm.{side}", rx=-40 - 30 * h, ry=10 * sign)
        a.rot(f"forearm.{side}", rx=-30)
        a.rot(f"thigh.{side}", rx=-14 * (1 - h))
        a.rot(f"shin.{side}", rx=26 * (1 - h))
        a.rot(f"foot.{side}", rx=-12 * (1 - h) + 15 * h)
    a.rot("head", rx=-6 * h)


ANIMS = {
    "mage": [("Idle", 120, mage_idle_free, True), ("IdleStaff", 90, mage_idle, True), ("Summon", 27, mage_summon, False), ("SummonFlick", 22, mage_summon_flick, False), ("SummonReach", 30, mage_summon_reach, False), ("SummonTwirl", 30, mage_summon_twirl, False), ("Walk", 24, mage_walk, True), ("Run", 18, mage_run, True),
             ("Jump", 14, mage_jump, False), ("Fall", 20, mage_fall, True), ("Cast", 48, mage_cast2, False),
             ("Talk", 72, mage_talk_free, True)],
    "elder": [("Idle", 120, elder_idle, True), ("Talk", 72, elder_talk, True),
              ],
    "child": [("Idle", 80, child_idle, True), ("Talk", 48, child_talk, True), ("Hop", 16, child_hop, True)],
}


def build(name, root):
    C.reset_scene()
    C.clear_mat_cache()
    spec = SPECS[name]
    rig = L.Rig(spec)
    L.build_body(rig)
    L.build_head(rig)
    if spec["outfit"] == "mage2":
        lib_freyja.build(rig)
    elif spec["outfit"] == "elder2":
        lib_villagers.edda_hair(rig)
        lib_villagers.edda(rig)
    elif spec["outfit"] == "child2":
        L.build_hair(rig)
        lib_villagers.pippa(rig)
    else:
        L.build_hair(rig)
        {"mage": L.outfit_mage, "elder": L.outfit_elder, "child": L.outfit_child}[spec["outfit"]](rig)
    if spec.get("staff"):
        L.staff(rig, kind=spec["staff"])
    arm = L.build_armature(rig)
    for ob, _, _ in rig.objects:
        C.set_origin_world(ob)
    L.skin_all(rig)
    tip_empty = None
    if getattr(rig, "staff_tip", None) is not None:
        tip_empty = bpy.data.objects.new("StaffTip", None)
        bpy.context.scene.collection.objects.link(tip_empty)
        tip_empty.parent = arm
        tip_empty.parent_type = "BONE"
        tip_empty.parent_bone = "hand.R"
        bpy.context.view_layer.update()
        tip_empty.matrix_world = Matrix.Translation(rig.staff_tip)
    anim = L.Animator(rig)
    for (aname, frames, fn, loop) in ANIMS[spec.get("anim_set", spec["outfit"])]:
        anim.action(aname, frames, fn, loop)
    anim.reset()
    out_dir = os.path.join(root, "game", "assets", "models", "characters")
    if spec.get("face_texture"):
        import lib_face
        hr = rig.head_radii()
        for expr in lib_face.EXPRESSIONS:
            lib_face.save_png(lib_face.paint_face(spec, hr.x, hr.z, expr), os.path.join(out_dir, "faces", f"{name}_{expr}.png"))
    objs = [arm] + [o for o, _, _ in rig.objects] + ([tip_empty] if tip_empty else [])
    C.export_glb(os.path.join(out_dir, f"{name}.glb"), objs)
    # Previews: rest turnaround + key frames of each animation (verifies the rig).
    prev = os.path.join(root, "art", "previews", f"{name}.png")
    for tr in arm.animation_data.nla_tracks:
        tr.mute = True
    anim.reset()
    bpy.context.view_layer.update()
    C.render_preview(prev, objs, height=spec["height"] * 1.12, look_z=spec["height"] * 0.55)
    C.render_preview(prev.replace(".png", "_head.png"), objs, views=((0, "front"), (35, "tq"), (180, "back")),
                     height=0.62 * spec["height"] / 1.68, look_z=spec["height"] * 0.86, size=(1500, 620), elevation=4)
    ad = arm.animation_data
    for tr in ad.nla_tracks:
        tr.mute = True
    poses = []
    for (aname, frames, fn, loop) in ANIMS[spec.get("anim_set", spec["outfit"])]:
        act = bpy.data.actions.get(aname)
        ad.action = act
        try:
            if act.slots:
                ad.action_slot = act.slots[0]
        except AttributeError:
            pass
        f = int(frames * (0.55 if aname == "Cast" else 0.25))
        bpy.context.scene.frame_set(f)
        poses += C.render_preview(prev.replace(".png", f"_pose_{aname}.png"), objs, views=((30, "q"),),
                                  height=spec["height"] * 1.25, look_z=spec["height"] * 0.55, size=(400, 900))
    ad.action = None
    print("POSES", poses)
    tris = sum(len(o.data.polygons) for o, _, _ in rig.objects)
    print(f"BUILT {name}: {len(rig.objects)} meshes, {tris} faces, bones={len(arm.data.bones)}")


if __name__ == "__main__":
    root = C.repo_root()
    names = [a for a in sys.argv[sys.argv.index("--") + 2:]] if "--" in sys.argv and len(sys.argv) > sys.argv.index("--") + 2 else list(SPECS)
    for n in names:
        build(n, root)
