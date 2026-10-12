# Demo 1: The Cottage

Status: **planning**. Decisions marked **OWNER** are not made yet.

## Finish line (all must be verified, not assumed)
1. A new game reaches the end card in 15-25 minutes, with exactly 3 quests completed, tracked in the journal, and a short closing beat.
2. Save/load works mid-quest and after each quest (smoke test extended).
3. Each quest has a scripted headless test; the smoke test and CI stay green.
4. A Windows export (zip) runs from a clean folder without the editor: start, play, quit.
5. Minimal options (volumes, mouse sensitivity, restart, quit) and a credits screen with every licence.
6. The owner has done one hands-on playtest and every blocker from it is fixed.
7. 60 fps at 1080p on the RTX 5070 Ti, real numbers reported.

## Scope fence
**In:** cottage and meadow, Freyja, Edda, Pippa, Field of Flowers, flight, dialogue/journal/save, two new quests, polish, options, export.
**Out unless the owner says otherwise:** new regions (Linköping, village), combat and enemies (Zoltraak stays a toy), new characters, large art-direction changes. The VRM swap has already landed (the player scene uses `freyja_vroid_game.glb`), so it is a dependency now, not a bonus.

## Quests 2 and 3: proposals (**OWNER picks**)
Rules: max one new mechanic each, reuse existing systems, rewards drawn from `USELESS_SPELLS.md`, no new characters.

### Pair A (prototype already started): "Flowers for Jonas" then "Good morning, statue"
- **Quest 2, Flowers for Jonas.** After the garden, Pippa mentions Grandpa's headstone under the oak, overgrown and unread. Freyja plants flowers there with the Field of Flowers (cast within a few metres of the stone), then tells Edda, who answers with the stain rhyme her mother used, which turns out to be a real spell: **Fläckfri**. *Reuses:* the garden quest's cast detection and dialogue actions, the memory event system. *New mechanic:* learning a reward spell (flag-gated spell slot, key 5).
- **Quest 3, Good morning, statue.** Pippa has said good morning to a mossed-over statue by the road every day. Freyja cleans it with Fläckfri; the plaque beneath reads that she made it rain on one tomato and then the whole valley, and the village forgot to spell her name wrong. *Reuses:* Fläckfri, Pippa, the interactable group, memory events. *New mechanic:* cleaning a prop (moss shader that recedes).
- Why it works: the spell chain gives the demo one small reward arc, both quests are stationary (about 5 minutes each), and the statue carries the game's theme (remembering and being remembered).

### Pair B: "Tea that stays warm" then "Pippa's book of facts"
- **Quest 2, Tea that stays warm** (Tevärme, *Tea Warmth*, household list). Edda's tea is always cold by the time she sits down. Freyja learns the spell from a fact in Pippa's book, then warms exactly one cup. *Reuses:* the interior and the indoor-cast rule (this spell is the first allowed indoors). *New mechanic:* an indoor prop interaction (warm a cup).
- **Quest 3, Pippa's book of facts.** Pippa's fact book needs three facts that are true: Freyja and Pippa look at three things in the meadow (the oak, the stones, the bench) with E; each is a short monologue that becomes a "fact" with a number. *Reuses:* interactables, monologues, memory events. *New mechanic:* collecting facts into the journal.
- Why: all inside or beside the cottage, tiny, no new props to model.

### Pair C: mix
Fläckfri from the stone (A2), then the facts quest (B3), where one of the facts is the statue. Smallest content, but loses the cleaning mechanic.

My recommendation: **A**. Closest to your earlier request, it is the only pair where the second quest is a payoff of the first, and the one new prop (moss shader) is already prototyped. Risk: moss must read as moss and the statue must be modelled well enough to be worth the quest.

## Decisions I need (**OWNER**)
1. Quests 2 and 3 (A, B, C, or your own).
2. The ending beat. Two directions: (a) she leaves at dusk down the road after Edda's "weeks, not years", with the statue behind her; (b) she stays on the bench with Edda and the camera lifts over the meadow, flowers and all.
3. The demo's title card (name and subtitle text).
4. The practice range (dummy shooters that hit the player): keep as a toy, hide in the demo, or remove from the demo.
5. Remove the F10 Linköping shortcut from the demo build (default: yes).

## Plan (ordered, one commit per task, tests green at each)
| # | Task | Done when |
|---|---|---|
| 0 | Reconcile PROJECT_STATE, roadmap, board; add this plan | Docs match the repo; JSON validates; board has the milestone |
| 1 | Demo spine: quest list, HUD tracks the current unfinished quest, journal lists all three, `demo_complete` flag | Smoke test asserts tracker text for each state |
| 2 | Quest 2 (per pick): content, mechanic, test | `tests/quest2_test.gd` passes headless; save/load mid-quest and after |
| 3 | Quest 3: same | `tests/quest3_test.gd` passes; full chain test passes |
| 4 | Ending beat and end card (title card text from the owner) | Scripted run reaches the card; a dialogue-time estimate of the full path is 15-25 min |
| 5 | Options (volumes, sensitivity, restart, quit); settings persisted; remove F10 and "Prototype 001" subtitle | Settings survive a restart; test reads/writes them |
| 6 | Credits screen from a data file; resolve the CC-BY Freyja base (exclude from export, or credit) | Every shipped asset in `docs/ASSETS.md` appears; export contains no unlisted asset |
| 7 | CI: add the quest tests; keep import and smoke test | CI green on GitHub |
| 8 | Windows export (zip), self-contained template path, run from a clean folder | Zip unpacked in a temp folder starts, runs a scripted boot check, quits with code 0 |
| 9 | Frame-time measurement at 1080p (scripted walk + cast) on the 5070 Ti | Average and 1% low reported; fix or document if under 60 fps |
| 10 | Playtest build to the owner with a "look for" list; fix blockers | Owner confirms; blockers closed |

## After demo (not built)
Linköping and the village, enemies and health, rebinding UI, text speed and accessibility options, more spells from the pool, Edda and Pippa model upgrade, aging and descendants.
