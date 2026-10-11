# Changelog

All notable changes to this project are documented here. Versions are prototype milestones.

## [Unreleased]
### Added
- **Zoltraak and defensive magic overhaul** (after the Frieren reference): a luminous white beam (HDR core, deep-blue speckled edge, soft halo) and an original black variant (black body, violet fringe and aura, key 4); procedural seal formations (rings, glyph band, six-petal rose curve, satellites, central aperture) stacked along the firing axis; quick, charged (RMB hold scales width, seals and impact), sustained, burst and tracking modes sharing one beam/bolt/seal framework; a hexagonal barrier (analytic dome shared by visuals and collision, per-impact lit cells, outward ripples, persistent contacts for beams, stress, local failure and recovery); a hostile `ZoltraakTurret` for testing. `--dbg --zoltraak` runs the ten acceptance scenarios in day and night.
- Flight: both hands on the staff, carried upright while hovering and level-ish while gliding, with push-off strokes that drive the staff forward and burst magic from its tail.
- **Linköping** (`scenes/linkoping.tscn`): a procedural, walkable slice of the city of churches after the world map: a three-towered cathedral on a rise, cobbled market square with fountain and stalls, a stone arch bridge over a carved river, about 45 townhouses, farmsteads, fields, the round tower and a tree ring. Terrain shader gained cobbles and wet banks.
- **Zoltraak aiming** after the concept sheets: hold RMB for focus aim (over-the-shoulder camera, six-petal circle at the staff head charging over 1.5 s, minimal reticle and impact marker); quick shot, sustained beam, rapid burst (Q), tracking volley (E) and a charged heavy shot (release RMB at full charge).
- Flight, after the two flight concept sheets: upright and composed (a small forward lean, at most about 24 degrees at full boost), the staff held in the right hand and carried forward while the free arm opens out for balance, relaxed legs that trail, head kept level with the gaze, banking in turns, a gentle landing flare, and diegetic feedback (rune circle at take-off, soft mana ring under her feet, a faint wake). The staff is always summoned and kept out while flying.
- Staff performance overhaul: a staff-authority rig (`StaffRig`, authored `StaffPoseClip`s) with two-handed analytic IK (`StaffGrip`) in the VRoid hand frame, so both fists sit on the shaft with fingers wrapped; torso posture, aim yaw/elevation, regrip blending, hand release for open-palm gestures.
- **Zoltraak** (fast aimed beam, chained casts), **Defensive Barrier** (circle to dome, held, hit ripple + reactive nudge) and a re-authored **Field of Flowers** (petal circle, circular staff arc, bloom with free hand). Spell data gained staff pose, aim, sustain, chaining, movement scale, expression, charge/effect scripts and flight stamina cost.
- Free flight with a stamina bar: climb/descend/boost, casting from the air (extra stamina), gentle exhausted descent. Hover legs (`HoverPose`) and a flight lean.
- Casting faces (focused, serene, alert) from the VRoid shapes.
- Dev animation preview scene (`scenes/animation_preview.tscn`): orbit camera, spell/flight/face triggers, pause and playback speed, grip diagnostics.

## [0.1.0-prototype] - 2026-10-09: Milestone 001 "A Cottage, a Mage, and a Memory"
### Added
- Godot 4.7 project: procedural meadow terrain with heightmap collision, chunked wind grass, wildflower drifts, tree ring, distant mountains, painterly sky, golden-hour lighting with SDFGI, butterflies, pollen and chimney smoke.
- Scripted Blender pipeline: rigged and animated Linnaea, Edda and Pippa; a cottage with a furnished interior and a working door; 21 nature and garden props.
- Third-person controller (walk, run, jump, coyote time, footsteps) and a spring-arm orbit camera with an indoor mode.
- Data-driven spell framework (`SpellDefinition`, `SpellCaster`, effect scenes) with mana and cooldowns.
- **Field of Flowers**: gather VFX, a terrain-following luminous wave, raycast-validated progressive blooming of six original flower variants, ring-buffer MultiMesh caps, and deterministic save/load.
- JSON dialogue runner: stable line IDs, conditions, choices, actions, voice and localisation hooks, interpolation. A dialogue director handles camera framing and emotes. Parchment dialogue UI.
- Story *The Garden Behind the Cottage* (Edda, Pippa) with distinct before and after dialogue, and the structured memory event `memory_cottage_garden_restored`.
- HUD (spell, mana, prompt, quest tracker, toasts, memory card), pause menu with journal, save and load.
- Original synthesised ambience and SFX, and the composed theme "Brenn's Meadow".
- Headless smoke test (34 checks) and a GPU screenshot tour. GitHub Actions CI and a Pages deploy.
- Canon docs: world, characters, relationships, timeline, dialogue guidelines and format, memory events, architecture, art pipeline, asset manifest.
