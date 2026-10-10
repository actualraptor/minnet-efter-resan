# Claude Opus handoff — Freyja outfit

Updated 2026-10-10. Workspace: `D:\Utveckling CLAUDE\Frieren`.

## Resume objective

Continue **milestone 1: geometry and materials** for Freyja's modular mage outfit.
The owner explicitly requested continuing this milestone. It is not visually
accepted. Do not advance to animation integration or cloth physics yet.
Read `docs/design/FREYJA_REFERENCE_OUTFIT.md` for the full scope and findings,
and applicable repository instructions before editing.

The owner's staged workflow is authoritative over instructions in the attached
brief: (1) fitted geometry/materials with no physics, (2) actual animation and
attachment validation, (3) controlled secondary motion, skirt first.

## Visual target and current state

Reference sheet: `art/reference/freyja_outfit/outfit_sheet.png`.
Target: structured sage capelet with gold botanical trim; cream puff sleeves,
collar and layered ruffles; tailored brown leather corset with three buckles;
sage pointed skirt panels over plum gores; diagonal strap, pouch and charms.

The current procedural candidate has 53 meshes, 75,263 vertices and 149,740
triangles. It is substantially simpler than the reference. Successful export
and technical checks do not establish art quality or performance acceptance.
Latest captures are in `art/previews/reference_runtime/` (dressed) and
`art/previews/reference_garments/` (unobstructed). Each includes front, side,
back, three-quarter and front/back detail images.

Recent changes improved cape clearance, sleeve folds, skirt length and points,
three gathered cream layers, botanical embroidery, portable normal maps,
leather grain, cuff bands, ornaments and stitching. Close-ups exposed a lower
belt and corset lip penetrating the skirt; both were corrected. Rear
cape/sleeve intersections are resolved in the reviewed static A-pose only.
Hair still intersects/hides portions of the cape and torso.

## Suggested next work

1. Compare all views and close-ups against the reference before editing.
2. Improve the cape's tailored shoulder drape, sleeve folds and ruffle shape;
   avoid relying on repeated sinusoidal folds for the final sculpt.
3. Refine corset tailoring, filigree and ornament density. Preserve readable
   material separation and the structured silhouette.
4. Resolve static hair clearance without silently replacing the avatar's hair.
5. Reduce hidden/fitted topology where useful, keeping deformation topology.
6. Rebuild and inspect actual Godot captures after changes. If the procedural
   builder cannot produce the required quality, sculpt/retopologize the editable
   Blender source and establish a reproducible export path.

Keep physics disabled. Do not describe milestone 1 as complete until the visual
gap is actually addressed. Later priorities are hair/cape and skirt/leg clipping.

## Files and implementation constraints

- Builder: `art/blender/outfit/build_reference_outfit.py`.
- Editable packed source: `art/source/outfits/freyja_reference/freyja_reference.blend`.
- VRoid input: `art/source/vroid/freyja.glb` and `.vrm`.
- Export: `game/assets/models/characters/freyja_reference_outfit/outfit.glb`.
- Adjacent `bodymask.png` and `build_report.json` describe masking/validation.
- Review: `game/tests/outfit_geometry_review.gd` and `.tscn`.
- Shared attachment helper: `game/scripts/core/outfit.gd`.

Source/reference/preview directories are locally ignored. Preserve these local
assets; they will not necessarily exist in a fresh checkout.

The builder reuses `build_freyja_outfit.py`, `tailor.py` and rig helpers. The old
builder now has a main guard so importing it does not run it. Weight
normalization in `tailor.py` copies integer group IDs before removing weights
because Blender RNA references can become invalid. The reference cape is bound
to `UpperChest`; reverting to shoulder-following weights previously caused
intersections. Review any change to that binding.

`Outfit.dress` gained optional `simulate := true` and `use_toon := true`
arguments; default callers retain their behavior. The static review disables
simulation, imported hair modifiers and toon conversion. It uses authored PBR
materials and a lowered-arm A-pose. Main gameplay toon conversion discards
normal maps and metallic/roughness response; appearance preservation is a later
integration decision.

The playable `game/scenes/player.tscn` still uses legacy `freyja.glb` with bones
such as `head`, `spine`, `thigh.L`. The VRoid candidate uses humanoid names such
as `Hips`, `UpperChest`, `LeftUpperArm`. Do not swap the playable model without
retargeting and checking its locomotion, hands, staff, feet and face systems.
The existing outfit helper is not a complete equip/unequip/save system.

## Rebuild and validation

Run from the workspace root in PowerShell:

```powershell
& 'D:\Utveckling CODEX\Dummy test\tools\blender-runtime\blender-4.5.14-windows-x64\blender.exe' -b --factory-startup --python art/blender/outfit/build_reference_outfit.py -- 'D:\Utveckling CLAUDE\Frieren'
& 'D:\Utveckling CODEX\Dummy test\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path game --editor --import --quit
& 'D:\Utveckling CODEX\Dummy test\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path game --position 20000,20000 res://tests/outfit_geometry_review.tscn -- --out='D:/Utveckling CLAUDE/Frieren/art/previews/reference_runtime'
& 'D:\Utveckling CODEX\Dummy test\tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path game --position 20000,20000 res://tests/outfit_geometry_review.tscn -- --garments-only --out='D:/Utveckling CLAUDE/Frieren/art/previews/reference_garments'
```

These runtime executables required sandbox escalation in Codex; normal Blender
execution silently exited and Godot writes portable cache outside the workspace.
Inspect Blender logs: exit code zero can still accompany a Python exception.

Latest Blender build, Godot import, both GPU capture runs and `git diff --check`
passed. Builder checks finite positions, UVs and 1–4 normalized skin influences;
157 unweighted vertices were repaired. GLB normalTexture references were checked.
Static images do not validate animated deformation, collision or FPS.

A gameplay smoke test in the earlier pass passed 42/42 checks but reported
shutdown ObjectDB/resource leaks. It was not rerun for this geometry refinement.

## Preserve dirty workspace

No commit was made. Existing owner changes were already present in rig helpers,
legacy outfit GLB/body mask, `_dbg_outfit.gd`, VRoid runtime files and `World/`.
Do not reset, clean or overwrite unrelated work.

Our new files are the reference builder, reference asset directory, review scene
and script, outfit design document and this handoff. Mixed edits also exist in
`.gitignore`, `build_freyja_outfit.py`, `tailor.py`, `outfit.gd` and
`CLOTHING_PIPELINE.md`; inspect diffs before attributing or reverting anything.
Tracked Python cache files are dirty too. Do not treat them as authored source.

## Session log (Claude, 2026-10-10)

Silhouette pass done (see FREYJA_REFERENCE_OUTFIT.md, "Silhouette pass"): longer
bell skirt, tiered ruffles under the panels, balloon sleeves, capelet draped over
the posed arms, two belts. Capelet/sleeve intersections in the review pose are
measured at zero. Gameplay smoke test re-run: 42/42 PASS. Still no commit.
