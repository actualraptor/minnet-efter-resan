# Project State

_Last updated: 2026-10-12 (reconciled against git history, the repo and a fresh headless run; see "Verified today")_

## Current milestone
**Demo 1: The Cottage.** A playable, shippable slice: the cottage and meadow, three small quests, a closing beat and a Windows build. Status: **Planning** (scope and plan agreed with the owner, quests 2 and 3 not yet picked). Finish line and plan: [docs/design/DEMO_1.md](docs/design/DEMO_1.md).

Milestone 001 (*A Cottage, a Mage, and a Memory*) is built and its systems pass the smoke test, but its human playtest (#9) never happened; Demo 1's playtest replaces it.

## Implemented (in the repository, with how each is checked)
| Feature | State | Checked by |
|---|---|---|
| Meadow terrain, grass, wildflower drifts, tree ring, mountains, sky, butterflies, pollen, chimney smoke | Done | smoke test (terrain, grass, props), screenshots |
| Cottage exterior and interior, working door, indoor volume (camera, footsteps, ambience, spell rule) | Done | smoke test (door, indoor detection, cast refused) |
| **Freyja is the VRoid model** (`freyja_vroid_game.glb`, reference outfit, spring-bone hair and cloth); Quaternius UAL (CC0) idle/walk/jog/jump/talk/cast retargeted by BoneMap; CMU mocap kept for jump/land | Done | smoke test (animations, spring chains, face rig, look-at), deformation gate, physics audit |
| Staff performance rig: summoned from thin air, two-handed IK grip, authored staff poses per spell | Done | smoke test (summon), `--dbg --staff` audits |
| Flight with stamina, hover legs, casting from the air | Done | `--dbg --fly`; **not in the smoke test** |
| Spell framework and **Field of Flowers** (levitating cast, circle, wave, bloom, caps, indoor refusal) | Done | smoke test (870 flowers first cast, 2,295 after 5 casts, none indoors) |
| **Solstråk / Mörkstråk** (white and black Zoltraak-style beams, seals, charged, burst, volley), **hex barrier**, focus-aim controls | Done (a toy, not an enemy system) | `--dbg --zoltraak` ten scenarios; **not in the smoke test** |
| Practice range in the meadow: straw dummies and two shooters (black beam, white volley) that hit the player (toast, no health) | Done | `--dbg --range`; **scope decision pending for the demo** |
| Dialogue runner, director, UI (choices, conditions, actions, interpolation) | Done | smoke test transcripts |
| Quest *The Garden Behind the Cottage* and memory event `memory_cottage_garden_restored` | Done | smoke test |
| Save/load (versioned JSON, flowers re-planted deterministically) | Done | smoke test (2,295 vs 2,295 after reload) |
| HUD, pause menu, journal (errands and memories), quit | Done | screenshots |
| Audio: ambience, SFX, music (synthesised and composed in-repo) | Done | files generated; **never judged by ear in play** |
| Linköping slice (`scenes/linkoping.tscn`, F10 from the meadow): procedural cathedral, square, bridge, houses | Prototype, **out of scope for the demo** | `town_shots` / `town_walk`; not in CI |
| Teaser film tooling (`scripts/dev/teaser.gd`, `build/teaser/render.sh`, `tools/audio/compose_teaser.js`) | Done, dev only | rendered clips |
| Design pool of useless spells (`docs/design/USELESS_SPELLS.md`, 86 entries) | Proposal doc | n/a |

## Work in progress (uncommitted, not wired in)
A prototype of a two-step stone errand chain (grave flowers → Fläckfri cleaning spell → mossed statue): `scripts/world/inspectable.gd`, `scripts/world/stone_quests.gd`, `shaders/grime_stone.gdshader`, `scripts/spells/stain_free_effect.gd`, `data/spells/stain_free.tres`. It is one candidate for quests 2 and 3 and is not connected to `main.gd` until the owner picks (see DEMO_1.md).

## Known issues and gaps
- **No human playtest has ever been run** (movement feel, camera indoors #10, dialogue pacing, audio mix).
- **No performance numbers recorded** (finish line needs 60 fps at 1080p on the RTX 5070 Ti).
- **No options menu** (volumes, mouse sensitivity) and no credits screen (#13).
- `PauseMenu` subtitle still reads "Prototype 001 — in development"; F10 travels to Linköping (dev shortcut) and must be removed from a demo build.
- Edda and Pippa are still the v2 scripted geometry (decal faces, mitten hands); unchanged since 2026-10-10.
- The old CC-BY Sketchfab-based `freyja.glb` and its textures are still tracked and **no longer referenced by any scene**, but the export preset uses `export_filter="all_resources"`, so it would ship and need attribution unless excluded or deleted. The raw `freyja_vroid.vrm` (18 MB) and `World/` are untracked local files; neither is referenced at runtime.
- The export preset points `custom_template/release` at `D:/Utveckling CODEX/...`, a path that exists only on this machine.
- CI runs the smoke test only; the flight, Zoltraak, and barrier suites are manual `--dbg` scripts.

## Verified today (2026-10-12, Windows 11, Godot 4.7.2)
- `godot --headless --path game --import`: 0 script or parse errors.
- `godot --headless --path game -- --smoke-test`: **PASS, 42/42 checks** on the committed tree (log kept outside the repo).
- Not run today: CI on GitHub, GPU tours, any export.

## GitHub (verified 2026-10-12)
- Repository (public): https://github.com/actualraptor/minnet-efter-resan; Pages: https://actualraptor.github.io/minnet-efter-resan/ and `/roadmap.html`.
- CI `Godot checks` (ubuntu-24.04, Godot 4.7.2): JSON validation, import, smoke test.
- Board: Projects v2 https://github.com/users/actualraptor/projects/1. 20 issues from milestone 001/002–008 seeding (#1–#8 closed, #9 review/testing, #10–#12 ready, #13 backlog, #14–#20 epics). Demo 1 gets its own milestone and epic. The API cannot create a Board-layout view, so switch the layout once in the UI.
- `site/data/roadmap.json` is the single source for the site; the board is updated alongside it by hand.

## Architecture
See [docs/design/ARCHITECTURE.md](docs/design/ARCHITECTURE.md): `GameState` (the one narrative singleton) plus `Audio` autoloads; scene-node systems for terrain, grass, flowers, world builder, player, caster, dialogue director and UI.

## Assets and licences
See [docs/ASSETS.md](docs/ASSETS.md). Shipped third-party: Quaternius UAL and monsters (CC0), godot-vrm and MToon (MIT), Nunito and Cormorant Garamond (OFL), GeneralUser GS (render-time only), CMU mocap (jump/land). The VRoid-made Freyja model is the owner's own work. CC-BY Sketchfab base: see the known issue above.

## Next
1. Owner picks quests 2 and 3, the ending beat and the title card (DEMO_1.md).
2. Build the plan in DEMO_1.md in order, one commit per task.

## Change log (short)
- 2026-10-12: State reconciled; Demo 1 milestone and plan added.
- 2026-10-11: Solid beams, combat camera, practice range with monster-bodied shooters, teaser v1-v3, useless-spell design list.
- 2026-10-10 to 2026-10-11: VRoid Freyja (reference outfit, UAL retarget, staff rig, flight, Zoltraak/barrier overhaul, Linköping slice).
- 2026-10-09: Milestone 001 slice built: world, cottage, characters, spell, dialogue, quest, memory, audio, tests, docs, site.
