# World Bible

> **Status key.** **[CANON]** is implemented in the game or locked by the team. **[PROPOSAL]** is an idea that can still change. Original world. It is inspired by the *feeling* of quiet post-adventure fantasy, and it borrows no names, places, plots or dialogue from any existing work.

## Tone [CANON]
- Whimsical, warm, colourful and full of small discoveries. Loss is occasional and **earned**.
- Magic is everyday and personal, not just a weapon. Useless spells are a joy.
- Time matters because people are worth knowing first.

## Calendar [CANON]
- Years are counted plainly (`Year 1031`). Seasons: spring, summer, autumn, winter.
- In-game dates use `Day N of <Season>, Year Y` (see `GameState.format_date()`).
- **981**: the Hollow King falls. **1031**: the game begins, fifty years later.

## The Hollow King [CANON: name and fall date / PROPOSAL: details]
- An enormous ancient threat ended by a party of four in 981.
- [PROPOSAL] It was "hollow" because it fed on forgotten things: abandoned places, unspoken names. This rhymes with the game's theme of remembering.

## Regions
### Brenn's Meadow (`reg_brenns_meadow`) [CANON]
- A sunlit meadow with rolling hills, birches and oaks, ringed by pines and distant mountains.
- A dirt road runs north from the south road to **Edda Brenn's cottage**.
- The **back meadow** (`loc_brenn_cottage_back_meadow`) was Jonas Brenn's garden. Standing stones mark where the bluebells grew.
- [PROPOSAL] A village of the same name lies a short walk south (milestone 002).

### Brenn's Crossing [CANON: mentioned]
- A market town where Jonas once sold seeds. The party passed through in the summer of 981.

### The coast (east) [CANON: mentioned]
- Teodor, the party's hero, lives there now, "I think". It is the seed for a future journey.

## Magic [CANON for implemented spells]
- Categories: whimsical, environmental, utility, exploration, defensive, offensive, ancient.
- Magic draws on **mana**, which settles between casts (cooldown).
- **Field of Flowers** (`spell_field_of_flowers`), whimsical. "The ground remembers it was once a garden, and agrees to be one again." It cannot be cast indoors ("Someone would have to sweep up after"). Flowers are real and persist.
- [PROPOSAL] Collectable odd spells: warm a teacup, sweeten fruit, call butterflies, find a lost hat (a Jonas callback).

## Species [PROPOSAL]
- **Elves** live for millennia. Their sense of scale makes years feel like weeks.
- **Humans** are the majority of the cast. They are short-lived and that matters.
