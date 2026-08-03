// soundfont_loader.mjs -- register General MIDI (gm_*) soundfont instruments into superdough
// for headless OFFLINE rendering (Phase 3 of the superdough upgrade).
//
// Ported from @strudel/soundfonts@1.1.0/fontloader.mjs but WITHOUT importing @strudel/webaudio
// (which risks running browser code in Node). The ADSR/vibrato/pitch helpers it needs are the
// SAME functions superdough already exports, so we take them from the live `sd` module.
//
// Preset .js files are fetched once from the webaudiofont CDN and cached to scripts/.sfcache/
// so the verify loop renders offline on subsequent runs.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { noteToMidi, freqToMidi, getSoundIndex } from '@strudel/core';
import gmMod from '@strudel/soundfonts/gm.mjs';

const gm = gmMod.default || gmMod;
const CACHE_DIR = path.join(path.dirname(fileURLToPath(import.meta.url)), '.sfcache');

// A real webaudiofont preset is `...var _tone_XXX={zones:[...]};`. Most are 100 kB+, but
// legit one-zone presets exist (1080_JCLive kalimba = 6 kB), so the length floor stays at 1 kB
// just to reject empty/error bodies -- the '={'/'zones' shape check plus parseZones (must eval
// to a non-empty zones array) are the real gate. Validate BEFORE trusting or caching.
const validPresetText = (txt) =>
  typeof txt === 'string' && txt.length > 1024 && txt.includes('={') && txt.includes('zones');

function parseZones(txt, file) {
  const [, data] = txt.split('={');
  // labeled-statement trick: `{ zones:[...] }` evaluates to the zones array
  const zones = eval('{' + data);
  if (!Array.isArray(zones) || zones.length === 0) throw new Error(`soundfont ${file}: parsed preset has no zones`);
  return zones;
}

async function fetchFont(file) {
  const url = `https://felixroos.github.io/webaudiofontdata/sound/${file}.js`;
  const r = await fetch(url);
  if (!r.ok) throw new Error(`soundfont ${file}: HTTP ${r.status} fetching ${url}`);
  const txt = await r.text();
  if (!validPresetText(txt)) {
    throw new Error(`soundfont ${file}: invalid preset payload from ${url} (length ${txt.length}) -- NOT caching`);
  }
  return txt;
}

const presetCache = {};
async function loadFont(file) {
  if (presetCache[file]) return presetCache[file];
  presetCache[file] = (async () => {
    const cachePath = path.join(CACHE_DIR, file + '.js');
    if (fs.existsSync(cachePath)) {
      const cached = fs.readFileSync(cachePath, 'utf8');
      if (validPresetText(cached)) {
        try {
          return parseZones(cached, file);
        } catch (e) {
          console.warn(`[soundfonts] corrupt cache ${cachePath} (${e.message.split('\n')[0]}) -- deleting, re-fetching`);
        }
      } else {
        console.warn(`[soundfonts] invalid cache ${cachePath} (length ${cached.length}) -- deleting, re-fetching`);
      }
      try { fs.unlinkSync(cachePath); } catch {}
    }
    const txt = await fetchFont(file); // throws loudly on bad HTTP/payload; nothing gets cached
    const zones = parseZones(txt, file); // parse-validate BEFORE writing the cache file
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    fs.writeFileSync(cachePath, txt);
    return zones;
  })();
  // failed loads must be retryable: drop the rejected promise so the next call re-fetches
  presetCache[file].catch(() => { delete presetCache[file]; });
  return presetCache[file];
}

const bufferCache = {};
async function getFontPitch(file, pitch, ac) {
  const key = `${file}:::${pitch}`;
  if (bufferCache[key]) return bufferCache[key];
  bufferCache[key] = (async () => {
    const zones = await loadFont(file);
    const zone = zones.find((z) => z.keyRangeLow <= pitch && z.keyRangeHigh + 1 >= pitch) || zones[0];
    const decoded = atob(zone.file);
    const arraybuffer = new ArrayBuffer(decoded.length);
    const view = new Uint8Array(arraybuffer);
    for (let i = 0; i < decoded.length; i++) view[i] = decoded.charCodeAt(i);
    const buffer = await new Promise((resolve, reject) => ac.decodeAudioData(arraybuffer, resolve, reject));
    return { buffer, zone };
  })();
  // failed decodes/loads must be retryable: drop the rejected promise so the next call retries
  bufferCache[key].catch(() => { delete bufferCache[key]; });
  return bufferCache[key];
}

async function getFontBufferSource(file, value, ac) {
  const { note = 'c3', freq } = value;
  const midi = freq ? freqToMidi(freq) : typeof note === 'string' ? noteToMidi(note) : note;
  const { buffer, zone } = await getFontPitch(file, midi, ac);
  const src = ac.createBufferSource();
  src.buffer = buffer;
  const baseDetune = zone.originalPitch - 100.0 * zone.coarseTune - zone.fineTune;
  src.playbackRate.value = Math.pow(2, (100.0 * midi - baseDetune) / 1200.0);
  if (zone.loopStart > 1 && zone.loopStart < zone.loopEnd) {
    src.loop = true;
    src.loopStart = zone.loopStart / zone.sampleRate;
    src.loopEnd = zone.loopEnd / zone.sampleRate;
  }
  return src;
}

// Register the requested gm_* instruments as superdough sounds. Returns how many registered.
export async function ensureSoundfonts(gmNames, sd, ctx) {
  let count = 0;
  for (const name of gmNames) {
    const fonts = gm[name];
    if (!fonts) { console.warn('[soundfonts] unknown instrument:', name); continue; }
    // warm the cache for c3 so the first fetch/decode is done up front (offline safety)
    try { await getFontPitch(fonts[0], 48, ctx); } catch (e) { console.warn('[soundfonts] preload', name, e.message.split('\n')[0]); }
    sd.registerSound(
      name,
      async (time, value, onended) => {
        const [attack, decay, sustain, release] = sd.getADSRValues([value.attack, value.decay, value.sustain, value.release]);
        const { duration = 0.5 } = value;
        const n = getSoundIndex(value.n, fonts.length);
        const bufferSource = await getFontBufferSource(fonts[n], value, ctx);
        bufferSource.start(time);
        const envGain = ctx.createGain();
        const node = bufferSource.connect(envGain);
        const holdEnd = time + duration;
        sd.getParamADSR(node.gain, attack, decay, sustain, release, 0, 0.3, time, holdEnd, 'linear');
        const envEnd = holdEnd + release + 0.01;
        try { sd.getVibratoOscillator?.(bufferSource.detune, value, time); } catch {}
        try { sd.getPitchEnvelope?.(bufferSource.detune, value, time, holdEnd); } catch {}
        bufferSource.stop(envEnd);
        bufferSource.onended = () => { try { bufferSource.disconnect(); node.disconnect(); } catch {} onended(); };
        return { node, stop: () => {} };
      },
      { type: 'soundfont', prebake: true, fonts },
    );
    count++;
  }
  return count;
}
