# Changelog

All notable changes to this project are documented here. Versions are prototype milestones.

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
