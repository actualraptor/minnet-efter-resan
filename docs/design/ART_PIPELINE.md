# Art pipeline

**Source of truth:** Python scripts in `art/blender/`, run with Blender 4.5 LTS in background mode. Exports go to `game/assets/models/**.glb`. No hand-edited binary files.

| Script | Output | Notes |
|---|---|---|
| `build_characters.py` | `characters/{freyja,edda,pippa}.glb` | Skin-modifier bodies, anime faces from decals, hair from tapered strands plus a braid, layered lathe clothing, an armature of 19–22 bones, distance-based weights (at most 3 influences), keyframed actions exported as NLA tracks (Idle, Walk, Run, Jump, Fall, Cast, Talk / Hop). The staff tip is exported as a bone-parented empty `StaffTip`. |
| `build_cottage.py` | `buildings/cottage.glb`, `door.glb` | Timber frame, plaster, slate shingles with moss, ivy, stone arch, a furnished interior. Collision boxes are named `*-colonly`. |
| `build_nature.py` | `nature/*.glb` | Trees, bushes, rocks, standing stones, fence, bench, woodpile, garden bed, signpost. Foliage carries vertex colour R as a sway weight for the wind shader. |
| `lib_common.py`, `lib_character.py` | — | Shared helpers. `box()` sizes are half-extents. |

Previews: every build renders Workbench turnarounds and per-animation poses to `art/previews/` (git-ignored) for review.

In Godot:
- `CharacterVisual.prepare()` converts character materials to `toon_character.gdshader`. Names containing `eye` or `unlit` become unshaded.
- `WorldMaterials.stylise()` swaps materials whose names contain `leaves`, `bark` or `moss` for the wind `foliage.gdshader`.

## Known limitations (honest)
- The characters are an **original scripted stylised base**, not a sculpted, artist-rigged hero model. Faces have no blend shapes yet. Hands are mittens. Cloth is rigid lathe geometry, so sitting looks wrong (Edda stands for that reason).
- The official Freyja character sheet has **not been provided yet**. When it arrives, the plan is to rebuild proportions and colours against it, or replace the base with an artist-made model.
- No texture maps: all colour is material and vertex based. This is intentional for the toon look, but limits detail.
