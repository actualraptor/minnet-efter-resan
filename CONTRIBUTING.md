# Contributing

Thanks for wanting to help with *Minnet efter resan*. It's a small, careful project, and these notes keep it that way.

## Workflow
1. Pick or open an issue. The board flows **Backlog → Ready → In Progress → Review/Testing → Done**, and **Blocked** is explicit.
2. Branch from `main` (`feature/<short-name>` or `fix/<short-name>`).
3. Keep the Godot project playable at every commit.
4. Before opening a PR:
   ```bash
   godot --headless --path game --import
   godot --headless --path game -- --smoke-test
   ```
   Then play the affected scene by hand. Visual changes need **in-game screenshots**. Never pass off concept art as a screenshot.
5. Fill in the PR template.

## Code style
- Typed GDScript where it helps readability. One responsibility per script. Avoid adding autoloads.
- New spells are a `SpellDefinition` resource plus an effect scene. Never edit the player controller to add a spell.
- Persistent state goes through `GameState` or a registered save provider.

## Narrative
- Read `docs/narrative/DIALOGUE_GUIDELINES.md` and run its quality gate.
- **Never renumber or reuse dialogue line IDs.** They are localisation and voice keys.
- Mark lore as **[CANON]** or **[PROPOSAL]** in `docs/lore/`.

## Assets
- Prefer generated or original assets. Third-party assets need a compatible licence, and an entry in `docs/ASSETS.md` with source, licence and attribution.
- No ripped or unlicensed material, and no commercial music recordings.

## Labels
`type:feature`, `type:bug`, `type:art`, `type:narrative`, `type:tech-debt`, `type:audio`, `type:infra` · `priority:high|medium|low` · `area:*` · `status:*`
