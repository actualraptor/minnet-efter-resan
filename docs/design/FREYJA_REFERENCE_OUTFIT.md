# Freyja reference outfit

## Scope and stage gates

The owner's outfit sheet is the visual target. The accompanying pasted brief is
background requirements; the owner's subsequent direction establishes three
milestones and supersedes any suggestion of implementing everything at once.

1. **Geometry and materials — current, review candidate.** Fitted, separately
   named meshes and portable materials. Review front, sides, back and close-ups
   with all secondary motion disabled. Visual resemblance is an acceptance gate;
   a successful export does not establish finished art quality.
2. **Animation and attachment — pending.** Validate the actual walk/run, stops,
   90/180-degree turns, jump/land, staff hold, summon and cast; check hands and
   raised arms. Establish the animation/skeleton mapping before changing the
   playable character. Do not use the synthetic outfit debug swings as evidence
   that actual game animations work.
3. **Secondary motion — pending.** Add skirt motion first, evaluate it, then
   selected cuff and cape edges. Never enable every loose section simultaneously.

| Section | Intended motion | Construction constraint |
|---|---|---|
| Capelet | Low; skeletal body, restrained hem | Keep the shoulder silhouette |
| Sleeves | Medium at cuffs | Shoulder/elbow skinning carries the main sleeve |
| Sage/plum skirt panels | High at lower ends | Anchor upper panels to hips; coordinate overlapping layers |
| Cream lining/ruffles | Controlled with skirt | Share motion where layers touch |
| Corset/belts | Skeletal only | No cloth flutter |
| Strap/pouch/charms | Limited, optional | Constrain travel and prevent skirt penetration |

Hair against the capelet and skirt against the legs are the first collision
priorities. Separate panel meshes do not imply a separate independent solver for
every panel. Closely layered cloth must have coordinated motion.

## Inspection findings (2026-10-10)

- Available runtimes: Blender 4.5.14 LTS and Godot 4.7.2 stable. Godot review
  captures use Forward+ on the RTX 5070 Ti. The project selects Jolt physics.
- `scenes/player.tscn` still references `freyja.glb`. The playable skeleton uses
  names such as `head`, `spine`, `thigh.L`, and `upper_arm.L`.
- The supplied VRoid source is `art/source/vroid/freyja.glb`/`freyja.vrm`;
  the importer produces humanoid names such as `Hips`, `UpperChest`, and
  `LeftUpperArm`. **These skeletons are not interchangeable by name.**
- Existing locomotion uses `LocomotionAnimator` and an `AnimationPlayer`, not a
  general equipment AnimationTree. `StaffSummon`, `HandPoser`, `FootGrounder`,
  face controls and look-at modifiers depend on the playable rig.
- `Outfit.dress` binds separate garment skins to a humanoid skeleton, hides
  covered skin and creates spring chains. It is not yet an equip/unequip/save
  system. Two optional arguments now permit disabling simulation and keeping
  authored PBR materials for geometry review; existing calls retain defaults.
- Both `CharacterPhysics` and `Outfit` already use `SpringBoneSimulator3D`.
  Body proxies are available; they do not establish full hair/cloth or
  cloth/cloth surface collision.

## Milestone-1 assets

- Builder: `art/blender/outfit/build_reference_outfit.py`.
- Export: `game/assets/models/characters/freyja_reference_outfit/outfit.glb`.
- UV body mask: adjacent `bodymask.png`.
- Inventory/counts/validation: adjacent `build_report.json`.
- Editable source, packed image materials:
  `art/source/outfits/freyja_reference/freyja_reference.blend`.
  This is local and ignored under the project's existing `art/source/` rule.
  The tracked builder reproduces it from the owner-provided VRoid source.
- Static review scene: `game/tests/outfit_geometry_review.tscn`.
- Runtime captures: `art/previews/reference_runtime/geometry_*.png` and
  `art/previews/reference_garments/geometry_*.png` (local, ignored).
- Owner's sheet: `art/reference/freyja_outfit/outfit_sheet.png` (local, ignored).

The candidate has four pointed sage panels, four plum gores, a cream lining and
three separately modelled ruffles, gathered sleeves, collar/cuffs, a structured
corset, three belts with open brass buckles, diagonal strap, gusseted pouch and
flap, medallions and swags. The refinement adds leather cuff bands, corset boning
seams, pouch stitching, front/back brooches and pointed plum-panel ornaments.
Gold trim occupies actual mesh regions; botanical embroidery, fabric weave,
leather grain and tangent-space cloth normals are packed image textures,
not Blender-only procedural nodes. Normal-map references were checked in the
exported GLB's material definitions.

The outfit uses existing humanoid and garment helper bones. Helper bones remain
at their skeletal poses during this review. The scene also disables imported
hair modifiers. No runtime cloth solver or new secondary-motion implementation
is added in milestone 1.

The candidate's main cape is bound to `UpperChest` to retain its structured
shape. The previous shoulder-following version produced sleeve intersections
in the A-pose; do not re-enable it without deformation review. Raised-arm
correctives and restrained hem motion remain later-stage work.

## Geometry refinement (2026-10-10)

- Widened and raised the cape shoulder envelope and reduced upper sleeve volume
  to resolve the rear sleeve intersections visible in the first static pass.
- Lengthened the skirt envelope by 12%, deepened the panel points and gave the
  three cream layers stronger gathered folds and uneven hems.
- Added longitudinal and diagonal sleeve creases; kept the upper sleeves and
  elbows skinned, with simulation disabled.
- Added repeated botanical cape embroidery, finer panel borders and curling
  leaf motifs, portable fabric normals and deterministic leather grain.
- Added shaped star ornaments, cuff leather, corset and pouch seams. Moved the
  lowest belt above the skirt waistband after close-up inspection exposed an
  intersection. Trimmed the corset's hidden lower lip to the waistband after
  a second close-up showed it penetrating the front skirt surface.
- Simplified the fitted tights/boots while preserving the cloth panel grids.
- Expanded the Godot review to include front/back garment close-ups in addition
  to the four full-body views.

The latest reviewed static views no longer show the earlier rear shoulder
intersections. This is visual evidence for that one A-pose, not a numerical
collision guarantee or validation of animated deformation.

## Silhouette pass (2026-10-10, Claude)

Compared against the sheet before editing; the largest gaps were silhouette,
not ornament: a short boxy skirt, a flat disc capelet and a solid white ruffle band.

- Skirt: own envelope below the knee (`knee - 0.085`), continuing the measured
  base envelope with a bell flare; longer, gently pointed sage panels (0.99 at
  the tip, 0.82 at the edges) over slightly longer plum gores.
- Ruffles: three gathered tiers sewn on under the panels; the outer tier is the
  shortest so each lower tier shows below it. They stay inside the panels and
  only flare below the panel hems (no tier pokes through a panel).
- Sleeves: bishop/balloon profile peaking over the forearm.
- Capelet: draped (`tailor.drop_cloth`) over the shoulders and over copies of the
  sleeves, fitted blouse and skin posed like the review (UpperArm 0.85 rad down,
  linear-blend-skinned by each vertex's arm weight). The cape is rigid on
  UpperChest, so this is the shape it has whenever the arms hang. Sides reach
  over the upper arm; small front/back points.
- Corset: two belts (lower edge, upper middle) instead of three stacked rings.
- Fixes found by checks, not screenshots: `tailor.push_out` searched from the
  wrong radius with short reaches (sleeves pierced the cape); `bvh_below` cut
  every face above the neck height, which also removed sleeve puffs (now the
  head/neck are excluded by bone weight); the bodice was ray-cast against the
  T-pose arms (now arm-weighted skin is ignored).
- Measured: 0 posed sleeve vertices outside the capelet (was 73/94). The bodice
  still rises just above the cape neckline at the front, hidden by the collar.

Detail pass: the capelet has a front V (smaller back V) with a gold spire,
scrolls and leaves painted at the centre front and back; the main belt has a
double-frame buckle on a leather keeper. Still below the sheet: ruffle hems read as a uniform wave, embroidery is
simpler, and raised-arm poses are untested (milestone 2).

## Deep detail pass (2026-10-10, Claude)

- Embroidery is painted with a small vector painter (`Ink`) in aspect-corrected
  units, so strokes stay round on stretched UVs: a fleur-de-lis on every sage
  panel point with leafy vines along both hems and curls above; stars and a
  small fleur running down every plum gore; a vine-and-leaf band around the
  capelet hem with curled sprigs, plus the centre spire/scroll filigree.
- Ruffles: three tiers gathered together (same fold phase, so they nest instead
  of interleaving), 480 segments, shallow rounded folds, and an eyelet-lace band
  (two staggered eyelet rows, scalloped edge) tiled 12x around the hem.
- Sleeves: gathered into the cuff band (the puff narrows into it, then a small
  frill); pleats radiate from the shoulder seam and the cuff. The shoulder seam
  is narrower and lower so no puff rises above the capelet at the back. Each
  cuff band sits on the gathered sleeve and has a small brass buckle.
- Corset: front lacing, eight pairs of brass eyelets with crossed dark laces.
- Neck: the collar now starts under the capelet neckline and the bodice stops
  below it (no white band between collar and cape).
- Charm cluster (sheet: CHARMS): ring on the lower belt at the front right hip,
  three chains hanging plumb, a coin with a star, a gold clover and a green leaf
  with a gold vein, resting outside the sage panels. Replaces the side swags.
- Capelet neckline edge smoothed.

Counts: 86 meshes, ~206k triangles (finer ruffles); performance reduction is a
later gate. Clipping check: 0 posed sleeve vertices outside the capelet; smoke
test 42/42.

## Rebuild and inspect

```powershell
& '<blender.exe>' -b --factory-startup --python art/blender/outfit/build_reference_outfit.py -- '<repo>'
& '<godot_console.exe>' --headless --path game --editor --import --quit
& '<godot_console.exe>' --path game res://tests/outfit_geometry_review.tscn -- --out='<absolute captures>'
& '<godot_console.exe>' --path game res://tests/outfit_geometry_review.tscn -- --garments-only --out='<absolute captures>'
```

The builder checks finite vertex positions, UV presence and one to four normalized
skin influences per vertex before exporting. Inspect the build log as well as its
exit code: Blender can exit successfully after a Python exception.

## Acceptance limits

This is an authored **review candidate**, not accepted premium-quality artwork.
The cape's shoulder drape, sleeve folds, corset tailoring, ruffle silhouette and
ornament density need comparison to the sheet. Texture embroidery is simpler
than the sheet's filigree; leather currently lacks bespoke stitched normal maps.
The source avatar's hair appearance is preserved, and its hair hides part of the
cape in dressed views; garments-only captures make the underlying geometry visible.
Hair/cape intersections are not solved by this static review.

Validation: Blender geometry checks and Godot import passed; four dressed and
four unobstructed garment captures plus close-ups were generated on Forward+.
The prior gameplay smoke test passed all 42 checks; this geometry-only refinement
did not change the playable character or shared gameplay scripts. That test
also reported ObjectDB/resource
leaks on shutdown; those remain outside this clothing geometry scope.

This dense first geometry pass is not performance-approved. Inspect counts in
the build report and reduce hidden lining/fitted topology before final gameplay
integration. No FPS or deformation quality claim is made from static renders.
Auto-generated import LODs are not evidence of correct animated LODs.

The current export has 53 meshes and approximately 150,000 triangles before
import optimization. The broadly rounded cape, procedural sleeve/ruffle folds
and repeated embroidery are still materially less detailed than the reference.
Milestone 1 is **not visually accepted**; further modelling is required before
proceeding to movement or secondary-motion acceptance.

The review retains the authored PBR materials. The existing gameplay toon
converter does not carry through these normal maps or the metallic/roughness
response; decide how to preserve their appearance during the integration gate.

Animation retargeting, equip/unequip restoration, saved equipment state, teleport
resets, simulation parameters/limits, collision debug overlays, distance-based
simulation and movement captures belong to the later gates and remain pending.
If procedural iteration cannot achieve the target drape and detailing, sculpt and
retopologize the supplied editable Blender source before adding physics.
