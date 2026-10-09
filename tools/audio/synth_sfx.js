// Procedural, original sound design for Minnet efter resan (no samples used).
// Usage: node tools/audio/synth_sfx.js <out_dir_for_wavs>
// Produces 44.1 kHz mono 16-bit WAVs; tools/audio/build_audio.sh converts to OGG.
const fs = require("fs");
const path = require("path");

const SR = 44100;
const out = process.argv[2] || "build/audio_wav";
fs.mkdirSync(out, { recursive: true });

let seed = 1031;
function rnd() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; }
const noise = () => rnd() * 2 - 1;

function writeWav(name, data) {
  const buf = Buffer.alloc(44 + data.length * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + data.length * 2, 4); buf.write("WAVE", 8);
  buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write("data", 36); buf.writeUInt32LE(data.length * 2, 40);
  let peak = 0; for (const v of data) peak = Math.max(peak, Math.abs(v));
  const g = peak > 0.98 ? 0.98 / peak : 1;
  for (let i = 0; i < data.length; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, data[i] * g)) * 32767), 44 + i * 2);
  fs.writeFileSync(path.join(out, name + ".wav"), buf);
  console.log("wrote", name, (data.length / SR).toFixed(2) + "s");
}

// One-pole filters
function lowpass(x, cutoff) { const a = Math.exp(-2 * Math.PI * cutoff / SR); let y = 0; return x.map(v => (y = (1 - a) * v + a * y)); }
function highpass(x, cutoff) { const lp = lowpass(x, cutoff); return x.map((v, i) => v - lp[i]); }
function env(n, a, d, sustain = 0, r = 0) {
  const e = new Float32Array(n);
  const A = Math.floor(a * SR), D = Math.floor(d * SR), R = Math.floor(r * SR);
  for (let i = 0; i < n; i++) {
    if (i < A) e[i] = i / Math.max(A, 1);
    else if (i < A + D) e[i] = 1 - (1 - sustain) * ((i - A) / Math.max(D, 1));
    else e[i] = sustain;
    if (R > 0 && i > n - R) e[i] *= (n - i) / R;
  }
  return e;
}
const secs = s => new Float32Array(Math.floor(s * SR));
function mix(dst, src, at = 0, gain = 1) { const o = Math.floor(at * SR); for (let i = 0; i < src.length && o + i < dst.length; i++) dst[o + i] += src[i] * gain; return dst; }
// Seamless loop: crossfade the tail into the head.
function loopify(x, fade = 1.5) {
  const F = Math.floor(fade * SR), n = x.length - F, y = new Float32Array(n);
  for (let i = 0; i < n; i++) y[i] = x[i];
  for (let i = 0; i < F; i++) { const t = i / F; y[i] = x[i] * t + x[n + i] * (1 - t); }
  return y;
}
// Soft bell (additive, inharmonic partials)
function bell(freq, dur, bright = 1) {
  const x = secs(dur);
  const parts = [[1, 1], [2.0, 0.45 * bright], [2.76, 0.25 * bright], [5.4, 0.08 * bright]];
  for (let i = 0; i < x.length; i++) {
    const t = i / SR; let v = 0;
    for (const [m, a] of parts) v += a * Math.sin(2 * Math.PI * freq * m * t) * Math.exp(-t * (2.2 + m * 0.9));
    x[i] = v * Math.min(1, t * 400);
  }
  return x;
}

// --- Ambience ------------------------------------------------------------------
function meadowWind(len = 24) {
  const x = secs(len + 1.5);
  const raw = x.map(noise);
  const lo = lowpass(raw, 420), mid = highpass(lowpass(raw, 1400), 500);
  for (let i = 0; i < x.length; i++) {
    const t = i / SR;
    const gust = 0.55 + 0.25 * Math.sin(t * 0.37) + 0.15 * Math.sin(t * 0.91 + 1.3) + 0.08 * Math.sin(t * 2.1);
    x[i] = (lo[i] * 0.9 + mid[i] * 0.25 * gust) * gust;
  }
  return loopify(x);
}
function birds(len = 28) {
  const x = secs(len + 1.5);
  const songs = [
    (t0, f) => { for (let k = 0; k < 4; k++) mix(x, chirp(f * (1 + k * 0.05), f * 1.4, 0.07), t0 + k * 0.11, 0.5); },
    (t0, f) => { mix(x, chirp(f * 1.3, f * 0.8, 0.22), t0, 0.45); mix(x, chirp(f, f * 1.25, 0.12), t0 + 0.28, 0.4); },
    (t0, f) => { for (let k = 0; k < 7; k++) mix(x, chirp(f * 1.2, f * 1.1, 0.035), t0 + k * 0.06, 0.3); },
  ];
  let t = 0.4;
  while (t < len - 1) {
    const f = 2200 + rnd() * 2200;
    songs[Math.floor(rnd() * songs.length)](t, f);
    t += 0.9 + rnd() * 2.4;
  }
  return loopify(x);
}
function chirp(f0, f1, dur) {
  const x = secs(dur); let ph = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / x.length; const f = f0 + (f1 - f0) * t;
    ph += 2 * Math.PI * f / SR;
    x[i] = Math.sin(ph + 0.6 * Math.sin(ph * 0.5)) * Math.sin(Math.PI * t) ** 1.5;
  }
  return x;
}
function fireplace(len = 16) {
  const x = secs(len + 1.5);
  const rumble = lowpass(lowpass(x.map(noise), 180), 220);
  for (let i = 0; i < x.length; i++) x[i] = rumble[i] * 2.2 * (0.8 + 0.2 * Math.sin(i / SR * 1.7));
  let t = 0;
  while (t < len) {
    const pop = secs(0.012 + rnd() * 0.03);
    for (let i = 0; i < pop.length; i++) pop[i] = noise() * Math.exp(-i / (pop.length * 0.25));
    mix(x, highpass(pop, 900 + rnd() * 2000), t, 0.25 + rnd() * 0.6);
    t += rnd() < 0.2 ? 0.02 + rnd() * 0.05 : 0.08 + rnd() * 0.45;
  }
  return loopify(x);
}

// --- One-shots -------------------------------------------------------------------
function stepGrass() {
  const x = secs(0.22);
  const n = x.map(noise);
  const f = highpass(lowpass(n, 2600 + rnd() * 800), 400);
  const e = env(x.length, 0.008, 0.18);
  return f.map((v, i) => v * e[i] * (1 + 0.5 * Math.sin(i * 0.004)));
}
function stepWood() {
  const x = secs(0.2);
  const f0 = 95 + rnd() * 25;
  for (let i = 0; i < x.length; i++) { const t = i / SR; x[i] = Math.sin(2 * Math.PI * f0 * t) * Math.exp(-t * 32) * 0.9; }
  const click = lowpass(secs(0.03).map(noise), 3500).map((v, i) => v * Math.exp(-i / 200));
  return mix(x, click, 0, 0.5);
}
function creak(up) {
  const dur = 0.75; const x = secs(dur); let ph = 0;
  for (let i = 0; i < x.length; i++) {
    const t = i / x.length;
    const f = up ? 180 + 140 * t + 20 * Math.sin(t * 40) : 300 - 160 * t + 18 * Math.sin(t * 37);
    ph += 2 * Math.PI * f / SR;
    const saw = (ph / Math.PI) % 2 - 1;
    x[i] = saw * 0.35 * Math.sin(Math.PI * t) * (0.6 + 0.4 * Math.sin(t * 90));
  }
  const y = lowpass(x, 1800);
  if (!up) { const thud = secs(0.25); for (let i = 0; i < thud.length; i++) thud[i] = Math.sin(2 * Math.PI * 70 * i / SR) * Math.exp(-i / SR * 25); mix(y, thud, dur - 0.22, 0.9); }
  return y;
}
function shimmerRise(dur = 1.1) {
  const x = secs(dur + 0.6);
  const notes = [587.33, 739.99, 880, 1108.73, 1318.51]; // D major add9 sparkle
  notes.forEach((f, k) => mix(x, bell(f, 1.2, 0.6), k * dur / notes.length, 0.35));
  const air = highpass(x.map(noise), 3000);
  for (let i = 0; i < x.length; i++) x[i] += air[i] * 0.06 * Math.min(1, i / (dur * SR));
  return x;
}
function release() {
  const x = secs(2.4);
  [293.66, 440, 587.33, 739.99].forEach((f, k) => mix(x, bell(f, 2.2, 0.8), k * 0.03, 0.5 - k * 0.07));
  const whoosh = lowpass(secs(1.2).map(noise), 900).map((v, i, a) => v * Math.sin(Math.PI * i / a.length));
  return mix(x, whoosh, 0, 0.4);
}
function waveSparkle() {
  const x = secs(3.5);
  for (let k = 0; k < 26; k++) {
    const f = [1174.66, 1318.51, 1479.98, 1760, 1975.53, 2349.32][Math.floor(rnd() * 6)];
    mix(x, bell(f, 0.8, 0.4), k * 0.11 + rnd() * 0.05, 0.12 * (1 - k / 30));
  }
  return x;
}
function memoryChime() {
  const x = secs(4.2);
  [587.33, 739.99, 880, 1174.66, 880, 1108.73].forEach((f, k) => mix(x, bell(f, 2.5, 0.5), k * 0.32, 0.35));
  return x;
}
function questStart() { const x = secs(1.8); mix(x, bell(659.25, 1.6, 0.5), 0, 0.5); mix(x, bell(987.77, 1.4, 0.5), 0.16, 0.45); return x; }
function tick(f, d) { const x = secs(d); for (let i = 0; i < x.length; i++) { const t = i / SR; x[i] = Math.sin(2 * Math.PI * f * t) * Math.exp(-t * 60); } return x; }
function jump() { const w = lowpass(secs(0.35).map(noise), 1200); return w.map((v, i, a) => v * Math.sin(Math.PI * i / a.length) * 0.6); }

writeWav("amb_meadow", meadowWind());
writeWav("amb_birds", birds());
writeWav("amb_fireplace", fireplace());
for (let k = 1; k <= 4; k++) { writeWav("sfx_step_grass_" + k, stepGrass()); writeWav("sfx_step_wood_" + k, stepWood()); }
writeWav("sfx_door_open", creak(true));
writeWav("sfx_door_close", creak(false));
writeWav("sfx_spell_gather", shimmerRise());
writeWav("sfx_spell_release", release());
writeWav("sfx_spell_wave", waveSparkle());
writeWav("sfx_memory_chime", memoryChime());
writeWav("sfx_quest_start", questStart());
writeWav("sfx_ui_advance", tick(1400, 0.08));
writeWav("sfx_ui_choice", tick(880, 0.15));
writeWav("sfx_jump", jump());
