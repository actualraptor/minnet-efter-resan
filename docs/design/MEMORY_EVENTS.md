# Memory events

Memory events are compact, append-only records of moments that later dialogue, aging and descendants can reference. They are stored in `GameState.memories` and saved with the game.

## Schema (v1)
```jsonc
{
  "id": "memory_cottage_garden_restored",   // stable, unique
  "schema": 1,
  "title": "The garden behind Edda's cottage",
  "kind": "shared_moment",                  // shared_moment | promise | first_meeting | argument | gift | journey | death | reunion
  "participants": ["char_freyja", "char_edda", "char_pippa"],
  "absent_but_present": ["char_jonas_brenn", "char_teodor"],
  "location": {"id": "loc_brenn_cottage_back_meadow", "region": "reg_brenns_meadow", "position": [x, y, z]},
  "world_date": {"year": 1031, "season": "spring", "day": 14, "hour": 15.0},
  "spell": "spell_field_of_flowers",
  "outcome": {"garden_restored": true, "flower_patches": 1, "flowers_counted_by_pippa": 150},
  "relationships": {"char_edda": {"affinity": 5, "trust": 0, "notes": []}},
  "promises": [{"id": "promise_return_to_edda", "to": "char_edda", "text": "Come back in a few weeks. Not years.", "due_in_days": 21, "kept": null}],
  "seeds": ["heard_jonas_story", "teodor_bought_seeds_for_her"],
  "tags": ["garden", "jonas", "promise", "mortality", "flowers"],
  "journal_text": "In Freyja's voice — shown in the journal.",
  "recorded_by": "char_freyja"
}
```

## Rules
- Record only events the player actually lived through.
- `journal_text` is written in Freyja's voice and varies with the player's choices.
- Future systems (aging, descendants) query memories by participant, tag or location, and never re-simulate them.
- Bump `schema` and add a migration in `GameState._migrate` when fields change meaning.

## Implemented
| ID | Trigger | Future hooks |
|---|---|---|
| `memory_cottage_garden_restored` | Edda's farewell line `edda.farewell.04` | Promise to return (`due_in_days: 21`). `resolve_visit_teodor`. Old Pippa callback. |
