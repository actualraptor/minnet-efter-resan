# Clothing pipeline (Freyja and future characters)

How game-ready, physics-driven clothing is built for Minnet efter resan.
Written 2026-10-10, when Freyja moved to a VRoid body (`art/source/vroid/freyja.vrm`)
and her clothing became a separate, modular outfit.

## Principles (why it is built this way)

1. **Modular garments on a shared skeleton.** Clothing is its own asset
   (`freyja_outfit.glb`) skinned to Godot's standard humanoid bone names
   (`Hips`, `Spine`, `Chest`, `UpperChest`, `LeftUpperLeg`, ...). That is what the
   VRM importer produces, so at runtime the garment meshes simply re-target the
   character's `Skeleton3D` by bone name. The body can be swapped, re-proportioned
   or re-exported from VRoid without re-authoring the clothes.
2. **Tailored to a measured body, not hand-placed.** A "tailor" step measures the
   body (exact outer surface by ray casts, joint positions from the skeleton) and
   generates each garment at a fixed clearance from the layer under it. Changing
   the body means re-running the tailor, not nudging vertices per screenshot.
3. **Explicit layers with fixed clearances.** Every garment has a layer index and
   sits a set distance outside the one below it, measured against that layer, not
   against the skin:
   | Layer | Garments | Clearance to layer below |
   |---|---|---|
   | 0 | skin | |
   | 1 | tights, boots (lower) | 1.5 mm / fitted |
   | 2 | blouse (body + sleeves) | 4 mm, sleeves puffed |
   | 3 | corset, skirt waistband | 8 mm |
   | 4 | skirt, petticoat | free-hanging A-line |
   | 5 | capelet | free-hanging bell over shoulders |
4. **Hide what is covered.** Body faces fully covered by an opaque garment are
   masked (removed in the body copy the game renders), so skin can never poke
   through tight clothing.
5. **Three kinds of motion.**
   - *Fitted* garments (tights, blouse body, boots, corset) follow the body:
     weights transferred from the body and smoothed; rigid pieces (corset, belt,
     cuffs) are limited to the bones they ride on.
   - *Hanging* garments (skirt, petticoat, capelet hem) are driven by spring-bone
     chains (`SpringBoneSimulator3D`): a ring of short chains, top rows weighted to
     the hips/chest, blending down to the chains.
   - *Props* (pouch, brooch, buckles) are rigid on one bone.
6. **Layers that touch share their motion.** The petticoat uses exactly the same
   chain bones and the same weight function as the skirt, only inset, so the two
   can never cross. Detail like panels and trims is texture or material regions
   on the same mesh, not separate floating geometry.
7. **Shapes that physics can handle.** The skirt is an A-line that hangs clear of
   the legs at rest (anime silhouette, and the legs rarely reach it). Colliders
   (thigh/shin capsules, hip sphere) only have to catch strides and turns.
   Real soft-body cloth (`SoftBody3D`) is not used: no stable layered collision.
8. **Gate on a repeatable test, not screenshots.** Every build runs the layer-pair
   clipping test (`art/blender/freyja_deform_test.py` style) across all clips, and
   the spring setup is reviewed in motion in-game.

## Files

- `art/blender/outfit/tailor.py`: body measurement and garment surface helpers.
- `art/blender/outfit/build_freyja_outfit.py`: Freyja's base outfit -> `game/assets/models/characters/freyja_outfit.glb`.
- `game/scripts/core/outfit.gd`: attaches an outfit to a character skeleton and sets up its spring chains and colliders.
