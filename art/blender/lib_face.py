"""Procedural anime face texture (painted with numpy, no external art).

The image covers the front of the head ellipsoid via planar projection:
  u = 0.5 + x / (2 * FX * rx),  v = 0.5 + (z - cz) / (2 * FZ * rz)
Everything outside the features is flat skin, so sides/back stay seamless.
"""
import math

import bpy
import numpy as np

FX = 1.12
FZ = 1.12
SIZE = 1024
SS = 1  # supersampling (2 = slower, marginally smoother)


def _hex(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _soft(d, aa):
    """Coverage from signed distance (negative inside)."""
    return np.clip(0.5 - d / aa, 0.0, 1.0)


class Canvas:
    def __init__(self, n, skin):
        self.n = n
        self.rgb = np.ones((n, n, 3)) * skin
        y, x = np.mgrid[0:n, 0:n]
        # normalised coords: u right, v up, both in [0, 1]
        self.u = (x + 0.5) / n
        self.v = 1.0 - (y + 0.5) / n
        self.aa = 1.5 / n

    def paint(self, mask, color, alpha=1.0):
        a = np.clip(mask * alpha, 0, 1)[..., None]
        self.rgb = self.rgb * (1 - a) + np.asarray(color) * a

    def ellipse(self, cu, cv, ru, rv, rot=0.0):
        du, dv = self.u - cu, self.v - cv
        c, s = math.cos(rot), math.sin(rot)
        x = (du * c + dv * s) / ru
        y = (-du * s + dv * c) / rv
        d = (np.sqrt(x * x + y * y) - 1.0) * min(ru, rv)
        return d

    def curve(self, pts, width):
        """Distance to a polyline (list of (u, v)); returns signed distance to a stroke."""
        best = np.full(self.u.shape, 1e9)
        for (a, b) in zip(pts[:-1], pts[1:]):
            ax, ay = a
            bx, by = b
            px, py = self.u - ax, self.v - ay
            ex, ey = bx - ax, by - ay
            t = np.clip((px * ex + py * ey) / (ex * ex + ey * ey + 1e-12), 0, 1)
            dx, dy = px - ex * t, py - ey * t
            best = np.minimum(best, np.sqrt(dx * dx + dy * dy))
        return best - width


def _bezier(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in [i / (n - 1) for i in range(n)]]


EXPRESSIONS = ("neutral", "blink", "happy", "talk", "surprised")


def paint_face(spec, rx, rz, expr="neutral"):
    """Returns an (n, n, 4) float RGBA array of the face texture."""
    n = SIZE * SS
    col = spec["colors"]
    skin = _hex(col["skin"])
    cv_ = Canvas(n, skin)
    # Map metres on the head to UV.
    U = lambda x: 0.5 + x / (2 * FX * rx)
    V = lambda dz: 0.5 + dz / (2 * FZ * rz)
    hs = spec.get("head_scale", 1.0) * spec["height"] / 1.68
    es = spec.get("eye_size", 1.0)
    eye_dz = -0.012 * hs
    ex = 0.037 * hs * spec.get("eye_spacing", 1.0)
    ew = 0.024 * hs * es          # eye half-width (m)
    eh = 0.021 * hs * es          # eye half-height (m)
    iris_c = _hex(col["eyes"])
    iris_dark = iris_c * 0.32
    iris_light = np.clip(iris_c * 1.35 + 0.08, 0, 1)
    lash = _hex(col.get("lash", "#3a2a3e"))
    # Blush
    for side in (1, -1):
        d = cv_.ellipse(U(0.052 * hs * side), V(eye_dz - 0.03 * hs), (0.018 * hs) / (2 * FX * rx), (0.009 * hs) / (2 * FZ * rz))
        cv_.paint(np.clip(1 - (d / (0.008 * hs / (2 * FX * rx)) + 1) * 0.5, 0, 1) ** 1.5, _hex("#f2a0a0"), 0.55)
        # little blush hatching strokes
        for k in range(3):
            x0 = 0.045 * hs * side + (k - 1) * 0.006 * hs
            pts = [(U(x0), V(eye_dz - 0.026 * hs)), (U(x0 - 0.004 * hs * side), V(eye_dz - 0.034 * hs))]
            cv_.paint(_soft(cv_.curve(pts, 0.0012), cv_.aa), _hex("#e88a8a"), 0.6)
    for side in (1, -1):
        cx, cz = ex * side, eye_dz
        cu, cvv = U(cx), V(cz)
        ru, rv = ew / (2 * FX * rx), eh / (2 * FZ * rz)
        brow_lift = rv * (0.45 if expr == "surprised" else 0.0)
        if expr in ("blink", "happy"):
            # Closed eyes: a lash arc (down-curved when blinking, up-curved when laughing).
            bend = 0.55 if expr == "happy" else -0.25
            arc = _bezier((cu - side * ru * 1.0, cvv - rv * 0.05), (cu + side * ru * 0.05, cvv + rv * bend * 1.4), (cu + side * ru * 1.1, cvv + rv * 0.05))
            for i in range(len(arc) - 1):
                cv_.paint(_soft(cv_.curve([arc[i], arc[i + 1]], 0.0042 + 0.004 * i / len(arc)), cv_.aa), lash)
            if expr == "blink":
                low = _bezier((cu - side * ru * 0.2, cvv - rv * 0.35), (cu + side * ru * 0.5, cvv - rv * 0.45), (cu + side * ru * 0.9, cvv - rv * 0.25))
                cv_.paint(_soft(cv_.curve(low, 0.0012), cv_.aa), lash, 0.6)
            brow = _bezier((cu - side * ru * 0.85, cvv + rv * 1.95), (cu + side * ru * 0.1, cvv + rv * 2.35), (cu + side * ru * 0.95, cvv + rv * 1.95))
            cv_.paint(_soft(cv_.curve(brow, 0.0014), cv_.aa), _hex(col.get("brow", col["hair"])), 0.9)
            continue
        # Eye white: almond, flatter on top.
        white_d = cv_.ellipse(cu, cvv - rv * 0.08, ru * 0.96, rv * 0.86)
        white = _soft(white_d, cv_.aa)
        cv_.paint(white, _hex("#fdfaf6"))
        # Upper-lid shadow on the white.
        shade = white * np.clip((cv_.v - (cvv + rv * 0.2)) / (rv * 0.7), 0, 1)
        cv_.paint(shade, _hex("#d9cfe0"), 0.8)
        # Iris: tall ellipse with a vertical gradient, clipped to the white.
        iu, iv = cu - side * ru * 0.06, cvv - rv * 0.06
        iris_d = cv_.ellipse(iu, iv, ru * 0.62, rv * 0.92)
        iris = _soft(iris_d, cv_.aa) * white
        t = np.clip((cv_.v - (iv - rv * 0.9)) / (rv * 1.8), 0, 1)[..., None]
        grad = iris_light * (1 - t) + iris_dark * t
        a = iris[..., None]
        cv_.rgb = cv_.rgb * (1 - a) + grad * a
        # Iris rim and a soft ring.
        ring = _soft(np.abs(iris_d) - 0.0015, cv_.aa) * white
        cv_.paint(ring, iris_dark * 0.8, 0.9)
        # Pupil
        pupil = _soft(cv_.ellipse(iu, iv + rv * 0.05, ru * 0.26, rv * 0.42), cv_.aa) * white
        cv_.paint(pupil, iris_dark * 0.5)
        # Sparkle in the lower iris
        glow = _soft(cv_.ellipse(iu, iv - rv * 0.48, ru * 0.36, rv * 0.18), cv_.aa) * white
        cv_.paint(glow, iris_light * 1.1, 0.55)
        # Highlights
        cv_.paint(_soft(cv_.ellipse(iu + side * ru * 0.22, iv + rv * 0.4, ru * 0.2, rv * 0.24), cv_.aa) * white, _hex("#ffffff"))
        cv_.paint(_soft(cv_.ellipse(iu - side * ru * 0.24, iv - rv * 0.3, ru * 0.08, rv * 0.09), cv_.aa) * white, _hex("#ffffff"), 0.9)
        # Upper lash: thick arc, heavier and winged at the outer corner.
        inner = (cu - side * ru * 1.02, cvv + rv * 0.35)
        top = (cu + side * ru * 0.05, cvv + rv * 1.25)
        outer = (cu + side * ru * 1.15, cvv + rv * 0.62)
        arc = _bezier(inner, top, outer)
        for i, (pu, pv) in enumerate(arc[:-1]):
            frac = i / (len(arc) - 2)
            w = 0.0042 + 0.0062 * math.sin(min(1.0, frac * 1.25) * math.pi * 0.5)
            seg = cv_.curve([arc[i], arc[i + 1]], w)
            cv_.paint(_soft(seg, cv_.aa), lash)
        wing = cv_.curve([outer, (outer[0] + side * ru * 0.32, outer[1] + rv * 0.28)], 0.0028)
        cv_.paint(_soft(wing, cv_.aa), lash)
        # Lower lash: thin partial line at the outer corner.
        low = _bezier((cu - side * ru * 0.1, cvv - rv * 0.95), (cu + side * ru * 0.6, cvv - rv * 0.95), (cu + side * ru * 1.0, cvv - rv * 0.35))
        cv_.paint(_soft(cv_.curve(low, 0.0011), cv_.aa), lash, 0.7)
        # Double-lid crease
        crease = _bezier((cu - side * ru * 0.2, cvv + rv * 1.32), (cu + side * ru * 0.3, cvv + rv * 1.5), (cu + side * ru * 0.8, cvv + rv * 1.25))
        cv_.paint(_soft(cv_.curve(crease, 0.0008), cv_.aa), lash, 0.45)
        # Brow: soft thin arc, hair-coloured.
        brow = _bezier((cu - side * ru * 0.85, cvv + rv * 1.95 + brow_lift), (cu + side * ru * 0.1, cvv + rv * 2.3 + brow_lift), (cu + side * ru * 0.95, cvv + rv * 1.95 + brow_lift))
        cv_.paint(_soft(cv_.curve(brow, 0.0014), cv_.aa), _hex(col.get("brow", col["hair"])), 0.9)
    # Nose: a tiny soft shadow and highlight.
    cv_.paint(_soft(cv_.ellipse(U(0.003 * hs), V(eye_dz - 0.03 * hs), 0.0035, 0.002), cv_.aa), skin * 0.82, 0.8)
    # Mouth: small gentle smile.
    sm = spec.get("smile", 0.3)
    mw = 0.012 * hs
    mz = eye_dz - 0.058 * hs
    mouth_col = _hex(col.get("mouth", "#b0646b"))
    inner = _hex("#7a3a44")
    tongue = _hex("#e48a8e")
    if expr in ("talk", "happy", "surprised"):
        if expr == "happy":
            ow, oh, oz = 0.011 * hs, 0.007 * hs, mz - 0.003 * hs
            d = cv_.ellipse(U(0), V(oz), ow / (2 * FX * rx), oh / (2 * FZ * rz))
            open_m = _soft(d, cv_.aa) * (cv_.v < V(oz + oh * 0.25))  # D-shaped laugh
        elif expr == "surprised":
            ow, oh, oz = 0.005 * hs, 0.0065 * hs, mz - 0.002 * hs
            open_m = _soft(cv_.ellipse(U(0), V(oz), ow / (2 * FX * rx), oh / (2 * FZ * rz)), cv_.aa)
        else:
            ow, oh, oz = 0.008 * hs, 0.0045 * hs, mz - 0.002 * hs
            open_m = _soft(cv_.ellipse(U(0), V(oz), ow / (2 * FX * rx), oh / (2 * FZ * rz)), cv_.aa)
        cv_.paint(open_m, inner)
        tg = _soft(cv_.ellipse(U(0), V(oz - oh * 0.55), ow * 0.6 / (2 * FX * rx), oh * 0.45 / (2 * FZ * rz)), cv_.aa) * open_m
        cv_.paint(tg, tongue)
    else:
        mouth = _bezier((U(-mw), V(mz + 0.002 * hs * sm)), (U(0), V(mz - 0.004 * hs * sm)), (U(mw), V(mz + 0.002 * hs * sm)))
        cv_.paint(_soft(cv_.curve(mouth, 0.0014), cv_.aa), mouth_col)
    rgba = np.concatenate([cv_.rgb, np.ones((n, n, 1))], axis=2)
    # Downsample (box filter) for anti-aliasing.
    rgba = rgba.reshape(SIZE, SS, SIZE, SS, 4).mean(axis=(1, 3))
    return rgba


def make_image(name, rgba):
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    flipped = rgba[::-1]  # Blender images are bottom-up
    img.pixels.foreach_set(flipped.astype(np.float32).ravel())
    img.pack()
    return img


def textured_material(name, img):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.6
    return m


def apply_face_uv(head_obj, center, rx, rz):
    me = head_obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = 0.5 + (co.x - center.x) / (2 * FX * rx)
            v = 0.5 + (co.z - center.z) / (2 * FZ * rz)
            if co.y > center.y + rx * 0.15:
                u, v = 0.02, 0.02  # back of the head: plain skin corner
            uv[li].uv = (min(max(u, 0.005), 0.995), min(max(v, 0.005), 0.995))


def save_png(rgba, path):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = bpy.data.images.new("tmp_face", SIZE, SIZE, alpha=False)
    img.pixels.foreach_set(rgba[::-1].astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
