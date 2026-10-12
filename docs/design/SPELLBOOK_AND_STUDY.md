# Spellbook, satchel and studying

How spells are known, bound and learned. Built for Demo 1; written so the long spell list in `USELESS_SPELLS.md` can be added one entry at a time.

## Concepts
- **Known spells** (`GameState.known_spells`) are every spell she can use. The caster's list follows it (`Player._sync_spells`).
- **Hotbar** (`GameState.hotbar`, nine slots, keys 1-9) says which known spell sits on which number key. A spell sits on one key only; binding it elsewhere moves it and swaps the old occupant back. New spells take the first free key.
- **Satchel** (`GameState.inventory`: item id → count). Items are defined in `data/items/items.json`: `name`, `kind` (`book` or `scroll`), `desc`, `teaches` (a spell id), `consumed` (a scroll is used up; a book stays as a keepsake).
- **Studying**: Satchel → select the item → *Study*. The world pauses behind a black screen, the clock runs forward by the spell's `study_hours` (complexity), the calendar rolls on past midnight (`GameState.advance_time`), then the spell is learned. There is no day/night cycle yet, so the meadow stays in golden hour; the clock and date change.

## Screens
- **B** opens the spellbook (cards for every known spell, details, the hotbar row at the bottom). Select a spell, then click a slot, press 1-9, or drag the card or another slot onto a slot. Right-click empties a slot.
- **I** opens the satchel. Esc closes. Both pause the game and are blocked during dialogue.
- The HUD shows the filled number keys above the equipped-spell pill, with a cooldown fill.

## Add a spell
1. `data/spells/<name>.tres` (`SpellDefinition`; set `study_hours` if it is learned from an item, `allowed_indoors` for household magic).
2. One line in `SpellLibrary.FILES` (`id → file name`).
3. Give it a source: a dialogue action `item:<book>` plus an `items.json` entry whose `teaches` is the spell id, or add the id to `GameState.DEFAULT_SPELLS` if she starts with it.
4. Spells without a `staff_pose` cast without summoning the staff (use for household and small magic).

## Not built yet
Item stacks beyond count, equipment, item use outside books/scrolls, drag items to the world, spell categories/filters in the book, rebinding of the 1-9 keys, a day/night cycle that responds to waiting.
