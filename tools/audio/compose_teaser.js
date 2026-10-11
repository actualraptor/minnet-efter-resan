// Composes the teaser's two pieces as MIDI files:
//   calm.mid   - "Blomsterfält": slow, sparse piano + flute + strings + celesta (A minor / C).
//   action.mid - "Mörkstråk":    fast strings ostinato, taiko, brass stabs, choir (D minor).
// Usage: node tools/audio/compose_teaser.js <out_dir>
// Rendered with FluidSynth + GeneralUser GS (see tools/audio/build_teaser_audio.sh).
const fs = require("fs");
const path = require("path");
const outDir = process.argv[2] || "build/teaser_audio";
fs.mkdirSync(outDir, { recursive: true });

const TPQ = 480;
const Q = TPQ, E = TPQ / 2, S = TPQ / 4;
const BAR = Q * 4;

const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const n = s => {
  const m = s.match(/^([A-G])(#|b)?(-?\d)$/);
  return 12 * (parseInt(m[3]) + 1) + NOTE[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0);
};

function vlq(v) { const b = [v & 0x7f]; while ((v >>= 7)) b.unshift((v & 0x7f) | 0x80); return b; }

function track(events, channel, program, name, vol = 100, reverb = 80) {
  events.sort((a, b) => a[0] - b[0] || (a[1] === "off" ? -1 : 1));
  const bytes = [];
  const nm = Buffer.from(name);
  bytes.push(0, 0xff, 0x03, nm.length, ...nm);
  if (channel !== 9) bytes.push(0, 0xc0 | channel, program);
  bytes.push(0, 0xb0 | channel, 91, reverb);
  bytes.push(0, 0xb0 | channel, 7, vol);
  let last = 0;
  for (const [t, type, note, vel] of events) {
    bytes.push(...vlq(Math.max(0, t - last))); last = t;
    bytes.push((type === "on" ? 0x90 : 0x80) | channel, note, vel);
  }
  bytes.push(0, 0xff, 0x2f, 0);
  const len = Buffer.alloc(4); len.writeUInt32BE(bytes.length);
  return Buffer.concat([Buffer.from("MTrk"), len, Buffer.from(bytes)]);
}

function writeMidi(file, bpm, tracks) {
  const header = Buffer.alloc(14);
  header.write("MThd", 0); header.writeUInt32BE(6, 4); header.writeUInt16BE(1, 8);
  header.writeUInt16BE(tracks.length + 1, 10); header.writeUInt16BE(TPQ, 12);
  const us = Math.round(60000000 / bpm);
  const tempoBytes = [0, 0xff, 0x51, 3, (us >> 16) & 255, (us >> 8) & 255, us & 255, 0, 0xff, 0x58, 4, 4, 2, 24, 8, 0, 0xff, 0x2f, 0];
  const tl = Buffer.alloc(4); tl.writeUInt32BE(tempoBytes.length);
  const tempo = Buffer.concat([Buffer.from("MTrk"), tl, Buffer.from(tempoBytes)]);
  fs.writeFileSync(file, Buffer.concat([header, tempo, ...tracks]));
}

const on = (arr, t, note, len, vel) => { arr.push([t, "on", note, vel], [t + len - 6, "off", note, 0]); };

// =================================== CALM ===========================================
{
  // 24 bars at 66 bpm = ~87 s of material; the teaser cuts what it needs.
  const prog = [
    ["A2", "E3", "A3", "C4", "E4"], ["F2", "C3", "F3", "A3", "C4"], ["C3", "G3", "C4", "E4", "G4"], ["G2", "D3", "G3", "B3", "D4"],
    ["A2", "E3", "A3", "C4", "E4"], ["F2", "C3", "F3", "A3", "C4"], ["D3", "A3", "D4", "F4", "A4"], ["E2", "B2", "E3", "G#3", "B3"],
    ["F2", "C3", "F3", "A3", "C4"], ["C3", "G3", "C4", "E4", "G4"], ["G2", "D3", "G3", "B3", "D4"], ["A2", "E3", "A3", "C4", "E4"],
    ["F2", "C3", "F3", "A3", "C4"], ["G2", "D3", "G3", "B3", "D4"], ["E2", "B2", "E3", "G3", "B3"], ["A2", "E3", "A3", "C4", "E4"],
  ];
  const bars = prog.length * 2;
  const melody = [
    // one phrase per two bars: [note, length in eighths]
    [["E5", 4], ["D5", 2], ["C5", 2]], [["A4", 8]],
    [["C5", 3], ["D5", 1], ["E5", 4]], [["D5", 8]],
    [["E5", 2], ["G5", 2], ["E5", 2], ["D5", 2]], [["C5", 6], ["B4", 2]],
    [["A4", 3], ["B4", 1], ["C5", 2], ["E5", 2]], [["G#4", 4], ["B4", 4]],
    [["A5", 4], ["G5", 2], ["E5", 2]], [["G5", 4], ["E5", 4]],
    [["D5", 3], ["E5", 1], ["G5", 4]], [["E5", 6], [null, 2]],
    [["F5", 4], ["E5", 2], ["C5", 2]], [["D5", 4], ["B4", 4]],
    [["C5", 2], ["D5", 2], ["E5", 4]], [["A4", 8]],
  ];
  const piano = [], flute = [], strings = [], celesta = [], bass = [];
  for (let L = 0; L < 2; L++) {
    prog.forEach((ch, bar) => {
      const t0 = (L * prog.length + bar) * BAR;
      // Piano: slow rolled arpeggio, soft.
      const pat = [0, 2, 3, 4, 3, 2, 3, 1];
      pat.forEach((k, i) => on(piano, t0 + i * E, n(ch[k]), E * 3, 50 + (i === 0 ? 12 : 0) + (L ? 4 : 0)));
      // Sustained string pad (enters after the first four bars of the first pass).
      if (L === 1 || bar >= 4) [ch[1], ch[3], ch[4]].forEach(s => on(strings, t0, n(s), BAR, 38 + (L ? 8 : 0)));
      // Bass note.
      on(bass, t0, n(ch[0]) - 0, BAR, 52);
      // Celesta sparkle on bar 1 beat 4 of each pair.
      if (bar % 2 === 1) on(celesta, t0 + Q * 3, n(ch[4]) + 12, Q, 40 + 8 * L);
      // Flute phrase every pair of bars, from the second pass (and the last four bars of the first).
      if (L === 1 || bar >= 12) {
        if (bar % 2 === 0) {
          const ph = melody[bar];
          let t = t0;
          for (const [note, len] of ph) {
            if (note) on(flute, t, n(note), len * E, 62);
            t += len * E;
          }
        } else {
          let t = t0;
          for (const [note, len] of melody[bar]) {
            if (note) on(flute, t, n(note), len * E, 60);
            t += len * E;
          }
        }
      }
    });
  }
  writeMidi(path.join(outDir, "calm.mid"), 66, [
    track(piano, 0, 0, "Piano", 100, 90),
    track(flute, 1, 73, "Flute", 96, 100),
    track(strings, 2, 48, "Strings", 76, 100),
    track(celesta, 3, 8, "Celesta", 80, 110),
    track(bass, 4, 42, "Cello", 80, 70),
  ]);
}

// =================================== ACTION ==========================================
{
  const bpm = 148;
  // D minor, 24 bars: Dm Dm Bb C | Dm Dm Bb A  (x3) then a rising climax.
  const prog = [
    ["D2", "D3", "A3", "D4", "F4"], ["D2", "D3", "A3", "D4", "F4"], ["Bb1", "Bb2", "F3", "Bb3", "D4"], ["C2", "C3", "G3", "C4", "E4"],
    ["D2", "D3", "A3", "D4", "F4"], ["D2", "D3", "A3", "D4", "F4"], ["Bb1", "Bb2", "F3", "Bb3", "D4"], ["A1", "A2", "E3", "A3", "C#4"],
    ["G2", "G3", "D4", "G4", "Bb4"], ["G2", "G3", "D4", "G4", "Bb4"], ["F2", "F3", "C4", "F4", "A4"], ["E2", "E3", "B3", "E4", "G#4"],
    ["D2", "D3", "A3", "D4", "F4"], ["D2", "D3", "A3", "D4", "F4"], ["Bb1", "Bb2", "F3", "Bb3", "D4"], ["C2", "C3", "G3", "C4", "E4"],
    ["Bb1", "Bb2", "F3", "Bb3", "D4"], ["C2", "C3", "G3", "C4", "E4"], ["D2", "D3", "A3", "D4", "F4"], ["A1", "A2", "E3", "A3", "C#4"],
    ["Bb1", "Bb2", "F3", "Bb3", "D4"], ["C2", "C3", "G3", "C4", "E4"], ["D2", "D3", "A3", "D4", "F4"], ["D2", "D3", "A3", "D4", "F4"],
  ];
  const lead = [
    // melody on the second half
    [["A4", 4], ["D5", 4], ["F5", 4], ["E5", 4]], [["D5", 8], ["C5", 4], ["A4", 4]],
  ];
  const ostinato = [], bassl = [], brass = [], choir = [], drums = [], melo = [], timp = [];
  prog.forEach((ch, bar) => {
    const t0 = bar * BAR;
    // Strings ostinato: 16ths on root / fifth, accented on the beat.
    for (let i = 0; i < 16; i++) {
      const note = n(ch[i % 4 === 3 ? 2 : (i % 2 ? 1 : 1)]) + (i % 8 === 7 ? 12 : 0);
      on(ostinato, t0 + i * S, note, S, i % 4 === 0 ? 92 : 66);
    }
    // Bass doubles the root on every eighth.
    for (let i = 0; i < 8; i++) on(bassl, t0 + i * E, n(ch[0]), E, i % 2 ? 70 : 90);
    // Brass: a stab on beats 1 and the 'and' of 3 in the second half.
    if (bar >= 4) {
      [ch[2], ch[3], ch[4]].forEach(s => { on(brass, t0, n(s), Q, 84); on(brass, t0 + Q * 2 + E, n(s), E, 78); });
    }
    // Choir: a sustained rising pad from bar 8.
    if (bar >= 8) [ch[3], ch[4]].forEach(s => on(choir, t0, n(s) + 12, BAR, 56 + Math.min(bar - 8, 12) * 2));
    // Drums (percussion channel): kick on 1 and 3, snare/toms on 2 and 4, driving 8th hats from bar 4.
    on(drums, t0, 36, S, 110); on(drums, t0 + Q * 2, 36, S, 104);
    on(drums, t0 + Q, 38, S, 96); on(drums, t0 + Q * 3, 38, S, 100);
    if (bar >= 4) for (let i = 0; i < 8; i++) on(drums, t0 + i * E, 42, S, i % 2 ? 54 : 70);
    // Taiko toms fill on the last beat of every fourth bar.
    if (bar % 4 === 3) [47, 45, 43, 41].forEach((tom, k) => on(drums, t0 + Q * 3 + k * S, tom, S, 108));
    // Timpani roll under the climax.
    if (bar >= 16) for (let i = 0; i < 8; i++) on(timp, t0 + i * E, n(ch[0]) + 12, E, 70 + (bar - 16) * 3);
    // Melody over bars 8-15 and 16-23 (violins in octaves).
    if (bar >= 8 && bar < 24) {
      const phrase = lead[bar % 2];
      let t = t0;
      for (const [note, len] of phrase) {
        const nn = n(note) + (bar >= 16 ? 12 : 0);
        on(melo, t, nn, len * S, 86);
        t += len * S;
      }
    }
  });
  // Final hit on the downbeat after the last bar.
  const end = prog.length * BAR;
  ["D2", "D3", "A3", "D4", "F4", "A4"].forEach(s => { on(brass, end, n(s), BAR * 2, 100); on(choir, end, n(s) + 12, BAR * 2, 90); });
  on(drums, end, 36, Q, 127); on(drums, end, 49, BAR * 2, 120);
  on(timp, end, n("D2"), BAR * 2, 120);
  writeMidi(path.join(outDir, "action.mid"), bpm, [
    track(ostinato, 0, 45, "Pizzicato strings", 90, 60),
    track(bassl, 1, 33, "Bass", 90, 40),
    track(brass, 2, 61, "Brass", 78, 80),
    track(choir, 3, 52, "Choir", 70, 110),
    track(drums, 9, 0, "Drums", 110, 50),
    track(melo, 5, 40, "Violin", 92, 90),
    track(timp, 6, 47, "Timpani", 100, 80),
  ]);
}
console.log("teaser music composed ->", outDir);
