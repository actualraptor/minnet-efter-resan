// Composes the original exploration theme "Brenn's Meadow" as a MIDI file.
// Gentle 6/8 in D major: harp arpeggios, flute melody, soft string pad.
// Usage: node tools/audio/compose_theme.js <out.mid>
// Rendered with FluidSynth + GeneralUser GS (see tools/audio/build_audio.sh).
const fs = require("fs");
const out = process.argv[2] || "build/meadow_theme.mid";

const TPQ = 480; // ticks per quarter
const EIGHTH = TPQ / 2;
const BAR = EIGHTH * 6; // 6/8

const n = s => { // "D4" -> midi
  const m = s.match(/^([A-G])(#|b)?(-?\d)$/);
  const base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0);
  return 12 * (parseInt(m[3]) + 1) + base;
};

// Chord progression (one per bar), 16 bars, loops cleanly back to D.
const prog = [
  ["D3", "A3", "D4", "F#4"], ["B2", "F#3", "B3", "D4"], ["G2", "D3", "G3", "B3"], ["A2", "E3", "A3", "C#4"],
  ["D3", "A3", "D4", "F#4"], ["F#2", "C#3", "F#3", "A3"], ["G2", "D3", "G3", "B3"], ["A2", "E3", "G3", "C#4"],
  ["B2", "F#3", "B3", "D4"], ["G2", "D3", "G3", "B3"], ["D3", "A3", "D4", "F#4"], ["A2", "E3", "A3", "C#4"],
  ["G2", "D3", "G3", "B3"], ["E2", "B2", "E3", "G3"], ["A2", "E3", "A3", "C#4"], ["D3", "A3", "D4", "F#4"],
];
// Flute melody: [note or null, length in eighths]; 6 eighths per bar.
const mel = [
  [["F#5", 3], ["E5", 1], ["D5", 2]], [["F#5", 2], ["A5", 1], ["B5", 3]], [["A5", 2], ["G5", 1], ["F#5", 2], ["E5", 1]], [["E5", 6]],
  [["F#5", 3], ["A5", 1], ["D6", 2]], [["C#6", 2], ["A5", 1], ["F#5", 3]], [["G5", 2], ["B5", 1], ["A5", 2], ["G5", 1]], [["E5", 4], [null, 2]],
  [["D5", 2], ["F#5", 1], ["B5", 3]], [["A5", 2], ["G5", 1], ["D5", 3]], [["F#5", 2], ["E5", 1], ["D5", 2], ["A4", 1]], [["C#5", 6]],
  [["B4", 2], ["D5", 1], ["G5", 3]], [["F#5", 2], ["E5", 1], ["G5", 3]], [["E5", 3], ["C#5", 3]], [["D5", 6]],
];

function track(events, channel, program, name) {
  // events: [tick, type, note, vel]
  events.sort((a, b) => a[0] - b[0] || (a[1] === "off" ? -1 : 1));
  const bytes = [];
  const vlq = v => { const b = [v & 0x7f]; while ((v >>= 7)) b.unshift((v & 0x7f) | 0x80); return b; };
  const nm = Buffer.from(name);
  bytes.push(0, 0xff, 0x03, nm.length, ...nm);
  bytes.push(0, 0xc0 | channel, program);
  bytes.push(0, 0xb0 | channel, 91, 70); // reverb
  bytes.push(0, 0xb0 | channel, 7, channel === 2 ? 70 : 100);
  let last = 0;
  for (const [t, type, note, vel] of events) {
    bytes.push(...vlq(t - last)); last = t;
    bytes.push((type === "on" ? 0x90 : 0x80) | channel, note, vel);
  }
  bytes.push(0, 0xff, 0x2f, 0);
  const hdr = Buffer.from("MTrk"); const len = Buffer.alloc(4); len.writeUInt32BE(bytes.length);
  return Buffer.concat([hdr, len, Buffer.from(bytes)]);
}

const harp = [], flute = [], strings = [];
const loops = 2;
for (let L = 0; L < loops; L++) {
  prog.forEach((ch, bar) => {
    const t0 = (L * prog.length + bar) * BAR;
    // Harp: rolling arpeggio up and down over the bar.
    const pattern = [0, 1, 2, 3, 2, 1];
    pattern.forEach((k, i) => {
      const note = n(ch[k]) + (i === 3 ? 12 : 0);
      harp.push([t0 + i * EIGHTH, "on", note, 62 + (i === 0 ? 14 : 0)], [t0 + i * EIGHTH + EIGHTH * 3, "off", note, 0]);
    });
    // Strings: sustained pad (root, fifth, third an octave up).
    [ch[0], ch[1], ch[3]].forEach(s => strings.push([t0, "on", n(s), 44], [t0 + BAR - 10, "off", n(s), 0]));
    // Flute enters on the second pass, so the loop opens quietly.
    if (L === 1 || bar >= 4) {
      let t = t0;
      for (const [note, len] of mel[bar]) {
        if (note) flute.push([t, "on", n(note), 70], [t + len * EIGHTH - 20, "off", n(note), 0]);
        t += len * EIGHTH;
      }
    }
  });
}

const header = Buffer.alloc(14);
header.write("MThd", 0); header.writeUInt32BE(6, 4); header.writeUInt16BE(1, 8); header.writeUInt16BE(4, 10); header.writeUInt16BE(TPQ, 12);
// Tempo track: dotted quarter = 52 bpm -> quarter = 78 bpm.
const usPerQuarter = Math.round(60000000 / 78);
const tempo = Buffer.from([0, 0xff, 0x51, 3, (usPerQuarter >> 16) & 255, (usPerQuarter >> 8) & 255, usPerQuarter & 255,
  0, 0xff, 0x58, 4, 6, 3, 24, 8, 0, 0xff, 0x2f, 0]);
const tt = Buffer.concat([Buffer.from("MTrk"), Buffer.from([0, 0, 0, tempo.length]), tempo]);
fs.writeFileSync(out, Buffer.concat([header, tt,
  track(harp, 0, 46, "Harp"), track(flute, 1, 73, "Flute"), track(strings, 2, 48, "Strings")]));
console.log("wrote", out);
