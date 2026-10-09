# Architecture (milestone 001)

```
game/
  project.godot                Godot 4.7, Forward+, Jolt physics, shader globals
  scenes/main.tscn             the slice: terrain, world, flowers, grass, player, camera, NPCs, UI
  scripts/
    core/        game_state.gd (autoload: flags, quests, relationships, memories, date, save/load)
                 audio_manager.gd (autoload: sfx, ambience layers, music crossfade)
                 input_setup.gd, character_visual.gd (toon materials, anim loops)
    world/       meadow_terrain.gd (heightmap mesh + collision + queries), grass_field.gd (chunked
                 MultiMesh), wildflowers.gd, world_builder.gd (env, cottage, props, tree ring,
                 mountains, ambient life), world_layout.gd (hand-authored layout data),
                 door.gd, indoor_volume.gd, world_materials.gd
    player/      player.gd (controller + caster interface), camera_rig.gd (spring-arm orbit)
    spells/      spell_definition.gd (Resource), spell_context.gd, spell_caster.gd (mana, cooldown,
                 gather VFX, effect hand-off), field_of_flowers_effect.gd, flower_field.gd
                 (persistent ring-buffer MultiMeshes), flower_mesh_builder.gd
    dialogue/    dialogue_runner.gd (JSON, conditions, actions, voice, l10n), dialogue_director.gd
                 (camera framing, emotes, participant control)
    npc/         npc.gd
    ui/          hud.gd, dialogue_box.gd, pause_menu.gd (journal), ui_style.gd
    main.gd      story controller for "The Garden Behind the Cottage"
  data/          dialogue/*.json, characters/cast.json, quests/quests.json, spells/*.tres
  shaders/       terrain, grass, flower, foliage, toon_character, sky, butterfly
  tests/         smoke_test.gd (headless playthrough), screenshot_tour.gd (GPU captures)
art/blender/     scripted asset generators (characters, cottage, nature) → game/assets/models
tools/audio/     original SFX synthesis + composed MIDI theme → game/assets/audio
```

## Key decisions
- **One large singleton (`GameState`)** for persistent narrative state. Everything else is a scene node. Systems that own persistent sub-state register a *provider* (`save_state`/`load_state`), e.g. `FlowerField`.
- **The spell system is data-driven.** A `SpellDefinition` resource plus an effect scene with `start(ctx)`. `SpellCaster` handles validation, mana, cooldown and the shared gather visual. The player only implements a tiny caster interface. Adding a spell never touches movement code.
- **Field of Flowers wave** is drawn by the terrain and grass shaders from global uniforms (`spell_wave`, `spell_wave_strength`), so it follows the ground exactly. Flowers are validated with physics raycasts: terrain only, slope limit, off paths, outside the cottage.
- **Flower persistence** stores patches (centre, radius, seed) rather than per-flower data. Load re-plants deterministically, and the smoke test verifies an identical count. Each variant is a MultiMesh ring buffer (3,200 cap) so recasting stays cheap.
- **Dialogue is data.** Stable line IDs serve as the localisation and voice keys. Conditions are Godot `Expression`s over `GameState`.
- **Saves are versioned JSON** (`SAVE_VERSION`, `_migrate`).
- **Deterministic world:** all scatter uses fixed seeds, and the hand-authored layout lives in `WorldLayout`.

## Not built yet (by design)
Combat, inventory, companions, time skips and aging, village, storybook prologue, voice acting. The hooks are memory events, relationships, `world_date`, the spell categories and voice IDs.
