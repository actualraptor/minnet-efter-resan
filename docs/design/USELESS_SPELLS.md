# Useless (but delightful) spells: the long list

> **Status: PROPOSAL.** A pool to draw from, not a commitment. Each entry is small enough to become a real `SpellDefinition` + a short effect script later. Names are Swedish-flavoured placeholders (to be proofread, like *Solstråk*); the English name is the one that matters for design.
>
> **Tone.** Magic here is everyday and personal (see `docs/lore/WORLD_BIBLE.md`). The best useless spell has three properties: it is **never the right tool**, it **is quietly perfect for one tiny moment**, and it **leaves a small, charming trace**. Inspired by the feeling of a mage who collects spells nobody asked for, without borrowing any names or specific spells from existing works.

**Legend** — *Build*: S = a few particles and a sound; M = needs a world interaction (items, NPCs, terrain); L = needs a new system. *Quest*: a good first-quest reward (small, charming, immediately demonstrable).

---

## 1. The household

| Name | English | What it does | Make it real |
|---|---|---|---|
| Fläckfri | Stain-Free | Lifts one stain, one crumb or one scuff from whatever she is looking at, with a tiny "ting". | M · decal removal on cottage props · **Quest** |
| Vikdans | Fold Dance | Laundry, napkins or a cloak fold themselves in a neat, smug little dance. | M · animate cloth props through a fold pose |
| Dammvirvel | Dust Whirl | A small dust devil sweeps the floor... and leaves a different pile. | S · particle devil, moves props a few cm |
| Tevärme | Tea Warmth | Warms exactly one cup. Loses interest in the second. | S · steam VFX + tooltip "still warm" |
| Brödsmula | Crumb Return | Every crumb on the table hops back onto the loaf. Mostly. | M · pooled crumb props |
| Nyckelsvar | Key Answer | Her keys call out where they are, in a very small voice. | M · positional audio on a prop |
| Gnistkamin | Hearth Spark | Lights a fire in a cold hearth. Also sets a nearby sleeve alight. | M · interact with hearth, light event |
| Spegelblank | Mirror Shine | Polishes a surface until it shows an honest, unflattering reflection. | S · shader flash on a surface |
| Lampsken | Lamp Glow | Gives a lantern a mood. Not more light: a *mood*. | S · tint and flicker change on a light |
| Dörrknarr | Door Murmur | Makes a door squeak a specific tune. | S · door sound swap |

## 2. Food and drink

| Name | English | What it does | Make it real |
|---|---|---|---|
| Sockerkorn | Sugar Grain | A single, perfect grain of sugar appears on the tongue. | S · UI toast + sparkle |
| Honungsdroppe | Honey Drop | A drop of honey forms in the air and refuses to be caught. | S · physics drop with a wobble |
| Bärsmak | Berry Memory | Makes plain water taste like a berry from childhood. | S · toast + memory chime |
| Brödskorpa | Crust Crisp | Re-crisps stale bread. Five seconds of glory. | M · food state on a prop |
| Smörblomma | Butter Bloom | Butter blossoms into a small yellow flower on the bread. | S · prop swap |
| Soppkväll | Soup Evening | Makes any soup a little more like "evening". | S · ambient tint change near a bowl |
| Fruktskratt | Fruit Laugh | A ripe fruit giggles when she walks past. | M · proximity audio on pickups |
| Isbit | Ice Cube | Makes one ice cube. Ceremoniously. | S · particle + prop spawn |

## 3. Weather, sky and light

| Name | English | What it does | Make it real |
|---|---|---|---|
| Regnskärm | Rain Umbrella | A small cloud holds the rain off one person's hat. Not the person. The hat. | M · rain occlusion on the head slot |
| Molnkudde | Cloud Pillow | Pulls one cloud down to sit as a pillow. It does not stay. | S · cloud prop with a soft landing |
| Dagg | Dew | Pearls of dew on every leaf in view, at the wrong hour. | S · shader param on foliage |
| Stjärnstänk | Star Splash | A handful of stars scatter in the daytime sky, politely. | S · sky shader layer |
| Vindskratt | Wind Giggle | A breeze stirs only the grass at her feet. | S · wind-shader local override |
| Sol-på-kammen | Sun on the Ridge | A beam of sunlight finds the one hilltop she is looking at. | M · spotlight on terrain |
| Lysmask | Glowworm | A single glowing worm leads her... somewhere unremarkable. | M · follower with a path to nothing |
| Skuggdocka | Shadow Puppet | Her shadow performs a short, rude play. | M · decoupled shadow animation |
| Dimvisp | Mist Whisper | A thin mist forms exactly one metre wide. | S · fog volume |

## 4. Plants and animals

| Name | English | What it does | Make it real |
|---|---|---|---|
| Fjärilsrop | Butterfly Call | One butterfly arrives, looks around, and leaves. | S · butterfly particle with a flyby |
| Gräslyssna | Grass Listen | Grass leans toward her and holds still, as if listening. | S · grass-shader bend toward the player |
| Blomsterord | Flower Word | A flower opens to say one word (always the wrong one). | M · dialogue bubble on a flower |
| Bi-bukett | Bee Bouquet | Collects bees into a bouquet-shaped cloud, for a moment. | S · particle shape |
| Mossrörelse | Moss March | A patch of moss moves a few centimetres to the left. | S · decal slide |
| Fågelspråk | Birdsong Translation | Understands one bird for four seconds. It says "mine". | S · toast + bird audio |
| Kattknuff | Cat Nudge | A cat decides, independently, to walk toward her. | M · NPC cat pathing |
| Lövfall | Leaf Fall | One leaf falls, on cue, at the most dramatic moment. | S · leaf particle |
| Svampkrans | Mushroom Ring | A fairy ring of mushrooms appears. Stepping inside does nothing. | S · prop ring + sound |

## 5. Sound and music

| Name | English | What it does | Make it real |
|---|---|---|---|
| Eko | Echo | Her voice answers itself, slightly more confident. | S · audio echo on a line |
| Visselvind | Whistle Wind | Makes the wind whistle exactly one note. | S · pitched wind sound |
| Klockskratt | Bell Laugh | Church bells chime the wrong hour, joyfully. | M · bell event + schedule |
| Pappersprassel | Paper Rustle | Turns any sound into the sound of someone turning a page. | S · bus filter |
| Tystnadslapp | Silence Patch | Patches one metre of silence over a noisy spot. | S · local audio dampening |
| Trumvirvel | Drum Whirl | Raindrops on a roof become a small marching band. | S · rain-hit audio swap |

## 6. Self, clothes and appearance

| Name | English | What it does | Make it real |
|---|---|---|---|
| Hårfrisyr | Instant Hairdo | A new hairstyle for ten seconds. Always the same one. | M · swap hair spring chains briefly |
| Mössaskift | Hat Swap | Swaps her hat with the hat of whoever is nearest. | M · NPC hat attachment |
| Skoblank | Boot Shine | Boots shine until she walks through a puddle. | S · material roughness lerp |
| Tygtaggar | Cloth Thorns | Her cape grows a perfectly useless row of small spikes. | S · cape mesh modifier |
| Färgdrag | Colour Tug | One thread on her sleeve changes colour, permanently. | S · material param, persistent |
| Kappkant | Cape Hem | Shortens or lengthens her cape by exactly one centimetre. | S · spring-chain offset |
| Ansiktsgrimas | Face Pull | Makes a specific, extremely serious face for a photograph. | M · face expression override |

## 7. Objects and physics

| Name | English | What it does | Make it real |
|---|---|---|---|
| Lyft-lite | Little Lift | Lifts a small object a hand's breadth, then thinks better of it. | M · physics prop impulse (the seed of the levitation system) |
| Stenstanna | Stone Stand | Stands a stone on its end. It falls over when she looks away. | M · prop toggle |
| Pilgrimsfjäder | Pilgrim Feather | A feather falls slowly, exactly where she points. | S · falling particle |
| Klockform | Bell Shape | Turns a cup into a small bell, which rings when empty. | M · prop swap |
| Snurrsten | Spinning Stone | A pebble spins on the spot, as long as she can stand it. | S · prop with angular velocity |
| Knopplås | Button Lock | Fastens every button within reach. Including the wrong ones. | M · NPC clothing flag |
| Rutstad | Grid Town | Arranges nearby small things into a neat grid. | M · prop snapping |
| Tyngdskratt | Gravity Giggle | Gravity is optional for one apple. | M · prop with low gravity |

## 8. People, quests and memory (the game's own theme)

| Name | English | What it does | Make it real |
|---|---|---|---|
| Minnesdoft | Memory Scent | Replays the smell of a place she has been, as a tiny drifting cloud. | M · ties to the memory-event system · **Quest** |
| Namnlapp | Name Tag | Shows the name of the last person who sat on a bench. | M · dialogue-system lookup · **Quest** |
| Glömskebock | Forgetful Goat | A goat appears and forgets why. So do you. | M · NPC goat |
| Dagbokssida | Diary Page | A page of her journal turns itself to a random date. | M · journal UI |
| Ekoskugga | Echo Shade | A faint figure repeats her last gesture, a moment late. | M · record and replay a pose |
| Hälsningsrim | Greeting Rhyme | Greets anyone in a poor rhyme. They are charmed anyway. | M · dialogue bark |
| Kartlek | Map Play | Her map folds into a bird. A very bad bird. | M · UI toy |
| Gårdagsljus | Yesterday's Light | Shows the light as it was at this spot yesterday. | M · lighting snapshot |

## 9. Travel and movement

| Name | English | What it does | Make it real |
|---|---|---|---|
| Halvhopp | Half Hop | A jump that goes exactly half as high as expected. | S · jump param |
| Spårfri | Trackless | Her footprints vanish... one at a time, in order. | S · decal fade |
| Skosula-flyt | Sole Float | Floats a centimetre above puddles. | S · foot-grounder offset on water |
| Svävkant | Edge Hover | Hangs at the edge of a drop for a second. For effect. | M · ledge state |
| Vindridning | Wind Ride | A gust carries her hat one metre ahead. She follows. | M · prop follower |
| Rundvandring | Round Walk | Walks her in a perfect circle around a single flower. | M · scripted movement |

## 10. Almost-useful (the traps)

| Name | English | What it does | Make it real |
|---|---|---|---|
| Nästan-eld | Almost Fire | A flame that is warm but never lights anything. | S · particle + warmth tooltip |
| Nästan-vatten | Almost Water | A cupful of water that is ever so slightly wrong. | S · material tint |
| Nästan-gnista | Almost Spark | A spark that gets very close to lighting something. | S · particle, no ignite |
| Falsk nyckel | Almost Key | A key shape that fits every lock except the one in question. | M · inventory trap |
| Mjukt ljud | Soft Sound | Turns one sound into a quieter copy of itself. | S · bus filter |

---

## First-quest candidates (small, readable, charming)

1. **Fläckfri (Stain-Free)** — the cottage is full of stains; demonstrates in one second; can give a quest where she cleans one stubborn thing.
2. **Namnlapp (Name Tag)** — fits "remembering"; ties to the dialogue and memory systems.
3. **Minnesdoft (Memory Scent)** — the most on-theme; a drifting scent-cloud that remembers a place.

## Implementation notes

- Almost all of these are **S**: a particle effect, a toast and a sound, driven by the existing `SpellDefinition` + effect script. No new framework.
- The **M** ones want small hooks (prop swap, NPC flag, journal lookup). Build a tiny shared "world interaction" helper once (find the thing she is looking at; ask it to react) and most M spells become a few lines.
- Several seed larger systems on purpose: *Little Lift* (levitating objects, a stated future direction), *Echo Shade* (pose recording), *Yesterday's Light* (time-of-day snapshots).
- Keep a "useless" tag and a codex page so the collection itself is the reward: every spell is a note in her journal, not a power.
