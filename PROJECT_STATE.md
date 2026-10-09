# Project State

_Last updated: 2026-10-09_

## Current milestone
**001: A Cottage, a Mage, and a Memory.** Status: **Review / testing.** The systems are implemented and pass the automated smoke test. It still needs a human playtest, feel tuning and an art pass against the official character sheet.

## Implemented (verified in the running game)
| Feature | State | Verified by |
|---|---|---|
| Meadow terrain (220 m generated, ~108 m playable diameter), heightmap collision, soft play boundary | Done | smoke test, screenshots |
| Wind grass (chunked MultiMesh, visibility ranges), wildflower drifts, tree ring, mountains, sky, butterflies, pollen, chimney smoke | Done | screenshots |
| Cottage exterior and interior with collision, working door, indoor volume (camera, footsteps, ambience, spell rule) | Done | smoke test (indoor detection), screenshots |
| Freyja: rigged GLB with 7 animations (Idle/Walk/Run/Jump/Fall/Cast/Talk), toon shading, staff tip attachment | Done | smoke test, Blender pose previews, screenshots |
| Edda and Pippa: rigged GLBs with idle and talk (Pippa also has Hop) | Done | screenshots |
| Third-person controller and spring-arm camera | Done | screenshots. **Not yet hand-playtested for feel.** |
| Spell framework and Field of Flowers (gather, wave, bloom, persistence, caps, indoor refusal) | Done | smoke test: 902 flowers on first cast, 2,472 after 5 casts within caps, none inside the cottage |
| Dialogue runner, director, UI (both speakers, choices, conditions, exit, voice and l10n hooks) | Done | smoke test transcripts |
| Quest *The Garden Behind the Cottage* and memory event | Done | smoke test |
| Save/load (versioned JSON, flowers re-planted deterministically) | Done | smoke test: identical flower count after reload |
| HUD, pause menu, journal | Done | screenshots |
| Audio: ambience, SFX, music (original) | Done | files generated; levels checked with ffmpeg. **Not yet judged by ear in play.** |

## Partially complete / known issues
- **Characters (v2, 2026-10-09):** rebuilt toward the owner's vision frames (`art/reference/`, local only). Freyja has layered skirt panels, a corset, puffed sleeves, long braided hair with a flower and ribbon, and a gem-loop staff. Edda and Pippa got matching redesigns. Still scripted geometry: static decal faces, mitten hands, rigid cloth.
- **Indoor camera:** in tight spots Freyja now fades out as the camera closes in. It still needs a feel check by hand (#10).
- **Edda's shawl** reads as a large plum shape from the front.
- **The interior** has improved but is still warmer and plainer than the reference art.
- The meadow wave glow is tuned for this lighting and may need retuning if the time of day changes.
- No options menu (sensitivity, volume, key rebinding) yet.
- The tree ring is deterministic random placement, not fully hand-composed.

## GitHub (verified 2026-10-09)
- Repository (public): https://github.com/actualraptor/minnet-efter-resan
- GitHub Pages (Actions deploy, verified HTTP 200): https://actualraptor.github.io/minnet-efter-resan/ and `/roadmap.html`
- CI `Godot checks` on ubuntu-24.04 with Godot 4.7.2: import plus smoke test **PASS** on the first push.
- Board: Projects v2 https://github.com/users/actualraptor/projects/1 (public). The Status field is Backlog / Ready / In Progress / Review-Testing / Done / Blocked, with 20 issues placed. **Limitation:** the API cannot create a *Board-layout view*, so the project opens in table layout. Switch it once via *View → Layout → Board* in the GitHub UI.
- 8 milestones (001–008), labels for type/priority/area/status, and 20 issues (8 done and closed with verification notes; #9 playtest in Review/Testing; #10 and #12 Ready; #11 Blocked on the character sheet; #13 and #14–#20 epics in Backlog). Seeded by `tools/github/seed_board.js` and `setup_project.js`.
- Status sync: `site/data/roadmap.json` is the single source for the site, and the board is updated alongside it (manual for now).

## Architecture
See [docs/design/ARCHITECTURE.md](docs/design/ARCHITECTURE.md). In short: `GameState` (the one narrative singleton) plus `Audio` autoloads; the scene-node systems are terrain, grass, flowers, world builder, player, caster, dialogue director and UI.

## Assets and licences
See [docs/ASSETS.md](docs/ASSETS.md). All models and audio are generated from scripts in this repo. Fonts are OFL. The music was rendered with the GeneralUser GS soundfont.

## Tests actually run (2026-10-09, Windows 11, RTX 5070 Ti, Godot 4.7.2)
- `godot --headless --path game --import`: no script errors.
- `godot --headless --path game -- --smoke-test`: **PASS, 34/34 checks.**
- `godot --path game -- --tour`: 9 runtime screenshots captured at 1080p and inspected (used on the site, labelled in-game).
- GitHub Actions on Linux: import plus smoke test PASS.
- Blender 4.5.14 builds of all assets: success. Pose previews inspected.
- **Not done:** human playtest with keyboard, mouse or gamepad. Performance profiling (no FPS numbers recorded). 

## Skills and tools
- Installed project skills: 28 Godot skills from `jame581/GodotPrompter` (MIT, skill text only, no hooks) plus the local `creature-rigging` skill. See `.claude/skills/SKILLS_PROVENANCE.md` (local only, git-ignored).
- No suitable Blender skill was found: the available ones require blender-mcp with a GUI session. Headless `bpy` is used instead.

## Next priorities
0. World vision pass: path dressing (walls, lantern posts, cobbles; props already built), castle vista, spell ribbons and petals, ornate HUD, optional pixel-art render mode.
1. Human playtest: movement feel, camera indoors, dialogue pacing, audio mix.
2. Character pass against the official Freyja sheet once provided (proportions, face, hair volume).
3. Interior dressing and lighting toward the reference (light shafts, clutter density, Edda's outfit).
4. Options menu (mouse sensitivity, volumes, rebinding) and accessibility (text speed, size).
5. Milestone 002 planning: the village to the south and the next small quests.

## Change log (short)
- 2026-10-09: Vision pass, characters: Freyja v2, Edda v2, Pippa v2. Golden-hour light, volumetric haze, cumulus sky, leaf-card trees, denser wildflowers.
- 2026-10-09: Milestone 001 slice built: world, cottage, characters, spell, dialogue, quest, memory, audio, tests, docs, site.
