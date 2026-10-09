// Seeds labels, milestones and a focused set of issues for the development board.
// Idempotent-ish: skips labels/milestones/issues whose names already exist.
// Usage: GH=/path/to/gh node tools/github/seed_board.js owner/repo
const { execFileSync } = require("child_process");
const GH = process.env.GH || "gh";
const REPO = process.argv[2];
if (!REPO) throw new Error("usage: node seed_board.js owner/repo");
const gh = (args, input) => execFileSync(GH, args, { encoding: "utf8", input, stdio: ["pipe", "pipe", "pipe"] }).trim();
const api = (method, path, body) => JSON.parse(gh(["api", "-X", method, `repos/${REPO}/${path}`, "--input", "-"], JSON.stringify(body || {})) || "{}");

const LABELS = [
  ["type:feature", "5f8b83", "New capability"], ["type:bug", "c46a6a", "Something is broken"],
  ["type:art", "b07aa8", "Models, shaders, VFX, UI art"], ["type:narrative", "7b4f7a", "Writing, characters, lore"],
  ["type:audio", "8fb0d8", "Music, SFX, ambience"], ["type:tech-debt", "8a7f6a", "Cleanup and refactoring"],
  ["type:infra", "6c8fb5", "CI, tooling, repo, site"], ["type:epic", "d8b25a", "Phase-level tracking issue"],
  ["priority:high", "e0603a", ""], ["priority:medium", "e0b24a", ""], ["priority:low", "c8d6b0", ""],
  ["area:world", "9cbc8a", "Terrain, vegetation, environment"], ["area:characters", "e6b8a2", "Player/NPC models & animation"],
  ["area:spells", "bfe39a", "Spell system & effects"], ["area:dialogue", "d6a3c9", "Dialogue system & UI"],
  ["area:quests", "f2b38a", "Quests, memory events"], ["area:ui", "efe4cc", "HUD, menus"], ["area:camera", "a8c4c0", "Camera & controls"],
  ["status:backlog", "ededed", ""], ["status:ready", "c2e0c6", ""], ["status:in-progress", "fbca04", ""],
  ["status:review-testing", "1d76db", ""], ["status:blocked", "b60205", "Waiting on something external"],
];
const MILESTONES = [
  ["001 Meadow, Cottage, Flower Spell, First Dialogue", "First playable vertical slice: meadow, cottage, rigged mage, Field of Flowers, Edda & Pippa, one warm quest and memory event."],
  ["002 Village and Quests", "The village south of the meadow: residents with schedules, small humane errands, a grimoire hunt."],
  ["003 Companions and Campfires", "Two companions who follow, banter and have priorities; camp scenes and shared meals."],
  ["004 Dungeons and Combat", "Third-person magic combat, barriers, enemy AI with telegraphs, a first ruin/dungeon and boss."],
  ["005 Relationships and Memories", "Journal of memory events, promises, gifts and callbacks driving dialogue."],
  ["006 Time and Generations", "Time skips, aging, descendants, inherited places; historical batch simulation."],
  ["007 Storybook Prologue", "Illustrated animated flipbook of the original journey with music and subtitles."],
  ["008 World Expansion and Polish", "More regions, seasons, accessibility, performance and the road to the coast."],
];

const verified = "Verified 2026-10-09: headless smoke test PASS (34/34) and runtime screenshots via `--tour`. Not yet hand-playtested.";
const ISSUES = [
  { m: 0, t: "Meadow terrain, grass and scenery", l: ["type:feature", "area:world"], done: true,
    b: "Rolling ~100 m meadow with collision, wind grass, wildflowers, trees, mountains, sky, ambient life.\n\n**Acceptance**\n- [x] No square edges / flat grid visible\n- [x] Collision everywhere the player can walk\n- [x] Wind motion on grass and foliage\n\n" + verified },
  { m: 0, t: "Cottage exterior, furnished interior and working door", l: ["type:art", "area:world"], done: true,
    b: "Scripted Blender cottage: timber/plaster, slate roof, chimney, windows, ivy, interior (hearth, bed, table, shelves, books, clutter).\n\n**Acceptance**\n- [x] Enterable with working door\n- [x] Camera and collision work inside\n- [x] Warm interior lighting\n\n" + verified },
  { m: 0, t: "Rigged, animated Linnaea (idle/walk/run/jump/fall/cast/talk)", l: ["type:art", "area:characters"], done: true,
    b: "Original scripted rigged base model exported to GLB with 7 actions; Edda and Pippa share the rig generator.\n\n**Known limits**: static faces, mitten hands, rigid cloth. See ART_PIPELINE.md.\n\n" + verified },
  { m: 0, t: "Field of Flowers spell and reusable spell framework", l: ["type:feature", "area:spells"], done: true,
    b: "SpellDefinition resource + SpellCaster + effect scene. Gather VFX, terrain-following wave, raycast-validated progressive blooms, MultiMesh caps, deterministic persistence.\n\n**Acceptance**\n- [x] Not castable indoors\n- [x] No flowers in the cottage\n- [x] Recasts stay within caps\n- [x] Flowers survive save/load\n\n" + verified },
  { m: 0, t: "Text dialogue: speakers, choices, conditions, voice-ready IDs", l: ["type:feature", "area:dialogue"], done: true,
    b: "JSON dialogue with stable line IDs, conditions over GameState, actions, interpolation, voice and localisation hooks; camera framing; parchment UI.\n\n" + verified },
  { m: 0, t: "Quest: The Garden Behind the Cottage + memory event", l: ["type:narrative", "area:quests"], done: true,
    b: "Edda & Pippa; before/after dialogue; cast in the back meadow; bench conversation; records `memory_cottage_garden_restored` with promise and Teodor seed.\n\n" + verified },
  { m: 0, t: "Original ambience, SFX and meadow theme", l: ["type:audio"], done: true,
    b: "Synthesised wind/birds/fire/footsteps/door/spell sounds and a composed MIDI theme rendered with GeneralUser GS.\n\nLevels checked with ffmpeg; **mix not yet judged by ear in play**." },
  { m: 0, t: "Versioned save/load", l: ["type:feature", "area:quests"], done: true, b: "JSON saves with version + migration hook; providers for system state.\n\n" + verified },
  { m: 0, t: "Human playtest of milestone 001", l: ["type:feature", "priority:high", "status:review-testing"],
    b: "Play the full slice with keyboard/mouse and a gamepad.\n\n**Check**\n- [ ] Movement and jump feel\n- [ ] Camera outdoors and indoors\n- [ ] Dialogue pacing and readability\n- [ ] Audio mix (ambience vs music vs SFX)\n- [ ] FPS on target hardware (record numbers)\n- [ ] Any blocking bugs" },
  { m: 0, t: "Indoor camera crowds Linnaea in tight spots", l: ["type:bug", "area:camera", "priority:medium", "status:ready"],
    b: "In the cottage the spring arm collapses close behind Linnaea; her hair can fill the frame.\n\n**Ideas**: fade the model when the arm is short, raise pitch, use a slightly wider FOV indoors.\n\n**Acceptance**\n- [ ] Edda and the room stay readable from anywhere inside" },
  { m: 0, t: "Character art pass against the official Linnaea sheet", l: ["type:art", "area:characters", "priority:high", "status:blocked"],
    b: "**Blocked**: the concept/character sheet has not been added to the repo yet.\n\nOnce available: match proportions, face, hair volume, outfit layers and staff; consider an artist-made model or face blend shapes." },
  { m: 0, t: "Interior dressing and lighting toward the reference", l: ["type:art", "area:world", "status:ready"],
    b: "Denser clutter (hanging herbs, bottles, botanicals), window light shafts, softer warm/cool balance, Edda's outfit silhouette (shawl reads as a blob).\n\n**Acceptance**\n- [ ] Runtime interior screenshot reads as cozy and lived-in" },
  { m: 0, t: "Options menu: sensitivity, volumes, rebinding, text speed", l: ["type:feature", "area:ui", "priority:low", "status:backlog"],
    b: "**Acceptance**\n- [ ] Mouse/pad sensitivity and invert\n- [ ] Master/music/ambience/SFX volume\n- [ ] Key rebinding\n- [ ] Dialogue text speed and size" },
];
const EPICS = [
  [1, "Epic: Village and Quests", "Brenn's village south of the meadow; 3–5 residents with schedules; 2–3 humane errands; one eccentric grimoire hunt."],
  [2, "Epic: Companions and Campfires", "Two companions with follow/banter/opinions; campfire scenes; relationship hooks."],
  [3, "Epic: Dungeons and Combat", "Aim/cast, barriers, mana, telegraphed enemies, a ruin, a distinct boss; combat never crowds out exploration."],
  [4, "Epic: Relationships and Memories", "Journal UI for memory events; promises with due dates; gifts; dialogue callbacks."],
  [5, "Epic: Time and Generations", "Time skips with meaningful transitions; aging; descendants recognising Linnaea; reproducible historical simulation."],
  [6, "Epic: Storybook Prologue", "Illustrated pages, parallax, page turns, subtitles, music, skippable; future voice."],
  [7, "Epic: World Expansion and Polish", "New regions, seasons, accessibility, performance, the road to the coast (Teodor)."],
];

const existingLabels = new Set(JSON.parse(gh(["label", "list", "-R", REPO, "--limit", "200", "--json", "name"])).map(x => x.name));
for (const [name, color, desc] of LABELS) {
  if (existingLabels.has(name)) continue;
  gh(["label", "create", name, "-R", REPO, "--color", color, "--description", desc || name]);
}
const msList = JSON.parse(gh(["api", `repos/${REPO}/milestones?state=all&per_page=100`]));
const msNum = {};
for (const m of msList) msNum[m.title] = m.number;
for (const [title, description] of MILESTONES) {
  if (!msNum[title]) msNum[title] = api("POST", "milestones", { title, description }).number;
}
const existing = new Set(JSON.parse(gh(["issue", "list", "-R", REPO, "--state", "all", "--limit", "300", "--json", "title"])).map(x => x.title));
const created = [];
const make = (title, body, labels, msIndex, close) => {
  if (existing.has(title)) return;
  const res = api("POST", "issues", { title, body, labels, milestone: msNum[MILESTONES[msIndex][0]] });
  if (close) api("PATCH", `issues/${res.number}`, { state: "closed", state_reason: "completed" });
  created.push({ number: res.number, title, url: res.html_url, closed: !!close });
};
for (const i of ISSUES) make(i.t, i.b, i.l, i.m, i.done);
for (const [m, t, b] of EPICS) make(t, b + "\n\nBreak into smaller cards when this phase becomes current.", ["type:epic", "status:backlog"], m, false);
console.log(JSON.stringify({ milestones: msNum, created }, null, 1));
