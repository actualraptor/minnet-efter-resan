"""Shared helpers for the scripted Blender asset pipeline.

All assets in this project are generated from these scripts (original work).
Run with Blender 4.5 LTS in background mode, e.g.:
    blender -b --factory-startup --python art/blender/build_characters.py -- <repo_root>
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector


# ---------------------------------------------------------------------------
# Scene / IO
# ---------------------------------------------------------------------------

def repo_root():
    argv = sys.argv
    if "--" in argv:
        return os.path.abspath(argv[argv.index("--") + 1])
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = 30
    scn.unit_settings.system = "METRIC"
    return scn


def export_glb(path, objects=None, animations=True, anim_mode="NLA_TRACKS"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    if objects:
        for o in objects:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=bool(objects),
        export_apply=True,
        export_yup=True,
        export_animations=animations,
        export_animation_mode=anim_mode,
        export_force_sampling=True,
        export_frame_step=1,
        export_skins=True,
        export_all_influences=False,
        export_def_bones=False,
        export_morph=False,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_normals=True,
    )
    print("EXPORTED", path)


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

_MATS = {}


def mat(name, color, rough=0.75, metal=0.0, emit=0.0, alpha=1.0):
    """Principled material; colour as hex string or RGB tuple (sRGB)."""
    if name in _MATS:
        return _MATS[name]
    if isinstance(color, str):
        color = hex_rgb(color)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    lin = tuple(srgb_to_linear(c) for c in color)
    bsdf.inputs["Base Color"].default_value = (*lin, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*lin, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    m.diffuse_color = (*lin, 1.0)
    _MATS[name] = m
    return m


def clear_mat_cache():
    _MATS.clear()


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def assign(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)
    return obj


# ---------------------------------------------------------------------------
# Mesh construction helpers (bmesh based, deterministic)
# ---------------------------------------------------------------------------

def mesh_obj(name, bm, material=None, smooth=True, collection=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    if material:
        ob.data.materials.append(material)
    return ob


def lathe(name, profile, segments=24, material=None, scale_xy=(1.0, 1.0), cap_top=False,
          cap_bottom=False, center=(0, 0, 0), skip_angle=None, smooth=True):
    """Revolve a profile [(radius, z), ...] around Z.

    skip_angle=(centre_deg, half_width_deg, z_below) removes faces in a wedge
    below a height, e.g. to open a coat at the front."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            x = math.cos(a) * r * scale_xy[0] + center[0]
            y = math.sin(a) * r * scale_xy[1] + center[1]
            ring.append(bm.verts.new((x, y, z + center[2])))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for i in range(segments):
            a_mid = math.degrees(2 * math.pi * (i + 0.5) / segments)
            if skip_angle is not None:
                c, hw, zb = skip_angle
                da = (a_mid - c + 180) % 360 - 180
                zmid = (profile[j][1] + profile[j + 1][1]) * 0.5 + center[2]
                if abs(da) < hw and zmid < zb:
                    continue
            v1 = rings[j][i]
            v2 = rings[j][(i + 1) % segments]
            v3 = rings[j + 1][(i + 1) % segments]
            v4 = rings[j + 1][i]
            bm.faces.new((v1, v2, v3, v4))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, smooth)


def ellipsoid(name, center, radii, material=None, segs=16, rings=10, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0] + center[0], v.co.y * radii[1] + center[1], v.co.z * radii[2] + center[2]))
    return mesh_obj(name, bm, material, smooth)


def box(name, center, size, material=None, smooth=False, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=2.0)  # vertices at +-1 so `size` is half-extents
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + center[0], v.co.y * size[1] + center[1], v.co.z * size[2] + center[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return mesh_obj(name, bm, material, smooth)


def cylinder(name, p0, p1, r0, r1=None, material=None, segs=10, caps=True, smooth=True):
    r1 = r0 if r1 is None else r1
    return tube(name, [Vector(p0), Vector(p1)], [r0, r1], material, segs, caps, smooth)


def tube(name, points, radii, material=None, segs=8, caps=True, smooth=True, flatten=1.0, flat_axis=None):
    """Tube along a polyline with per-point radius. flatten<1 squashes the
    cross-section along flat_axis (a world vector), for ribbons of hair."""
    points = [Vector(p) for p in points]
    bm = bmesh.new()
    rings = []
    prev_side = None
    for i, p in enumerate(points):
        if i == 0:
            d = (points[1] - points[0]).normalized()
        elif i == len(points) - 1:
            d = (points[-1] - points[-2]).normalized()
        else:
            d = (points[i + 1] - points[i - 1]).normalized()
        if prev_side is None:
            ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            side = d.cross(ref).normalized()
        else:
            side = (prev_side - d * prev_side.dot(d)).normalized()
        prev_side = side
        up = side.cross(d).normalized()
        ring = []
        for k in range(segs):
            a = 2 * math.pi * k / segs
            off = side * math.cos(a) + up * math.sin(a)
            if flat_axis is not None:
                fa = Vector(flat_axis).normalized()
                off = off - fa * off.dot(fa) * (1.0 - flatten)
            ring.append(bm.verts.new(p + off * radii[i]))
        rings.append(ring)
    for j in range(len(rings) - 1):
        for k in range(segs):
            bm.faces.new((rings[j][k], rings[j][(k + 1) % segs], rings[j + 1][(k + 1) % segs], rings[j + 1][k]))
    if caps:
        if radii[0] > 1e-4:
            bm.faces.new(list(reversed(rings[0])))
        if radii[-1] > 1e-4:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, material, smooth)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def apply_all_modifiers(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def set_origin_world(ob):
    """Ensure object transform is identity (vertex data already in world)."""
    ob.location = (0, 0, 0)
    ob.rotation_euler = (0, 0, 0)
    ob.scale = (1, 1, 1)


def displace_noise(ob, strength=0.03, scale=1.5, seed=0):
    """Deterministic pseudo-noise displacement along normals (no textures)."""
    me = ob.data
    for v in me.vertices:
        p = v.co
        n = (math.sin(p.x * 7.1 * scale + seed) * math.cos(p.y * 5.3 * scale + seed * 1.7)
             + math.sin(p.z * 6.7 * scale + seed * 0.3) * 0.6
             + math.sin((p.x + p.y + p.z) * 13.0 * scale + seed) * 0.25)
        v.co = p + v.normal * n * strength


def vertex_color_fill(ob, rgba_fn):
    """Fill a vertex colour attribute named 'Col' via rgba_fn(co, normal)."""
    me = ob.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    attr = me.color_attributes["Col"]
    for i, v in enumerate(me.vertices):
        attr.data[i].color = rgba_fn(v.co, v.normal)
    me.color_attributes.active_color = attr


# ---------------------------------------------------------------------------
# Preview rendering (Workbench, background-safe)
# ---------------------------------------------------------------------------

def render_preview(path, targets, views=((0, "front"), (90, "side"), (180, "back"), (35, "three_quarter")),
                   size=(1600, 900), height=1.7, distance=None, ortho=True, elevation=8.0, look_z=None):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"
    scn.display.shading.color_type = "TEXTURE"
    scn.display.shading.show_shadows = True
    scn.display.shading.show_cavity = True
    scn.display.shading.show_object_outline = True
    scn.display.shading.background_type = "VIEWPORT"
    scn.view_settings.view_transform = "Standard"
    scn.world = scn.world or bpy.data.worlds.new("W")
    scn.world.color = (0.82, 0.86, 0.8)
    scn.render.resolution_x = size[0] // len(views)
    scn.render.resolution_y = size[1]
    scn.render.film_transparent = False
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scn.collection.objects.link(cam)
    scn.camera = cam
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = height * 1.15
    else:
        cam_data.lens = 50
    look_z = height * 0.5 if look_z is None else look_z
    dist = distance or 6.0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    files = []
    for yaw, label in views:
        a = math.radians(yaw)
        e = math.radians(elevation)
        # Character faces -Y; "front" camera sits at -Y looking +Y.
        pos = Vector((math.sin(a) * dist * math.cos(e), -math.cos(a) * dist * math.cos(e), look_z + math.sin(e) * dist))
        cam.location = pos
        direction = Vector((0, 0, look_z)) - pos
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        f = path.replace(".png", f"_{label}.png")
        scn.render.filepath = f
        bpy.ops.render.render(write_still=True)
        files.append(f)
    bpy.data.objects.remove(cam)
    return files
