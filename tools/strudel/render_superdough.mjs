// render_superdough.mjs -- HIGH-FIDELITY verify-loop render using Strudel's REAL engine.
//
//   node render_superdough.mjs <code.strudel> <out.wav> [--cycles N] [--cps X] [--sr 44100]
//                                                        [--samples <mapUrlOrGithubOrLocalJson>] [--no-samples]
//                                                        [--seed <int>]   (deterministic RNG, default 12345)
//
// --samples may be passed MULTIPLE times; each value is either a remote map URL (fetched by
// superdough, as before) or a LOCAL .json sample map whose file paths get inlined as data:
// URIs (see loadLocalSampleMap below -- Workstream C, sf2-extracted GBA samples).
//
// Unlike render_strudel.mjs (hand-rolled oscillators, dry, synth-only), this drives the
// ACTUAL superdough engine offline via node-web-audio-api's OfflineAudioContext, so the
// rendered WAV == what strudel.cc plays: real waveforms + FX (reverb/delay/filter/distortion/
// crush) + sample sounds & drums (s("bd")) + soundfonts (gm_*). The diff finally measures
// real fidelity instead of a dry approximation.
//
//   TIER A: real @strudel engine parses the code; queryArc note/control events -> <out>.events.json
//   TIER B: superdough renders those events offline -> <out.wav>
//
// GUARDRAILS (do not break): @strudel/core stays <=1.2.3 headless-safe (pinned 1.1.0 here);
// superdough@1.3.0 loads worklets from a data: URL (safe in Node); NEVER import @strudel/web
// or @strudel/repl. See notes/DESIGN.md + references/setup.md.

import * as nwa from 'node-web-audio-api';
import fs from 'node:fs';
import path from 'node:path';

// --- browser-env shims superdough needs in Node ---
for (const k of Object.keys(nwa)) { if (!(k in globalThis)) globalThis[k] = nwa[k]; }
globalThis.window = globalThis;
globalThis.self = globalThis;
if (!globalThis.navigator) globalThis.navigator = { userAgent: 'node' };
globalThis.location = globalThis.location || { href: 'file:///', origin: 'file://' };
if (typeof globalThis.addEventListener !== 'function') globalThis.addEventListener = () => {};
if (typeof globalThis.removeEventListener !== 'function') globalThis.removeEventListener = () => {};

// --- deterministic RNG: seeded mulberry32 replaces Math.random ---
// superdough generates its reverb impulse response from Math.random, so any render using
// .room() differed byte-for-byte on every run -> spectral scores weren't comparable/cacheable.
// Seed via --seed <int> (default 12345). Placement note: the @strudel/* imports below are
// STATIC (hoisted), so they initialize BEFORE this line runs -- that's fine because they don't
// consume Math.random at import time for anything render-relevant; the critical consumer
// (superdough) is imported DYNAMICALLY after these shims, so every MAIN-REALM Math.random it
// sees (reverbGen IR, noise buffers, chainID, zzfx) is the seeded PRNG. SCOPE: AudioWorklet
// processors run in a separate node:worker_threads realm (node-web-audio-api/js/AudioWorklet.js),
// so supersaw voice phases (worklets.mjs:559) and wt_* phases (:1388) stay nondeterministic --
// renders using those sounds are flagged in the summary (nondeterministic_sounds) + stderr.
// mulberry32 (public domain, Tommy Ettinger): 32-bit state, passes gjrand. Kept as a factory so
// renderAttempt() can RE-SEED per attempt: a stuck-note retry then replays the identical draw
// stream and stays byte-identical to a clean first-attempt run of the same code+seed.
const SEED = (() => { const i = process.argv.indexOf('--seed'); return (i >= 0 ? Number(process.argv[i + 1]) : 12345) >>> 0; })();
const mulberry32 = (s) => () => {
  s = (s + 0x6D2B79F5) | 0;
  let t = Math.imul(s ^ (s >>> 15), 1 | s);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
Math.random = mulberry32(SEED);

// --- reverb-IR race fix: track inner offline renders so the main render can drain them ---
// Seeding alone is NOT enough for byte-identical reverb: superdough's IR pipeline (reverb.mjs
// createReverb -> reverbGen.applyGradualLowpass, lpFreqStart defaults to 15000 ≠ 0) filters the
// impulse through an INNER OfflineAudioContext and only attaches it to the convolver in that
// render's oncomplete -- asynchronously, on native threads. If the MAIN startRendering() wins
// the race, the convolver renders with a missing/late IR: bimodal timing-dependent WAV bytes
// (observed idle: same seed, two stable md5s). Wrapping startRendering lets renderAttempt()
// await every in-flight offline render (+ an event-loop tick for oncomplete handlers) before
// kicking off the main one, making the IR attachment deterministic.
const pendingOfflineRenders = new Set();
const _origStartRendering = nwa.OfflineAudioContext.prototype.startRendering;
nwa.OfflineAudioContext.prototype.startRendering = function () {
  const p = _origStartRendering.call(this);
  const tracked = p.catch(() => {});          // never let a failed inner render reject the drain
  pendingOfflineRenders.add(tracked);
  tracked.finally(() => pendingOfflineRenders.delete(tracked));
  return p;
};

import * as core from '@strudel/core';
import * as mini from '@strudel/mini';
import * as tonal from '@strudel/tonal';
import { evaluate } from '@strudel/transpiler';
import { ensureSoundfonts } from './soundfont_loader.mjs';

// superdough MUST be imported dynamically AFTER the shims above — a static import is
// hoisted and would run superdough's module code (BaseAudioContext prototype patches,
// window checks) before window/globals exist, breaking reverb (createReverb) etc.
// `let` + resolved URL because stuck-note retries re-import a FRESH module instance (see
// renderAttempt): superdough's module-scope state -- the lazy SuperdoughAudioController
// (superdough.mjs:320, still wrapping attempt 1's context; resetGlobalEffects() rebuilds its
// output on the OLD stored context) and nodePools.mjs WeakRef'd nodes -- otherwise hands
// old-context nodes to the retry's fresh OfflineAudioContext, and EVERY event dies with
// "Attempting to connect nodes from different contexts" (observed: retry rendered 0/54).
const SD_URL = import.meta.resolve('superdough');
let sd = await import(SD_URL);

await core.evalScope(core, mini, tonal);
core.setStringParser(mini.mini);

// ---- args ----
const [codeFile, outWav] = process.argv.slice(2);
const argNum = (k, d) => { const i = process.argv.indexOf(k); return i >= 0 ? Number(process.argv[i + 1]) : d; };
const argStr = (k, d) => { const i = process.argv.indexOf(k); return i >= 0 ? process.argv[i + 1] : d; };
const hasFlag = (k) => process.argv.includes(k);
if (!codeFile || !outWav) {
  console.error('usage: node render_superdough.mjs <code.strudel> <out.wav> [--cycles N] [--cps X] [--sr 44100] [--samples <url>] [--no-samples]');
  process.exit(1);
}
let CYCLES = argNum('--cycles', 4);
let CPS = argNum('--cps', 0.5);
const SR = argNum('--sr', 44100);
// every --samples occurrence is collected (repeatable flag); default stays the Dirt bank
const SAMPLE_MAPS = (() => {
  const out = [];
  for (let i = 0; i < process.argv.length; i++) if (process.argv[i] === '--samples') out.push(process.argv[i + 1]);
  return out.length ? out : ['https://raw.githubusercontent.com/tidalcycles/Dirt-Samples/master/strudel.json'];
})();

// ---- local sample maps -> data: URIs (Workstream C: sf2-extracted GBA samples) ----
// superdough's sampler loads every sample URL with fetch() (sampler.mjs loadBuffer). Node's
// fetch (undici) does NOT support file:// URLs -- but it DOES support data: URIs per the
// fetch spec (verified: fetch('data:audio/wav;base64,..') resolves in this runtime). So a
// LOCAL map (JSON with paths relative to the JSON's directory, e.g. work/sf2/rse.json
// written by scripts/sf2_extract.py) is inlined here: each path is read from disk and
// replaced by a data:<mime>;base64 URI, and the resulting OBJECT is passed to sd.samples().
// Why this over the alternatives: no http server (no ports/teardown/races), no superdough
// patching (guardrails intact), and byte-deterministic (same files -> same URIs -> same
// render). Resolved ONCE up front; stuck-note retries re-register the same object on the
// fresh superdough module instance.
function loadLocalSampleMap(jsonPath) {
  const dir = path.dirname(path.resolve(jsonPath));
  const MIME = { '.wav': 'audio/wav', '.mp3': 'audio/mpeg', '.ogg': 'audio/ogg', '.flac': 'audio/flac' };
  const toDataUri = (p) => {
    if (/^(data:|https?:)/.test(p)) return p;              // already fetchable as-is
    const abs = path.resolve(dir, p);
    const mime = MIME[path.extname(abs).toLowerCase()] || 'application/octet-stream';
    return `data:${mime};base64,${fs.readFileSync(abs).toString('base64')}`;
  };
  const map = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
  const out = {};
  for (const [name, bank] of Object.entries(map)) {
    if (name.startsWith('_')) continue;                    // paths are pre-resolved; _base/_doc would misregister as sounds
    if (typeof bank === 'string') out[name] = toDataUri(bank);
    else if (Array.isArray(bank)) out[name] = bank.map(toDataUri);
    else out[name] = Object.fromEntries(Object.entries(bank).map(([note, v]) =>
      [note, (Array.isArray(v) ? v : [v]).map(toDataUri)]));
  }
  return out;
}
const RESOLVED_SAMPLE_MAPS = SAMPLE_MAPS.map((m) =>
  m.endsWith('.json') && fs.existsSync(m) ? loadLocalSampleMap(m) : m);

// ---- read code; parse & strip setcps/setcpm (they throw in the headless scope) ----
let code = fs.readFileSync(codeFile, 'utf8');
const mcps = code.match(/setcps\s*\(\s*([0-9.]+)\s*\)/);
const mcpm = code.match(/setcpm\s*\(\s*([0-9.]+)\s*\)/);
if (mcps) CPS = Number(mcps[1]);
else if (mcpm) CPS = Number(mcpm[1]) / 60;               // cycles per minute -> per second
if (process.argv.indexOf('--cps') >= 0) CPS = argNum('--cps', CPS);   // explicit CLI --cps wins
code = code.replace(/setcp[sm]\s*\([^)]*\)\s*;?/g, '');   // strip so evaluate() doesn't throw
const SPC = 1 / CPS;                                      // seconds per cycle

// ---- TIER A: parse + query real Strudel events ----
const { pattern } = await evaluate(code);
const haps = pattern.queryArc(0, CYCLES).filter((h) => h.hasOnset && h.hasOnset());

const KNOWN_OSC = new Set(['sine', 'sawtooth', 'square', 'triangle']);
const SYNTH_SET = new Set([...KNOWN_OSC, 'zzfx', 'z_sine', 'z_sawtooth', 'z_triangle', 'z_square', 'z_tan', 'z_noise',
  'white', 'pink', 'brown', 'crackle', 'supersaw', 'pulse', 'sawtooth', 'gm']);
const isSynth = (s) => !s || SYNTH_SET.has(s) || s.startsWith('z_') || s.startsWith('wt_');
const isSoundfont = (s) => typeof s === 'string' && s.startsWith('gm_');

// pull the control vocabulary off each hap. IMPORTANT: haps store the CANONICAL control name
// (first element of registerControl's array in @strudel/core/controls.mjs), not the alias you
// type: .fm(4) -> value.fmi (controls.mjs:211), .lpf() -> cutoff (:546), .hpf() -> hcutoff (:833),
// .size() -> roomsize (:1316). 'size' is also kept because .room("a:b") stores the 2nd list
// element under literal 'size' (:1248). Curated whitelist -- controls superdough actually consumes.
const CONTROLS = ['note', 's', 'bank', 'gain', 'velocity', 'pan', 'cutoff', 'resonance', 'hcutoff', 'hresonance',
  'bandf', 'bandq', 'room', 'roomsize', 'size', 'roomfade', 'delay', 'delaytime', 'delayfeedback', 'attack', 'decay',
  'sustain', 'release', 'crush', 'coarse', 'shape', 'distort', 'speed', 'vowel', 'n', 'freq', 'vib', 'vibmod',
  'fmi', 'fmh', 'fmenv', 'fmattack', 'fmdecay', 'fmsustain',      // FM family (canonical: fmi, not 'fm')
  'clip', 'duration',                                             // event-length semantics (hap.duration)
  'unison', 'spread', 'detune', 'noise', 'ftype', 'postgain', 'orbit',  // supersaw / filter type / routing
  'lpenv', 'lpattack', 'lpdecay', 'lpsustain', 'lprelease',       // lowpass filter envelope
  'penv', 'pattack', 'pdecay', 'prelease',                        // pitch envelope
  'begin', 'end', 'cut', 'loop'];                                 // sample playback

const events = [];
const gmNeeded = new Set();
const sampleSoundsUsed = new Set();
for (const h of haps) {
  const w = h.whole || h.part;
  const v = h.value || {};
  const s = v.s;
  if (s && ['~', '-', '_'].includes(s)) continue;
  let hz = null;
  try { hz = core.getFrequency(h); } catch { hz = null; }   // quick-win: correct MIDI-vs-Hz
  const beginCyc = w.begin.valueOf();
  // hap.duration (not whole.end - whole.begin) reproduces the engine's clip/legato/duration
  // semantics exactly (@strudel/core/hap.mjs:35-46); webaudio passes hap.duration/cps to superdough.
  let durCyc;
  try { durCyc = h.duration.valueOf(); } catch { durCyc = w.end.valueOf() - beginCyc; }
  const rec = {
    begin_s: +(beginCyc * SPC).toFixed(4),
    dur_s: +(durCyc * SPC).toFixed(4),
    begin_cycle: +beginCyc.toFixed(4),
    hz: hz ? +hz.toFixed(2) : null,
    wave: KNOWN_OSC.has(s) ? s : (isSynth(s) ? (s || 'triangle') : null),
    kind: isSoundfont(s) ? 'soundfont' : (isSynth(s) ? 'synth' : 'sample'),
  };
  for (const c of CONTROLS) if (v[c] !== undefined) rec[c] = v[c];
  events.push(rec);
  if (isSoundfont(s)) gmNeeded.add(s);
  else if (!isSynth(s)) sampleSoundsUsed.add(s);
}
events.sort((a, b) => a.begin_s - b.begin_s || (a.hz || 0) - (b.hz || 0));

// sounds whose randomness lives INSIDE the AudioWorklet thread (separate realm -- the seeded
// Math.random above can't reach it): supersaw voice phases, wt_* wavetable phases. Renders using
// them are NOT byte-reproducible even with a fixed --seed; flag so downstream never caches/compares.
const nondetSounds = [...new Set(events.map((e) => e.s).filter((s) => s === 'supersaw' || (typeof s === 'string' && s.startsWith('wt_'))))];
if (nondetSounds.length) console.error(`WARNING: sounds [${nondetSounds.join(', ')}] randomize phase inside the AudioWorklet realm -- --seed does NOT make this render byte-reproducible.`);
// NOTE: events.json is written AFTER the render loop (only events that actually rendered),
// so diff_notes never scores notes that are silent in the WAV.

// ---- TIER B: real superdough offline render ----
// FX-tail-aware duration: reverb tail ~ roomsize seconds (superdough/reverb.mjs IR length,
// default 2 s) + roomfade (default 0.5 s); delay tail is feedback-derived: each echo repeats
// every delaytime seconds, decaying by a factor delayfeedback, starting at ~wet-send level, so
// the tail is n*delaytime where n echoes bring wet*fb^n under -60 dBFS (1e-3). superdough
// defaults (node_modules/superdough/superdough.mjs:193-194,503): delayfeedback 0.5, delaytime =
// delaysync (3/16 cycle) / cps. Floor at the full requested pattern length (CYCLES/CPS) and at
// last event end + release + 0.3.
const DELAY_TAIL_CAP = 10; // s; bounds verify-loop render length for extreme feedback (fb->0.98)
let delayCapHit = false;   // cap engaged => echo train is still ABOVE the -60 dB floor at EOF by
                           // construction (the -60 dB point lies beyond the cap) -> loud tail is
                           // designed truncation, not a stuck note; detection below must not retry
const lastEnd = events.reduce((m, e) => Math.max(m, e.begin_s + e.dur_s + (e.release ?? 0.1)), 0);
const fxEnd = events.reduce((m, e) => {
  const roomTail = e.room > 0 ? (e.roomsize ?? e.size ?? 2) + (e.roomfade ?? 0.5) : 0;
  let delayTail = 0;
  if (e.delay > 0) {
    const wet = Math.max(e.delay, 0.001);   // wet-send level of first echo; superdough doesn't clamp
                                            // the send above 1, and DELAY_TAIL_CAP bounds extremes
    const fb = Math.min(Math.max(e.delayfeedback ?? 0.5, 0), 0.98); // cap <1 so the log converges
    const dt = e.delaytime ?? (3 / 16) / CPS;                     // superdough.mjs:194,503 default
    if (!Number.isFinite(fb) || !Number.isFinite(dt) || dt <= 0) {
      delayTail = 2; // degenerate delaytime/feedback -> old flat 2 s fallback
    } else {
      const n = fb > 0 ? Math.max(1, Math.ceil(Math.log(0.001 / wet) / Math.log(fb))) : 1;
      if (n * dt > DELAY_TAIL_CAP) delayCapHit = true;
      delayTail = Math.min(n * dt, DELAY_TAIL_CAP);
    }
  }
  return Math.max(m, e.begin_s + e.dur_s + (e.release ?? 0.1) + Math.max(roomTail, delayTail));
}, 0);
const totalDur = Math.max(CYCLES / CPS, lastEnd + 0.3, fxEnd + 0.2);

// One full render pass, self-contained so it can be re-run on a stuck note: fresh
// OfflineAudioContext (a poisoned context can't be reused), re-init superdough on it,
// re-load samples/soundfonts (ensureSoundfonts is disk-cached -- cheap on retry), and
// re-schedule EVERY event. Per-event failure tracking (rendered/failed/__ok) is reset
// per attempt so events.json + WARNING reflect the FINAL attempt only.
async function renderAttempt(tryNo) {
  // re-seed FIRST: superdough draws from Math.random during every attempt's scheduling (chainID
  // per event, reverb IR samples, noise buffers, zzfx), so without this a retry would start from
  // an advanced RNG state and produce bytes differing from a clean single-attempt run. (Safe to
  // re-seed before the retry's re-import too: superdough draws nothing at module init.)
  Math.random = mulberry32(SEED);
  // retries need a FRESH superdough module (cache-busted URL): its module-scope controller +
  // node pools stay bound to the previous attempt's context (see import note above) and would
  // fail every event on the new context. Attempt 0 keeps the base import.
  if (tryNo > 0) sd = await import(`${SD_URL}?attempt=${tryNo}`);
  const ctx = new nwa.OfflineAudioContext(2, Math.ceil(SR * totalDur), SR);
  sd.setAudioContext(ctx);
  await sd.initAudio();
  sd.registerSynthSounds();

  // load sample bank(s) if the code uses sample sounds / drums
  let samplesLoaded = false;
  if (sampleSoundsUsed.size && !hasFlag('--no-samples')) {
    for (const m of RESOLVED_SAMPLE_MAPS) {
      try { await sd.samples(m); samplesLoaded = true; }
      catch (e) { console.warn('[samples] load failed:', e.message.split('\n')[0]); }
    }
  }
  // register any gm_ soundfonts referenced (Phase 3)
  let sfLoaded = 0;
  if (gmNeeded.size) {
    try { sfLoaded = await ensureSoundfonts([...gmNeeded], sd, ctx); }
    catch (e) { console.warn('[soundfonts] load failed:', e.message.split('\n')[0]); }
  }

  // schedule every hap through superdough
  let rendered = 0;
  const failed = [];
  for (const e of events) {
    delete e.__ok;                                          // reset per attempt, don't accumulate
    const v = {};
    for (const c of CONTROLS) if (e[c] !== undefined) v[c] = e[c];
    if (e.hz && v.note === undefined && v.freq === undefined && v.n === undefined) v.freq = e.hz;
    if (v.s === undefined && e.wave) v.s = e.wave;
    try { await sd.superdough(v, e.begin_s, e.dur_s, CPS, e.begin_cycle); rendered++; e.__ok = true; }
    catch (err) {
      failed.push({ begin_s: e.begin_s, s: v.s ?? null, note: v.note ?? null, hz: e.hz ?? null,
        err: err.message.split('\n')[0] });
    }
  }

  // drain inner offline renders (reverb IR lowpass) BEFORE the main render, then yield one
  // macrotask so their oncomplete handlers run and attach the convolver buffers (see wrap above)
  while (pendingOfflineRenders.size) {
    await Promise.all([...pendingOfflineRenders]);
    await new Promise((r) => setImmediate(r));
  }
  await new Promise((r) => setImmediate(r));

  const buf = await ctx.startRendering();
  // stereo interleave via copyFromChannel (getChannelData flagged unreliable in node-web-audio-api)
  const L = new Float32Array(buf.length), R = new Float32Array(buf.length);
  buf.copyFromChannel(L, 0);
  buf.copyFromChannel(R, buf.numberOfChannels > 1 ? 1 : 0);
  return { buf, L, R, failed, rendered, samplesLoaded, sfLoaded };
}

// ---- stuck-note detection + retry ----
// Rare node-web-audio-api race (seen ~1-in-3 under CPU load): a note's release/stop is dropped
// and its oscillator drones at CONSTANT RMS (~0.08) from mid-file to EOF, poisoning any spectral
// score. Detection matches that exact signature -- loud tail AND flat (tail RMS ~= RMS 1.5 s
// earlier) -- because loud alone false-positives on tails that are loud at EOF BY DESIGN:
// (1) delay tails truncated by DELAY_TAIL_CAP (cap engaging MEANS the -60 dB point lies beyond
//     the cap, so EOF level is above the 1e-3 floor -- e.g. fb 0.9, dt 0.375 leaves ~6% of signal
//     at 10 s); handled via delayCapHit -> never retried, reported as tail_truncated instead;
// (2) long one-shot samples (crash/ride, gm_ releases) ringing past the dur_s-based totalDur;
//     those DECAY across 1.5 s (fb<=0.77 fits under the cap at default dt -> ratio <=~0.66, cymbals
//     ~-3 dB/s -> ~0.6), while a stuck oscillator holds ratio ~1.0 -- the flatness gate splits them.
const MAX_RENDER_RETRIES = 2;      // extra attempts after the first render comes back stuck
const STUCK_TAIL_RMS = 2e-3;       // absolute CEILING: a tail above this is never considered clean
const STUCK_REL_FACTOR = 0.01;     // ...but quiet renders get a stricter, level-relative trigger:
const STUCK_ABS_FLOOR = 1e-4;      // a QUIET stuck note (low-gain instrument) drones below the
                                   // absolute ceiling and evades it (observed: gm_contrabass solo
                                   // droned at 1.1e-3 < 2e-3, undetected). Effective threshold =
                                   // min(CEILING, max(FLOOR, REL_FACTOR * whole-file body RMS)) --
                                   // a drone is caught relative to its own render's level, while
                                   // the floor keeps dither/denormal noise from ever tripping it.
const TAIL_WINDOW_S = 0.15;        // window at EOF over which tail RMS is measured. MUST stay
                                   // under the 0.2 s margin totalDur guarantees past fxEnd --
                                   // a wider window overlaps designed sound on short renders
                                   // (verified: 0.5 s false-flagged a clean 2.4 s render)
const FLAT_GAP_S = 1.5;            // reference window ends this far before EOF
const FLAT_RATIO_MIN = 0.8;        // tail/ref inside [MIN,MAX] => constant plateau, not a decay
const FLAT_RATIO_MAX = 1.25;
const rmsWin = (a, backFromEof) => {  // RMS of [EOF-backFromEof, EOF-backFromEof+TAIL_WINDOW_S)
  const start = Math.max(0, a.buf.length - Math.round(backFromEof * SR));
  const end = Math.min(a.buf.length, start + Math.max(1, Math.round(TAIL_WINDOW_S * SR)));
  let acc = 0;
  for (let i = start; i < end; i++) { const m = (a.L[i] + a.R[i]) / 2; acc += m * m; }
  return Math.sqrt(acc / Math.max(1, end - start));
};
const bodyRmsOf = (a) => {          // whole-file mono RMS; a drone only RAISES it, and the
  let acc = 0;                      // threshold factor < 1 keeps detection self-consistent
  for (let i = 0; i < a.buf.length; i++) { const m = (a.L[i] + a.R[i]) / 2; acc += m * m; }
  return Math.sqrt(acc / Math.max(1, a.buf.length));
};
let attempt, tailRms, stuckThresh, renderRetries = 0, stuck = false, tailTruncated = false;
for (let tryNo = 0; ; tryNo++) {
  attempt = await renderAttempt(tryNo);
  tailRms = rmsWin(attempt, TAIL_WINDOW_S);
  stuckThresh = Math.min(STUCK_TAIL_RMS, Math.max(STUCK_ABS_FLOOR, STUCK_REL_FACTOR * bodyRmsOf(attempt)));
  if (tailRms <= stuckThresh) break;                        // clean tail -> done
  if (delayCapHit) {                                        // loud at EOF by design -> not stuck
    tailTruncated = true;
    console.error(`[render] tail RMS ${tailRms.toExponential(2)} at EOF but DELAY_TAIL_CAP truncated ` +
      `a delay tail -- designed truncation, not a stuck note; no retry.`);
    break;
  }
  // flatness gate needs disjoint windows; renders shorter than gap+2 windows can't provide a
  // reference, so fall back to loud-only => treat as stuck (such short renders are cheap to retry)
  const refRms = attempt.buf.length >= Math.round((FLAT_GAP_S + 2 * TAIL_WINDOW_S) * SR)
    ? rmsWin(attempt, TAIL_WINDOW_S + FLAT_GAP_S) : tailRms;
  const ratio = refRms > 0 ? tailRms / refRms : Infinity;
  if (ratio < FLAT_RATIO_MIN || ratio > FLAT_RATIO_MAX) {   // decaying/rising tail -> truncation
    tailTruncated = true;
    console.error(`[render] loud but decaying tail at EOF (RMS ${tailRms.toExponential(2)}, ` +
      `ratio ${ratio.toFixed(2)} vs ${FLAT_GAP_S}s earlier) -- truncated FX/sample tail, not a stuck note; no retry.`);
    break;
  }
  if (tryNo >= MAX_RENDER_RETRIES) {                        // out of attempts: keep last audio
    stuck = true;
    console.error(`WARNING: STUCK NOTE persisted after ${1 + MAX_RENDER_RETRIES} render attempts ` +
      `(tail RMS ${tailRms.toExponential(2)} > ${stuckThresh.toExponential(2)}, flat ratio ${ratio.toFixed(2)}) -- ` +
      `WAV has a droning oscillator; spectral scores from it are NOT trustworthy.`);
    break;
  }
  renderRetries++;
  console.error(`[render] stuck note detected (tail RMS ${tailRms.toExponential(2)}, flat ratio ${ratio.toFixed(2)}); retry ${renderRetries}/${MAX_RENDER_RETRIES}...`);
}
const { buf, L, R, failed, rendered, samplesLoaded, sfLoaded } = attempt;

// write events.json ONLY with events that actually made it into the WAV (final attempt)
const okEvents = events.filter((e) => e.__ok);
for (const e of okEvents) delete e.__ok;
fs.writeFileSync(outWav + '.events.json', JSON.stringify(okEvents, null, 2));
if (failed.length) {
  console.error(`WARNING: ${failed.length}/${events.length} events FAILED to render -- the WAV is missing notes! ` +
    `events.json excludes them. First failure: ${failed[0].err}`);
}

const N = buf.length;
const bytes = Buffer.alloc(44 + N * 2 * 2);
bytes.write('RIFF', 0); bytes.writeUInt32LE(36 + N * 4, 4); bytes.write('WAVE', 8);
bytes.write('fmt ', 12); bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20);
bytes.writeUInt16LE(2, 22); bytes.writeUInt32LE(SR, 24); bytes.writeUInt32LE(SR * 4, 28);
bytes.writeUInt16LE(4, 32); bytes.writeUInt16LE(16, 34);
bytes.write('data', 36); bytes.writeUInt32LE(N * 4, 40);
let peak = 0;
for (let i = 0; i < N; i++) {
  let l = Math.max(-1, Math.min(1, L[i])), r = Math.max(-1, Math.min(1, R[i]));
  peak = Math.max(peak, Math.abs(l), Math.abs(r));
  bytes.writeInt16LE((l < 0 ? l * 0x8000 : l * 0x7fff) | 0, 44 + i * 4);
  bytes.writeInt16LE((r < 0 ? r * 0x8000 : r * 0x7fff) | 0, 44 + i * 4 + 2);
}
fs.writeFileSync(outWav, bytes);

console.log(JSON.stringify({
  engine: 'superdough@offline', cycles: CYCLES, cps: +CPS.toFixed(4), seconds_per_cycle: +SPC.toFixed(4),
  events: events.length, rendered, skipped: failed.length,
  samples_loaded: samplesLoaded, sample_sounds: [...sampleSoundsUsed], soundfonts_loaded: sfLoaded,
  peak: +peak.toFixed(4), duration_s: +totalDur.toFixed(2), wav: outWav, events_json: outWav + '.events.json',
  failed: failed.slice(0, 10),
  tail_rms: +tailRms.toExponential(4),      // RMS of final TAIL_WINDOW_S of the mono mix
  render_retries: renderRetries,            // extra render attempts consumed by stuck-note retry
  stuck: stuck,                             // true = droning note survived all attempts; distrust WAV
  tail_truncated: tailTruncated,            // true = loud EOF tail is designed truncation (delay cap / long one-shot), WAV is fine
  nondeterministic_sounds: nondetSounds,    // worklet-realm randomness: --seed can't make these byte-reproducible
}, null, 2));
