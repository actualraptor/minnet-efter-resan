# Dialogue data format

Files live in `game/data/dialogue/<id>.json`. Speakers are defined in `game/data/characters/cast.json`.

```jsonc
{
  "id": "edda",
  "entries": [                         // first entry whose "if" passes starts the talk
    {"if": "quest(\"garden_of_jonas\") == \"complete\"", "node": "after"},
    {"node": "first"}
  ],
  "nodes": {
    "first": {
      "lines": [
        {"id": "edda.first.01", "speaker": "char_edda", "text": "...", "emote": "Talk",
         "pause": 0.6,                 // seconds of silence before the line types
         "if": "has_flag(\"pippa_met\")",
         "voice": "res://...ogg",      // optional; default res://assets/audio/voice/<id>.ogg
         "do": ["flag:edda_met", "affinity:char_edda:1"]}
      ],
      "choices": [{"id": "edda.first.c_name", "text": "...", "goto": "name", "if": "...", "do": []}],
      "goto": "next_node"              // used when there are no choices
    }
  }
}
```

**Conditions** are Godot `Expression`s evaluated against `GameState`: `has_flag(name)`, `flag(name)`, `quest(id)`, `affinity(char_id)`, `has_memory(id)`, combined with `and`, `or` and `not`.

**Actions (`do`):**

| Action | Effect |
|---|---|
| `flag:name` / `flag:name=value` | Set a flag. |
| `quest:id=state` | Change a quest state. |
| `affinity:char_id:+n` | Adjust a relationship. |
| `event:name` | Emit to scene logic. |
| `memory:id` | Ask scene logic to record a memory event. |
| `end` | Stop the conversation. |

Choices also set `chose.<choice id>` automatically.

**Interpolation:** `{flag_name}` in text is replaced with the flag value, for example Pippa's `{flowers_counted}`.
