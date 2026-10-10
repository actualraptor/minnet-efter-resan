"""Milestone 1: reference outfit, separate from the playable character.

blender -b --factory-startup --python art/blender/outfit/build_reference_outfit.py -- <repo>
Exports a skinned GLB, packed editable .blend, body mask and build report.
No simulation is authored or enabled in the review scene.
"""
import json
import math
import os
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_freyja_outfit as B
import tailor as T
import rig_outfit as R

C = B.C
ROOT = B.ROOT
DEST = os.path.join(ROOT, "game", "assets", "models", "characters", "freyja_reference_outfit")
SOURCE = os.path.join(ROOT, "art", "source", "outfits", "freyja_reference")


def mesh(name, grid, materials, border=False):
    """Open quad patch with UVs and visible edge thickness, no intersecting cards."""
    ny, nx = len(grid), len(grid[0])
    vertices = [tuple(p) for row in grid for p in row]
    faces = [(j * nx + i, j * nx + i + 1, (j + 1) * nx + i + 1, (j + 1) * nx + i)
             for j in range(ny - 1) for i in range(nx - 1)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(vertices, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for m in materials:
        me.materials.append(m)
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        j, i = divmod(p.index, nx - 1)
        if border and (i == 0 or i == nx - 2 or j == ny - 2):
            p.material_index = 1
        p.use_smooth = True
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            y, x = divmod(vi, nx)
            uv.data[li].uv = (x / (nx - 1), 1 - y / (ny - 1))
    return ob


def thickness(ob, amount=0.0015):
    T._select_only([ob])
    mod = ob.modifiers.new("Tailored edge thickness", "SOLIDIFY")
    mod.thickness = amount
    mod.offset = 0
    bpy.ops.object.modifier_move_to_index(modifier=mod.name,index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def textile(name, color, embroidered=False, repeats=1):
    base, gold = B._hex(color), B._hex("#cba75f")
    def paint(u, v):
        weave = np.sin(u * math.tau * 155) * np.sin(v * math.tau * 190)
        rgb = np.ones(u.shape + (3,)) * base
        rgb *= (0.985 + 0.015 * weave)[..., None]
        if embroidered:
            # Symmetrical botanical embroidery, laid in UV space along the hem.
            ink = np.zeros(u.shape, dtype=bool)
            motif_u = (u*repeats)%1
            def stroke(x0, y0, x1, y1, width=0.0018):
                dx, dy = x1 - x0, y1 - y0
                t = np.clip(((motif_u-x0)*dx + (v-y0)*dy) / max(dx*dx+dy*dy, 1e-9), 0, 1)
                ink[:] |= (motif_u-x0-t*dx)**2 + (v-y0-t*dy)**2 < width**2
            def curve(points):
                for first,second in zip(points,points[1:]):
                    stroke(*first,*second)
            for center in (0.22, 0.5, 0.78):
                stroke(center, 0.89, center, 0.71)
                for y in (0.79, 0.84):
                    for sign in (-1, 1):
                        stroke(center, y, center + sign*0.04, y-0.04)
                        stroke(center + sign*0.04, y-0.04, center+sign*0.015, y-0.045)
                for sign in (-1, 1):
                    stroke(center, 0.71, center + sign*0.022, 0.742)
                    stroke(center + sign*0.022, 0.742, center, 0.765)
                for sign in (-1,1):
                    # Curling tendrils and outlined leaves, with narrow stems.
                    curve([(center+sign*(0.012+0.06*t),0.87-0.045*math.sin(t*math.pi)) for t in np.linspace(0,1,18)])
                    for level in (0.775,0.835):
                        curve([(center+sign*0.05*math.sin(t*math.pi),level-0.05*t) for t in np.linspace(0,1,20)])
                        curve([(center+sign*0.028*math.sin(t*math.pi),level-0.05*t) for t in np.linspace(0,1,20)])
            # Fine double borders and a repeated scallop vine along the hem.
            ink |= (np.abs(v-(0.935+0.009*np.cos(motif_u*math.tau*8)))<0.0015)
            ink |= (np.abs(v-0.955)<0.0015)
            ink |= (np.abs(v - 0.92) < 0.003) | (np.abs(u - 0.037) < 0.003) | (np.abs(u - 0.963) < 0.003)
            rgb[ink] = gold
        return rgb
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = B._paint(name + "_albedo", 1024, 1024, paint)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.82
    # Portable tangent-space cloth normal texture, rather than a Blender bump node.
    normal = mat.node_tree.nodes.new("ShaderNodeTexImage")
    def normal_pixels(u,v):
        x = 0.045*np.sin(u*math.tau*155)
        y = 0.045*np.sin(v*math.tau*190)
        return np.stack((0.5+x,0.5+y,np.ones_like(u)),axis=-1)
    normal.image = B._paint(name+"_normal",512,512,normal_pixels)
    normal.image.colorspace_settings.name = "Non-Color"
    mapping = mat.node_tree.nodes.new("ShaderNodeNormalMap")
    mapping.inputs["Strength"].default_value = 0.25
    mat.node_tree.links.new(normal.outputs["Color"],mapping.inputs["Color"])
    mat.node_tree.links.new(mapping.outputs["Normal"],bsdf.inputs["Normal"])
    return mat


def leather_material(name,color):
    mat = textile(name,color)
    node = next(n for n in mat.node_tree.nodes if n.type=="TEX_IMAGE" and n.image.colorspace_settings.name!="Non-Color")
    rng = np.random.default_rng(1031)
    grain = rng.normal(0,0.018,(1024,1024,1))
    base = B._hex(color)
    node.image = B._paint(name+"_grain",1024,1024,lambda u,v:np.clip(base*(0.98+grain),0,1))
    mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.58
    return mat


def pipe(name, points, radius, material):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(points)-1)
    for p, co in zip(sp.points, points):
        p.co = (*co, 1)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    cu.materials.append(material)
    T._select_only([ob])
    bpy.ops.object.convert(target="MESH")
    return bpy.context.object


def buckle(name, c, material, size=(0.037, 0.028)):
    x, y, z = c
    w, h = size
    pts = [(x-w/2,y,z-h/2), (x+w/2,y,z-h/2), (x+w/2,y,z+h/2),
           (x-w/2,y,z+h/2), (x-w/2,y,z-h/2)]
    frame = pipe(name, pts, 0.0023, material)
    tongue = pipe(name+"Tongue", [(x-w/2,y-0.001,z), (x+w*0.3,y-0.001,z)], 0.0015, material)
    T._select_only([frame, tongue], frame)
    bpy.ops.object.join()
    return frame


def ornament(name,center,width,height,material,back=False):
    """A shallow four-point filigree star with bevelled front and closed back."""
    sign = 1 if back else -1
    x,y,z = center
    outline = [(x+math.cos(i*math.tau/8)*width/2*(1 if i%2==0 else 0.42),y,
                z+math.sin(i*math.tau/8)*height/2*(1 if i%2==0 else 0.42)) for i in range(8)]
    vertices = [(x,y+sign*0.004,z)]+outline+[(x,y-sign*0.002,z)]
    faces = [(0,1+i,1+(i+1)%8) for i in range(8)]+[(9,1+(i+1)%8,1+i) for i in range(8)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(vertices,[],faces)
    me.materials.append(material)
    ob = bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    return ob


def main():
    os.makedirs(DEST, exist_ok=True)
    os.makedirs(SOURCE, exist_ok=True)
    body = T.Body(B.BODY)
    garments = B.build(body)
    arm = B.rig(body, garments)
    materials = B.mats()
    sage = textile("M_Outfit_EmbroideredSage", "#849277", True)
    cape_sage = textile("M_Outfit_CapeBotanical", "#849277", True, repeats=4)
    plum = textile("M_Outfit_EmbroideredPlum", "#59455e", True)
    cream = textile("M_Outfit_WovenCream", "#eee5d7")
    gold = materials["gold"]
    leather = leather_material("M_Outfit_GrainedLeather","#513829")
    materials["leather_dark"] = leather_material("M_Outfit_DarkLeather","#3f2b22")
    thread = C.mat("M_Outfit_LeatherThread","#b69568",rough=0.9)
    ctr = B.META["skirt_centre"]
    rings = B.META["skirt_rings"]
    top, base_hem = B.META["skirt_top"], B.META["skirt_hem"]
    # Sheet proportions: panels end just below the knee, ruffles lower still.
    knee_z = body.joint("LeftLowerLeg").z
    length = top-(knee_z-0.085)
    hem = top-length
    base_len = top-base_hem
    extra = {}
    hanging = []
    rigid = {}

    def skirt_point(angle, t, offset=0):
        """Measured base envelope (clears hips and legs) continued below its hem,
        plus a bell flare toward the hem; t = 0 waist .. 1 hem."""
        z = top-length*t
        tb = min(1.0, max(0.0, (top-z)/base_len))
        a = angle % math.tau / math.tau * len(rings[0])
        i, f = int(a), a-int(a)
        row = tb*(len(rings)-1)
        j, g = int(row), row-int(row)
        j1 = min(j+1, len(rings)-1)
        p0 = rings[j][i].lerp(rings[j][(i+1)%len(rings[0])], f)
        p1 = rings[j1][i].lerp(rings[j1][(i+1)%len(rings[0])], f)
        p = p0.lerp(p1, g)
        d = Vector((p.x-ctr.x, p.y-ctr.y, 0.0))
        r = d.length
        d.normalize()
        bell = 0.07*T.smoothstep(0.3, 1.0, t)**1.3
        return Vector((ctr.x, ctr.y, z))+d*(r+bell+offset)

    # Four broad pointed sage panels, with separate plum gores between them.
    for k in range(4):
        center = math.radians(225 + 90*k)
        for kind, angle, span, offset, mat in (("SagePanel",center,35,0.012,sage),
                                            ("PlumPanel",center+math.pi/4,16,0.004,plum)):
            grid = []
            for j in range(25):
                t = j/24
                row = []
                for i in range(33):
                    u = i/32
                    # Pointed handkerchief hem; upper part remains tucked under belt.
                    drop = (0.99 - 0.17*abs(2*u-1)**1.3) if kind == "SagePanel" else (1.04 - 0.15*abs(2*u-1)**1.3)
                    p = skirt_point(angle+math.radians(span)*(2*u-1), t*drop, offset)
                    a = angle+math.radians(span)*(2*u-1)
                    p += Vector((math.cos(a),math.sin(a),0)) * (0.003*t*t*math.cos(u*math.tau*4))
                    row.append(p)
                grid.append(row)
            name = f"{kind}{k+1:02d}"
            ob = mesh(name,grid,[mat,gold],True)
            thickness(ob)
            extra[name] = ob
            hanging.append(ob)
    # Three individually modelled gathered ruffles, over a continuous cream lining.
    garments["Skirt"].hide_render = True
    garments["Petticoat"].hide_render = True
    lining_grid = [[skirt_point(math.tau*i/128,j/24,0) for i in range(129)] for j in range(25)]
    lining = mesh("CreamSkirtLining",lining_grid,[cream])
    thickness(lining)
    extra[lining.name] = lining
    hanging.append(lining)
    for layer in range(3):
        # Every tier is sewn on under the panels; the outer tier is the shortest,
        # so each lower tier shows below the one outside it (sheet: SKIRT LAYERS).
        grid = []
        start = 0.8
        end = 1.06+0.045*layer
        outset = 0.007-0.0025*layer
        folds = 30+4*layer
        for j in range(11):
            t = j/10
            row = []
            for i in range(193):
                a = math.tau*i/192
                tt = start+(end-start)*t
                p = skirt_point(a,tt,outset)
                # Gathered folds open toward the hem (rounded crests, soft troughs).
                wave = math.sin(a*folds+0.7*layer)
                below = T.smoothstep(0.95, 1.08, tt)    # free of the panels
                fold = (0.0015+0.013*below)*(0.55+0.45*wave)
                p += Vector((p.x-ctr.x,p.y-ctr.y,0)).normalized()*(fold+0.018*below**2)
                p.z += below*0.004*wave
                row.append(p)
            grid.append(row)
        ob = mesh(f"CreamRuffle{layer+1:02d}",grid,[cream])
        thickness(ob,0.001)
        extra[ob.name] = ob
        hanging.append(ob)

    # Cape embroidery maps around its continuous surface; no floating trim cards.
    garments["Capelet"].data.materials[0] = sage
    # Replace close-fitting arm tubes with continuous, gathered puff sleeves.
    blouse = garments["Blouse"]
    blouse.data.materials.clear()
    blouse.data.materials.append(cream)
    bm = bmesh.new()
    bm.from_mesh(blouse.data)
    shoulder_x = abs(body.joint("LeftUpperArm").x) + 0.015
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(abs(v.co.x)>shoulder_x for v in f.verts)], context="FACES")
    bm.to_mesh(blouse.data)
    bm.free()
    for side in ("Left", "Right"):
        shoulder = body.joint(side+"UpperArm")
        wrist = body.joint(side+"Hand")
        axis = (wrist-shoulder).normalized()
        e1 = axis.cross(Vector((0,0,1))).normalized()
        e2 = axis.cross(e1).normalized()
        grid = []
        for j in range(25):
            t = j/24
            center = shoulder.lerp(wrist,t*0.94)
            ring = []
            for i in range(65):
                a = math.tau*i/64
                r = 0.038*(1-t)+0.03*t+0.056*math.sin(math.pi*t**0.78)**0.9
                r += 0.006*math.sin(a*9+1.2*t)*math.sin(math.pi*t)
                r += 0.004*math.sin(t*math.tau*5+a*2)*math.sin(math.pi*t)**2
                ring.append(center+(e1*math.cos(a)+e2*math.sin(a))*r)
            grid.append(ring)
        ob = mesh(side+"GatheredSleeve",grid,[cream])
        thickness(ob)
        T.transfer_weights(body,ob)
        R.restrict(ob,[side+"Shoulder",side+"UpperArm",side+"LowerArm",side+"Hand","UpperChest","Chest"])
        extra[ob.name] = ob
        body.add_layer(ob)
    # Re-tailor the cape over the new sleeve volume, rather than letting sleeves
    # break through the original close-fitting shoulder envelope.
    old_cape = garments["Capelet"]
    old_cape.hide_render = True
    old_cape.name = "_OldCapelet"
    nc = B.META["cape_centre"]
    neck = body.joint("Neck")
    # The main cape is a structured shoulder shell, authored for lowered arms.
    # It follows the torso in this geometry gate; arm-up corrective deformation
    # is a separate milestone-2 task, not a spring workaround for bad rest fit.
    # The cape is rigid on UpperChest, so its shape must clear the sleeves where
    # the arms actually hang (review pose: 0.85 rad below the T-pose), not the
    # horizontal rest arms. Drape it over rotated copies of the puff sleeves.
    rest_sleeves = [extra[side+"GatheredSleeve"] for side in ("Left","Right")]+[garments["Blouse"], body.shell()]
    posed = []
    rots = {}
    for side in ("Left","Right"):
        piv = body.joint(side+"UpperArm")
        sign = 1 if side == "Left" else -1
        rots[side] = (piv, Matrix.Rotation(sign*0.85, 3, "Y"))
    # Linear-blend-skinned copies in the review pose (arm verts rotate by their
    # arm weight, shoulder verts partially), including the fitted blouse's sleeves.
    for src in rest_sleeves:
        cp = src.copy()
        cp.data = src.data.copy()
        cp.name = "_Posed"+src.name
        bpy.context.collection.objects.link(cp)
        groups = {}
        for side in ("Left","Right"):
            groups[side] = {g.index for g in cp.vertex_groups if g.name in (side+"UpperArm", side+"LowerArm", side+"Hand")}
        for v in cp.data.vertices:
            co = v.co.copy()
            for side in ("Left","Right"):
                w = sum(g.weight for g in v.groups if g.group in groups[side])
                if w > 0:
                    piv, R_ = rots[side]
                    co = co.lerp(piv+R_@(co-piv), min(1.0, w))
            v.co = co
        posed.append(cp)
    saved = list(body.layers)
    rest_shell = body._remesh
    body._remesh = posed[-1]            # the skin itself, arms lowered
    body.layers = [o for o in saved if o not in rest_sleeves]+posed[:-1]
    body._below = {}
    fb_len = 0.25*body.height/1.6
    side_len = abs(body.joint("LeftUpperArm").x-nc.x)+0.15
    def cape_len(a):
        rad = math.radians(a)
        side = abs(math.cos(rad))**1.6
        point = max(0.0, -math.sin(rad))**14*0.055+max(0.0, math.sin(rad))**14*0.035
        return fb_len*(1-side)+side_len*side+point
    cr = T.drop_cloth(body, nc, cape_len, segs=128, rows=20, clearance=0.014, r0=0.06, z_cap=neck.z+0.01, flare=0.1)
    cr = T.push_out(body, cr, nc, 0.012, rows_from=1, reach=0.08)
    cr = T.convexify(cr, nc, rows_from=4)
    body.layers = saved
    body._remesh = rest_shell
    body._below = {}
    for cp in posed:
        bpy.data.objects.remove(cp, do_unlink=True)
    cape = T.revolve("Capelet",cr,128,[cape_sage,gold],lambda j,i:1 if j==19 else 0)
    R.rigid(cape,"UpperChest")
    T.limit_and_normalise(cape,4)
    R.bind(cape,arm)
    garments["Capelet"] = cape
    B.META["cape_rings"] = cr
    garments["Clasp"].hide_render = True
    for label,index,back in (("Front",96,False),("Back",32,True)):
        position = cr[3 if not back else 5][index]+Vector((0,0.004 if back else -0.004,0))
        ob = ornament("Cape"+label+"Brooch",position,0.022,0.036,gold,back)
        extra[ob.name] = ob
        rigid[ob.name] = "UpperChest"
    # Gathered standing collar around the neck, under the cape's neckline.
    nc = B.META["cape_centre"]
    neck = body.joint("Neck")
    grid = []
    for j in range(7):
        t = j/6
        grid.append([Vector((nc.x + (0.058+0.004*t*math.sin(math.tau*i/96*24))*math.cos(math.tau*i/96),
                             nc.y + (0.053+0.004*t*math.sin(math.tau*i/96*24))*math.sin(math.tau*i/96),
                             nc.z+0.009+0.04*t)) for i in range(97)])
    ob = mesh("RuffledCollar",grid,[cream])
    thickness(ob)
    extra[ob.name] = ob
    rigid[ob.name] = "UpperChest"

    # Cuffs: small ruffled rings about each forearm, clear of the fingers.
    for side in ("Left", "Right"):
        wrist = body.joint(side+"Hand")
        elbow = body.joint(side+"LowerArm")
        axis = (wrist-elbow).normalized()
        e1 = axis.cross(Vector((0,0,1))).normalized()
        e2 = axis.cross(e1).normalized()
        grid = []
        for j in range(9):
            t = j/8
            ring = []
            for i in range(65):
                a = math.tau*i/64
                r = 0.034 + 0.015*t + 0.006*t*math.sin(a*12)
                ring.append(wrist-axis*(0.013+0.045*(1-t)) + (e1*math.cos(a)+e2*math.sin(a))*r)
            grid.append(ring)
        ob = mesh(side+"RuffledCuff",grid,[cream])
        thickness(ob)
        extra[ob.name] = ob
        rigid[ob.name] = side+"LowerArm"
        band_grid = []
        for j in range(3):
            center = wrist-axis*(0.06+(j/2-0.5)*0.012)
            band_grid.append([center+(e1*math.cos(math.tau*i/64)+e2*math.sin(math.tau*i/64))*0.039 for i in range(65)])
        ob = mesh(side+"LeatherCuffBand",band_grid,[leather])
        thickness(ob,0.0018)
        extra[ob.name] = ob
        rigid[ob.name] = side+"LowerArm"

    # Leather belts follow the actual corset envelope, with recessed brass tongues.
    corset = garments["Corset"]
    cv = [v.co.copy() for v in corset.data.vertices]
    # A structured leather shell with smooth continuous boning, measured from
    # the fitted source instead of exposing its triangulation in the silhouette.
    bm = bmesh.new()
    bm.from_mesh(corset.data)
    corset_bvh = BVHTree.FromBMesh(bm)
    bm.free()
    # End the structured shell at the waistband. Its old hidden lower lip
    # extended through the skirt's front surface in the detail camera.
    lo, hi = max(min(p.z for p in cv),top+0.002), max(p.z for p in cv)
    grid = []
    for j in range(17):
        z = lo+0.001+(hi-lo-0.002)*j/16
        radii = []
        for i in range(128):
            a = math.tau*i/128
            d = Vector((math.cos(a),math.sin(a),0))
            c = Vector((ctr.x,ctr.y,z))
            hit = corset_bvh.ray_cast(c+d*0.4,-d,0.4)
            radii.append((hit[0]-c).dot(d)+0.001 if hit[0] is not None else 0.125)
        for iteration in range(6):
            radii = [(radii[(i-1)%128]+2*radii[i]+radii[(i+1)%128])/4 for i in range(128)]
        grid.append([Vector((ctr.x+math.cos(math.tau*i/128)*radii[i%128],
                             ctr.y+math.sin(math.tau*i/128)*radii[i%128],z)) for i in range(129)])
    corset.hide_render = True
    corset.name = "_OldCorset"
    corset = mesh("Corset",grid,[leather])
    T.transfer_weights(body,corset)
    R.restrict(corset,["Hips","Spine","Chest","UpperChest"])
    R.bind(corset,arm)
    garments["Corset"] = corset
    cv = [v.co.copy() for v in corset.data.vertices]
    def torso_point(a,z,offset=0.005):
        direction = Vector((math.cos(a),math.sin(a),0))
        angular = (a%math.tau)/math.tau*128
        i, f = int(angular),angular-int(angular)
        vertical = min(16,max(0,(z-lo-0.001)/max(hi-lo-0.002,1e-6)*16))
        j, g = int(vertical),vertical-int(vertical)
        lower = cv[j*129+i].lerp(cv[j*129+i+1],f)
        upper = cv[min(16,j+1)*129+i].lerp(cv[min(16,j+1)*129+i+1],f)
        p = lower.lerp(upper,g)+direction*offset
        p.z = z
        return p
    cz = body.joint("Spine").z
    corset_low, corset_high = min(p.z for p in cv), max(p.z for p in cv)
    belt_low = max(corset_low+0.019,top+0.018)
    for k, frac in enumerate((0.0, 0.55)):
        z = belt_low+frac*(corset_high-0.019-belt_low)
        grid = [[torso_point(math.tau*i/128,z+(j/4-0.5)*0.022) for i in range(129)] for j in range(5)]
        ob = mesh(f"LeatherBelt{k+1}",grid,[leather])
        thickness(ob,0.002)
        extra[ob.name] = ob
        rigid[ob.name] = "Spine"
        p = torso_point(-math.pi/2,z,0.011)
        ob = buckle(f"BrassBuckle{k+1}",p,gold)
        extra[ob.name] = ob
        rigid[ob.name] = "Spine"
    for k in range(4):
        garments[f"Buckle{k}"].hide_render = True
    # Boning channels and fine seams emphasize the corset's tailored structure.
    for k,a in enumerate((math.radians(235),math.radians(305),math.radians(55),math.radians(125))):
        pts = [torso_point(a,corset_low+0.008+(corset_high-corset_low-0.016)*j/20,0.0025) for j in range(21)]
        ob = pipe(f"CorsetBoningSeam{k}",pts,0.0007,thread)
        T.transfer_weights(body,ob)
        R.restrict(ob,["Hips","Spine","Chest","UpperChest"])
        extra[ob.name] = ob
    for label,z in (("Top",corset_high-0.005),("Bottom",corset_low+0.005)):
        ob = pipe("Corset"+label+"Seam",[torso_point(math.tau*i/128,z,0.0025) for i in range(129)],0.0007,thread)
        T.transfer_weights(body,ob)
        R.restrict(ob,["Hips","Spine","Chest","UpperChest"])
        extra[ob.name] = ob

    # Diagonal cross-body leather strap, measured over torso and cape front.
    cap = B.META["cape_rings"]
    grid = []
    for j in range(49):
        t = j/48
        z = cz-0.025 + (neck.z-0.07-(cz-0.025))*t
        x = 0.105-0.23*t
        candidates = sorted(cv,key=lambda p: abs(p.z-z)*2+abs(p.x-x))[:8]
        y = min(p.y for p in candidates)-0.006
        if z > max(p.z for p in cv)-0.015:
            candidates = sorted([p for row in cap for p in row if p.y < nc.y],key=lambda p: abs(p.z-z)*2+abs(p.x-x))[:6]
            y = min(p.y for p in candidates)-0.007
        grid.append([Vector((x+(i/4-0.5)*0.024,y,z)) for i in range(5)])
    ob = mesh("DiagonalLeatherStrap",grid,[leather])
    thickness(ob,0.002)
    extra[ob.name] = ob
    # Transfer weights from the underlying fitted torso, clamp to torso bones.
    T.transfer_weights(body, ob)
    R.restrict(ob,["Hips","Spine","Chest","UpperChest","LeftShoulder","RightShoulder"])

    # Small rounded satchel with a shaped flap and visible brass fastening.
    p = torso_point(math.radians(335),top-0.035,0.047)
    # Closed rounded rectangular volume with a curved base and padded side gussets.
    grid = []
    for j in range(17):
        t = j/16
        z = p.z-0.057+0.112*t
        scale = 0.82+0.18*math.sin(math.pi*t)**0.5
        ring = []
        for i in range(65):
            a = math.tau*i/64
            x = math.copysign(abs(math.cos(a))**0.5,math.cos(a))*0.05*scale
            y = math.copysign(abs(math.sin(a))**0.5,math.sin(a))*0.024*scale
            ring.append(p+Vector((x,y,z-p.z)))
        grid.append(ring)
    pouch = mesh("LeatherPouch",grid,[leather])
    # Cap the padded pouch volume; UVs on these hidden closures are secondary.
    bm = bmesh.new()
    bm.from_mesh(pouch.data)
    bm.verts.ensure_lookup_table()
    bm.faces.new([bm.verts[i] for i in range(64)])
    bm.faces.new([bm.verts[16*65+i] for i in reversed(range(64))])
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(pouch.data)
    bm.free()
    extra[pouch.name] = pouch
    rigid[pouch.name] = "Hips"
    grid = []
    for j in range(13):
        t = j/12
        grid.append([p+Vector(((i/24-0.5)*0.1,-0.026-0.003*math.sin(math.pi*t),
                               0.057-0.063*t-0.008*math.sin(math.pi*i/24)*t)) for i in range(25)])
    flap = mesh("PouchFlap",grid,[materials["leather_dark"]])
    thickness(flap,0.002)
    extra[flap.name] = flap
    rigid[flap.name] = "Hips"
    stitch_pts = [p+Vector(((i/48-0.5)*0.092,-0.03,0.048-0.057-0.008*math.sin(math.pi*i/48))) for i in range(49)]
    ob = pipe("PouchFlapStitching",stitch_pts,0.0007,thread)
    extra[ob.name] = ob
    rigid[ob.name] = "Hips"
    ob = buckle("PouchBuckle",p+Vector((0,-0.038,0.009)),gold,(0.023,0.02))
    extra[ob.name] = ob
    rigid[ob.name] = "Hips"
    # Two restrained accessory swags. In stage 1 they share skirt skinning.
    for k, center in enumerate((math.radians(195),math.radians(345))):
        pts = []
        for i in range(33):
            u = i/32
            q = skirt_point(center+(u-0.5)*0.6,0.15+0.16*math.sin(math.pi*u),0.025)
            pts.append(q)
        ob = pipe(f"GoldSwag{k+1}",pts,0.0016,gold)
        extra[ob.name] = ob
        hanging.append(ob)
        for j in (8,16,24):
            q = pts[j]-Vector((0,0,0.014))
            ob = C.ellipsoid(f"Medallion{k}_{j}",q,(0.009,0.003,0.012),gold,segs=12,rings=8)
            extra[ob.name] = ob
            hanging.append(ob)
    # Central gold ornaments sit on the actual plum panels.
    for k in (0,2):
        angle = math.radians(270+90*k)
        position = skirt_point(angle,0.63,0.012)
        ob = ornament(f"PlumPanelOrnament{k}",position,0.031,0.043,gold,back=k==2)
        extra[ob.name] = ob
        hanging.append(ob)

    for ob in hanging:
        R.weight_hanging(ob,arm,ctr,top,hem,"skirt",16)
        T.limit_and_normalise(ob,4)
    for name,bone in rigid.items():
        R.rigid(extra[name],bone)
    for ob in extra.values():
        R.bind(ob,arm)
    # The imported skin shell contains disconnected torso islands. Build a
    # continuous measured bodice so the space under the cape is actually clothed.
    old_blouse = garments["Blouse"]
    old_blouse.hide_render = True
    old_blouse.name = "_OldBlouse"
    shell_bm = bmesh.new()
    shell_bm.from_mesh(body.shell().data)
    # Torso only: the rest-pose arms are horizontal, and rays at shoulder height
    # would otherwise give the bodice a flange that pokes through the cape.
    arm_groups = {g.index for g in body.shell().vertex_groups
                  if any(k in g.name for k in ("UpperArm","LowerArm","Hand","Thumb","Index","Middle","Ring","Little"))}
    dl = shell_bm.verts.layers.deform.active
    if dl is not None:
        kill = [f for f in shell_bm.faces
                if sum(sum(w for gi,w in v[dl].items() if gi in arm_groups) for v in f.verts)/len(f.verts) > 0.35]
        bmesh.ops.delete(shell_bm, geom=kill, context="FACES")
    skin_bvh = BVHTree.FromBMesh(shell_bm)
    shell_bm.free()
    bodice_grid = []
    for j in range(25):
        t = j/24
        z = top-0.035+(neck.z+0.008-(top-0.035))*t
        center = Vector((ctr.x,ctr.y,z))
        radii = []
        for i in range(128):
            a = math.tau*i/128
            direction = Vector((math.cos(a),math.sin(a),0))
            hit = skin_bvh.ray_cast(center+direction*0.2,-direction,0.2)
            radii.append((hit[0]-center).dot(direction)+0.005 if hit[0] is not None else 0.08)
        for iteration in range(4):
            radii = [(radii[(i-1)%128]+2*radii[i]+radii[(i+1)%128])/4 for i in range(128)]
        bodice_grid.append([center+Vector((math.cos(math.tau*i/128),math.sin(math.tau*i/128),0))*radii[i%128]
                            for i in range(129)])
    blouse = mesh("Blouse",bodice_grid,[cream])
    T.transfer_weights(body,blouse)
    R.restrict(blouse,["Hips","Spine","Chest","UpperChest","LeftShoulder","RightShoulder"])
    R.bind(blouse,arm)
    garments["Blouse"] = blouse
    omitted = ["Skirt","Petticoat","Clasp"]+[f"Buckle{k}" for k in range(4)]
    output = [ob for name,ob in garments.items() if name not in omitted] + list(extra.values())
    # Static thickness on existing fitted fabric before export, respecting weights.
    for name in ("Blouse","Capelet","Corset"):
        thickness(garments[name])
    # Reduce redundant fitted topology, leaving the panel/ruffle grids intact.
    for name in ("Tights","Boots"):
        ob = garments[name]
        T._select_only([ob])
        mod = ob.modifiers.new("Fitted mesh simplification","DECIMATE")
        mod.ratio = 0.55
        bpy.ops.object.modifier_move_to_index(modifier=mod.name,index=0)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # glTF must have normalized weights on every vertex, including solidified rims.
    unweighted = 0
    deform = [b for b in arm.data.bones if b.name in T.VROID_TO_HUMANOID.values()]
    for ob in output:
        for v in ob.data.vertices:
            if not any(g.weight>1e-5 for g in v.groups):
                bone = min(deform,key=lambda b:(b.head_local-v.co).length_squared)
                R._set(ob,v.index,{bone.name:1.0})
                unweighted += 1
        T.limit_and_normalise(ob,4)
        if not ob.data.uv_layers:
            uv = ob.data.uv_layers.new(name="UVMap")
            xs = [v.co.x for v in ob.data.vertices]
            zs = [v.co.z for v in ob.data.vertices]
            for loop in ob.data.loops:
                p = ob.data.vertices[loop.vertex_index].co
                uv.data[loop.index].uv = ((p.x-min(xs))/max(max(xs)-min(xs),1e-6),
                                          (p.z-min(zs))/max(max(zs)-min(zs),1e-6))
        for v in ob.data.vertices:
            assert 1<=len(v.groups)<=4,(ob.name,v.index,"invalid influence count")
            assert abs(sum(g.weight for g in v.groups)-1)<0.001,(ob.name,v.index,"weights not normalized")
            assert all(math.isfinite(c) for c in v.co),(ob.name,v.index,"nonfinite position")
    R.body_mask(body,[garments[n] for n in ("Blouse","Corset","Boots","Tights")]+
                [extra[s+"GatheredSleeve"] for s in ("Left","Right")],os.path.join(DEST,"bodymask.png"))
    for ob in body.meshes:
        ob.hide_render = True
    for ob in bpy.data.objects:
        if ob.name.startswith("_"):
            ob.hide_render = True
    C.export_glb(os.path.join(DEST,"outfit.glb"),[arm]+output,animations=False)
    report = {"stage":"geometry_and_materials", "body_source":os.path.relpath(B.BODY,ROOT),
              "simulation_enabled":False,"visual_acceptance":"pending_owner_review",
              "mesh_count":len(output),"repaired_unweighted_vertices":unweighted,
              "geometry_checks":"finite positions, UVs, 1-4 normalized skin influences per vertex",
              "vertices":sum(len(ob.data.vertices) for ob in output),
              "triangles":sum(len(p.vertices)-2 for ob in output for p in ob.data.polygons),
              "meshes":[{"name":ob.name,"vertices":len(ob.data.vertices)} for ob in output],
              "limitations":["Animation deformation and collision are milestone 2/3 acceptance gates.",
                              "No runtime equipment integration or retargeting to the playable legacy skeleton yet.",
                              "Hair/capelet interaction must be checked on the visible avatar."]}
    with open(os.path.join(DEST,"build_report.json"),"w",encoding="utf-8") as f:
        json.dump(report,f,indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,"freyja_reference.blend"))
    C.render_preview(os.path.join(ROOT,"art","previews","reference_outfit.png"),output,
                     views=((0,"front"),(90,"side"),(180,"back"),(35,"three_quarter")),
                     height=body.height*1.05,look_z=body.height*0.52,size=(2400,1100))
    print("MILESTONE1_EXPORTED",json.dumps(report))


if __name__ == "__main__":
    main()
