# Minnet efter resan

*"The memory after the journey"*: a cozy, third-person 3D fantasy adventure in Godot 4.

Fifty years after her party defeated the Hollow King, the centuries-old elven mage **Freyja** walks the old roads again. Her friends have grown old, the world has moved on, and she is only beginning to notice how much ordinary lives matter.

> **Status: early prototype (milestone 001).** Not released and no release date. Everything here is work in progress.

- 🌐 **Website:** https://actualraptor.github.io/minnet-efter-resan/ (coming-soon page and public roadmap)
- 🗺️ **Roadmap:** [site/roadmap.html](site/roadmap.html), data in [site/data/roadmap.json](site/data/roadmap.json)
- 📋 **Development board:** [Issues](https://github.com/actualraptor/minnet-efter-resan/issues) · [Project board (kanban)](https://github.com/users/actualraptor/projects/1)
- 📒 **Current state:** [PROJECT_STATE.md](PROJECT_STATE.md) · [CHANGELOG.md](CHANGELOG.md)

## What's playable now (milestone 001: "A Cottage, a Mage, and a Memory")
- A ~100 × 100 m sunlit meadow with rolling terrain, wind-blown grass, wildflowers, trees, hills, mountains, butterflies and chimney smoke.
- Edda's cottage, with a furnished interior you can walk into through a working door.
- Freyja, a rigged and animated elven mage. Third-person movement (walk, run, jump), an orbit camera that avoids walls, footsteps.
- **Field of Flowers**: gather light at the staff, then a luminous wave travels along the ground and real 3D flowers sprout and bloom. They persist and are saved.
- Text dialogue where both the NPCs and Freyja speak, with choices, conditions, camera framing and voice-ready line IDs.
- A short, complete story, *The Garden Behind the Cottage*, that records a structured **memory event** in Freyja's journal.
- Original synthesised ambience and SFX, and a composed meadow theme.

## Controls
| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move / look | WASD / mouse | Left / right stick |
| Run | Shift | L3 |
| Jump | Space | A |
| Interact / talk | E | X |
| Advance dialogue | Space / E / Enter / click | A |
| Choose | 1–3 or click | — |
| Summon / stow staff | Q | — |
| Cast equipped spell (summons the staff if needed; hold for the barrier) | Left mouse or F | RB |
| Select spell: Field of Flowers / Zoltraak / Barrier | 1 / 2 / 3 | — |
| Zoltraak focus aim (hold; releasing at full charge fires the heavy shot) | Right mouse | — |
| While aiming: quick shot / sustained beam / rapid burst / tracking volley | Tap or hold LMB or F / Q / E | — |
| Cancel a cast | X | — |
| Fly (toggle; also double-tap Space in the air) | H | Y |
| Climb / descend while flying (Shift = faster) | Space / Ctrl | A / LB |
| Journal / pause | J or Tab / Esc | Start |
| Quick save / load | F5 / F9 | — |

## Running from source
1. Install **Godot 4.7.2 stable** (standard build): https://godotengine.org/download
2. Open `game/project.godot` in the editor and press **F5**, or from a terminal:
   ```bash
   godot --path game
   ```
3. The first open imports assets, which takes a minute.

### Tests
```bash
godot --headless --path game --import          # import, fail on script errors
godot --headless --path game -- --smoke-test   # scripted playthrough of the whole quest
godot --path game --position 20000,20000 -- --tour --out=/abs/path    # runtime screenshots (GPU), window placed off-screen
```
The smoke test checks systems (dialogue, quests, spell, flowers, memory, save/load). It is **not** a substitute for a human playtest.

## Rebuilding assets
All 3D models and audio are generated from source in this repo:
```bash
blender -b --factory-startup --python art/blender/build_characters.py -- .
blender -b --factory-startup --python art/blender/build_cottage.py -- .
blender -b --factory-startup --python art/blender/build_nature.py -- .
FLUIDSYNTH=fluidsynth SOUNDFONT=/path/GeneralUser-GS.sf2 tools/audio/build_audio.sh
```
See [docs/design/ART_PIPELINE.md](docs/design/ART_PIPELINE.md) and the provenance manifest [docs/ASSETS.md](docs/ASSETS.md).

## Repository layout
```
game/        Godot project (scenes, scripts, shaders, data, assets, tests)
art/blender/ scripted asset generators (source of truth for models)
tools/audio/ original audio synthesis and music composition
docs/        lore, narrative, design docs and the asset manifest
site/        GitHub Pages coming-soon site and roadmap (data-driven)
```

## Contributing and licence
See [CONTRIBUTING.md](CONTRIBUTING.md). Code is MIT. Story, characters, models and audio are © the project owner (see [LICENSE](LICENSE)). This is an original, non-commercial fan homage to quiet post-adventure fantasy. It is not affiliated with any existing work, and uses none of its characters, art, music or text.
