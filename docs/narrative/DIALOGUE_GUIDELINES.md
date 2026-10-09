# Dialogue Guidelines

## Voice
- **Freyja:** understated, precise, gently funny. Short lines. She notices a flower's proper name before she notices a feeling. Feelings arrive as pauses ("...Oh.") and as small concessions, never speeches.
- **Edda:** brisk rural wit. She insults affectionately, and when she means something she says it plainly and once.
- **Pippa:** blunt, counts things, interrupts herself, asks what adults won't.

## Craft rules
1. **Earn feeling through play.** Callbacks reference memory events or flags the player actually caused.
2. **Subtext over statement.** "Maybe he wasn't buying them to plant." is enough. Never explain the subtext.
3. **Let pauses work.** Use the `pause` field (seconds) and lines of `...`. Silence is allowed.
4. **No manipulative music cues.** A scene must land in silence. Music only dips during dialogue.
5. **Humour sits next to tenderness.** Every sad beat gets a human-sized joke nearby (the goat, the radish, the kettle).
6. **Choices express personality, not morality.** Options are dry humour, curiosity, honesty or avoidance. Each one is something Freyja could plausibly say.
7. **Short lines.** At most two sentences per line in most cases, so lines are readable and voice-actable.
8. **Every important character has a life beyond the mage.**

## Quality gate (run before merging a scene)
- Does the scene earn its feeling through prior play?
- Is each speaker distinct with their name hidden?
- Is the subtext readable without being stated?
- Is Freyja consistent with the character bible?
- Will this matter later (a flag, memory or relationship)?
- Does it work with no music at all?

## Voice-over readiness
- Every line has a stable `id` (`<dialogue>.<node>.<nn>`). **Never renumber or reuse IDs.** Add new suffixes instead.
- Audio is picked up automatically from `res://assets/audio/voice/<id>.ogg`, or from the line's `voice` field.
- Localisation uses the line `id` as the translation key (`DialogueRunner.localize`).
- See `DIALOGUE_FORMAT.md` for the data schema.
