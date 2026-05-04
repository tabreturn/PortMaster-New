const TILE = 9;
const STAGE_W = 15;
const STAGE_H = 15;
const SCALE = 3;
const GAME_W = STAGE_W * TILE * SCALE;
const GAME_H = STAGE_H * TILE * SCALE;

const canvas = document.getElementById('game-canvas');
const ctx = canvas.getContext('2d');
canvas.width = GAME_W;
canvas.height = GAME_H;
ctx.imageSmoothingEnabled = false;

let game = null;
let currentStage = null;
let currentStageId = null;
let heroX, heroY;
let heroSkin = null;
let frameCounter = 0;
let gameVars = {};       // runtime variable storage
let seqCounters = {};    // sequential branch counters
let touchedIdx = -1;     // tile index of current interaction
let inputCooldown = 0;
let audioCtx = null;

// Menu state
let gameFiles = [];
let selectedIdx = 0;
let state = 'menu';
let menuInputCooldown = 0;
let menuScroll = 0;
const MENU_VISIBLE = 12;

// Dialog state
let dialogText = '';
let dialogActive = false;

const tileCache = {};
const keys = {};
const prevKeys = {};
window.addEventListener('keydown', e => { keys[e.key] = true; });
window.addEventListener('keyup', e => { keys[e.key] = false; });

// --- Audio engine ---

function createNoiseBuffer(ctx, duration) {
  const sr = ctx.sampleRate;
  const len = Math.ceil(sr * Math.min(Math.max(duration, 0.01), 2));
  const buf = ctx.createBuffer(1, len, sr);
  const d = buf.getChannelData(0);
  for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
  return buf;
}

function adsr(gain, now, t, a, h, d, s, r) {
  const att = a || 0.005, hld = h || 0, dec = d || 0, sus = s !== undefined ? s : 1, rel = r || 0.01;
  const v = gain.gain;
  v.setValueAtTime(0, now);
  v.linearRampToValueAtTime(1, now + att);
  if (hld > 0) v.setValueAtTime(1, now + att + hld);
  v.linearRampToValueAtTime(sus, now + att + hld + dec);
  v.linearRampToValueAtTime(0, now + att + hld + dec + rel);
}

function parseMod(val, now, ctx) {
  if (typeof val === 'number') return { v: val };
  if (typeof val === 'object') {
    if (val.t !== undefined) return { v: val.t };
    if (val.f !== undefined || val.freq !== undefined) {
      const lfo = ctx.createOscillator();
      lfo.type = 'sine';
      lfo.frequency.value = (val.freq !== undefined ? val.freq : val.f) || 1;
      const lg = ctx.createGain();
      lg.gain.value = val.gain || 0;
      lfo.connect(lg); lfo.start(now); lfo.stop(now + 5);
      return { v: null, lfo: lg };
    }
    if (typeof val.w === 'number') return { v: val.w };
    return { v: 0 };
  }
  return { v: 0 };
}

function playCue(cue) {
  if (!cue || !audioCtx) return;
  const now = audioCtx.currentTime;
  const dur = cue.duration || 0.3;
  const vel = (cue.velocity || 0.7) * 0.6;
  const rand = cue.randomness || 0;
  const baseFreq = (cue.freq || 440) * (1 + (Math.random() - 0.5) * rand);

  const prog = Array.isArray(cue.program) ? cue.program : [cue.program];
  let last = null;

  for (const step of prog) {
    const type = step.type || '';

    if (type === 'n0' || type === 'np' || type === 'nb') {
      const buf = createNoiseBuffer(audioCtx, dur);
      const src = audioCtx.createBufferSource();
      src.buffer = buf; src.loop = true;
      const ng = audioCtx.createGain();
      ng.gain.value = vel * 0.4;
      src.connect(ng); last = ng;
      src.start(now); src.stop(now + dur + 0.05);
      if (step.gain) adsr(ng, now, step.gain.t, step.gain.a, step.gain.h, step.gain.d, step.gain.s, step.gain.r);
    } else if (type === 'sine' || type === 'square' || type === 'triangle') {
      const osc = audioCtx.createOscillator();
      osc.type = type;
      const freqSpec = step.freq;
      // freq can be: number, {t}, {w,p,q} modulation, or array of {w,p,q}
      if (Array.isArray(freqSpec) && freqSpec.length > 0 && typeof freqSpec[0] === 'object' && freqSpec[0].p !== undefined) {
        // Use first entry: p = pitch multiplier, w = vibrato rate, q = vibrato depth
        const spec = freqSpec[0];
        osc.frequency.value = baseFreq * (spec.p || 1);
        if (spec.w > 0) {
          const lfo = audioCtx.createOscillator();
          lfo.frequency.value = spec.w * 10;
          const lfoGain = audioCtx.createGain();
          lfoGain.gain.value = baseFreq * (spec.q || 0.01);
          lfo.connect(lfoGain);
          lfoGain.connect(osc.frequency);
          lfo.start(now); lfo.stop(now + dur + 0.05);
        }
      } else {
        const m = parseMod(freqSpec || baseFreq, now, audioCtx);
        if (m.v && typeof m.v === 'number') osc.frequency.value = m.v;
        if (m.lfo) m.lfo.connect(osc.frequency);
      }
      const og = audioCtx.createGain();
      og.gain.value = vel;
      osc.connect(og); last = og;
      osc.start(now); osc.stop(now + dur + 0.05);
      if (step.gain) adsr(og, now, step.gain.t, step.gain.a, step.gain.h, step.gain.d, step.gain.s, step.gain.r);
    } else if (type === 'lowpass' || type === 'highpass') {
      if (!last) continue;
      const f = audioCtx.createBiquadFilter();
      f.type = type;
      const m = parseMod(step.freq || 1000, now, audioCtx);
      if (m.v) f.frequency.value = m.v;
      if (m.lfo) m.lfo.connect(f.frequency);
      if (step.Q) f.Q.value = step.Q;
      last.connect(f); last = f;
    }
  }

  if (last && last !== audioCtx.destination) last.connect(audioCtx.destination);
}

function playCueById(id) {
  if (!game || !game.cuesById || !id) return;
  const cue = game.cuesById[id];
  if (cue) playCue(cue);
}

function playMenuChime() {
  if (!audioCtx) return;
  const now = audioCtx.currentTime;
  [440, 660].forEach((freq, i) => {
    const osc = audioCtx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    const g = audioCtx.createGain();
    g.gain.setValueAtTime(0, now + i * 0.08);
    g.gain.linearRampToValueAtTime(0.15, now + i * 0.08 + 0.01);
    g.gain.linearRampToValueAtTime(0, now + i * 0.08 + 0.12);
    osc.connect(g); g.connect(audioCtx.destination);
    osc.start(now + i * 0.08); osc.stop(now + i * 0.08 + 0.15);
  });
}

// --- Scenario Engine ---

let pendingScenario = null;
let confirmActive = false;
let confirmText = '';
let confirmYes = 'Yes';
let confirmNo = 'No';
let confirmSelection = 0;

let dialogType = 'say'; // 'say' or 'message'

function formatText(raw) {
  // Variable interpolation FIRST: ${variable name}
  let text = raw.replace(/\$\{([^}]+)\}/g, (_, varName) => {
    if (!game || !game.variables) return '0';
    const vars = Array.isArray(game.variables) ? game.variables : Object.entries(game.variables).map(([id, v]) => ({id, ...v}));
    const v = vars.find(x => x.name === varName);
    return v ? String(getVar(v.id)) : '0';
  });
  // Random choice: {a|b|c}
  text = text.replace(/\{([^}]+)\}/g, (_, opts) => {
    const choices = opts.split('|');
    return choices[Math.floor(Math.random() * choices.length)];
  });
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<[^>]+>/g, '');
  text = text.replace(/ *\n */g, '\n').trim();
  return text;
}

function initVars() {
  gameVars = {};
  seqCounters = {};
  if (!game || !game.variables) return;
  if (Array.isArray(game.variables)) {
    for (const v of game.variables) gameVars[v.id] = v.initialValue;
  } else {
    for (const [id, v] of Object.entries(game.variables)) gameVars[id] = v.initialValue;
  }
}

function getVar(id) { return gameVars[id] !== undefined ? gameVars[id] : 0; }
function setVar(id, val) { gameVars[id] = val; }

function resolveData(actor, node, inputName) {
  const edge = node.dataEdges?.[inputName];
  if (!edge) return node.values?.[inputName.split('-').pop()] ?? 0;
  const srcNode = actor.scenario?.[edge.node];
  if (!srcNode) return 0;
  return evalNode(actor, srcNode, edge.handle);
}

function evalNode(actor, node, outputHandle) {
  switch (node.code) {
    case 'getVariable':
      return getVar(node.values?.variable);
    case 'compare': {
      const a = resolveData(actor, node, 'number-a');
      const b = node.values?.b ?? 0;
      const op = node.values?.operand || '==';
      let result = false;
      switch (op) {
        case '>': result = a > b; break;
        case '<': result = a < b; break;
        case '>=': result = a >= b; break;
        case '<=': result = a <= b; break;
        case '==': result = a === b; break;
        case '!=': result = a !== b; break;
      }
      return result;
    }
    default:
      return node.values?.[outputHandle?.split('-').pop()] ?? 0;
  }
}

function removeFromStage(targetId, stg) {
  for (let i = 0; i < stg.actors.length; i++) if (stg.actors[i] === targetId) stg.actors[i] = -1;
  for (let i = 0; i < stg.background.length; i++) if (stg.background[i] === targetId) stg.background[i] = -1;
  for (let i = 0; i < stg.foreground.length; i++) if (stg.foreground[i] === targetId) stg.foreground[i] = -1;
}

function removeFromAllStages(targetId) {
  for (const stg of game.stages) removeFromStage(targetId, stg);
}

function replaceInStage(fromId, toId, stg) {
  for (let i = 0; i < stg.actors.length; i++) if (stg.actors[i] === fromId) stg.actors[i] = toId;
}

function replaceInAllStages(fromId, toId) {
  for (const stg of game.stages) replaceInStage(fromId, toId, stg);
}

let signalDepth = 0;

function broadcastSignal(signalName) {
  if (signalDepth > 5) return;
  signalDepth++;
  const allEntities = [...Object.values(game.actorsById), ...Object.values(game.propsById)];
  for (const entity of allEntities) {
    if (!entity.scenario) continue;
    for (const [nid, node] of Object.entries(entity.scenario)) {
      if (node.code === 'signal' && node.values?.signal === signalName) {
        const next = node.execEdges?.['exec-next'];
        if (next) runChain(entity.id, next);
      }
    }
  }
  signalDepth--;
}

function execNode(actor, node, nodeId) {
  switch (node.code) {
    case 'touch': case 'signal': break;
    case 'cue': playCueById(node.values?.cue); break;
    case 'say': case 'message':
      dialogText = formatText(node.values?.text || '');
      dialogType = node.code;
      dialogActive = true;
      return 'pause';
    case 'confirm':
      confirmText = formatText(node.values?.text || '');
      confirmYes = node.values?.yesLabel || 'Yes';
      confirmNo = node.values?.noLabel || 'No';
      confirmActive = true;
      confirmSelection = 0;
      return 'confirm';
    case 'waitForInput':
      dialogText = '';
      dialogActive = true;
      return 'pause';
    case 'sleep': break; // skip delay on handheld
    case 'exit':
      dialogText = 'THE END';
      dialogActive = true;
      pendingScenario = null;
      return 'pause';
    case 'destroySelf':
      if (touchedIdx >= 0) {
        if (currentStage.actors[touchedIdx] === actor.id) currentStage.actors[touchedIdx] = -1;
        if (currentStage.background[touchedIdx] === actor.id) currentStage.background[touchedIdx] = -1;
        if (currentStage.foreground[touchedIdx] === actor.id) currentStage.foreground[touchedIdx] = -1;
      } else {
        removeFromStage(actor.id, currentStage);
      }
      break;
    case 'destroyAll': {
      const targetId = node.values?.actorId;
      if (targetId && targetId !== -1) {
        if (node.values?.destroyEverywhere) removeFromAllStages(targetId);
        else removeFromStage(targetId, currentStage);
      }
      break;
    }
    case 'setVisibility': {
      const ent = game.actorsById[node.values?.actorId] || game.propsById[node.values?.actorId];
      if (ent) ent.isVisible = node.values?.isVisible;
      else actor.isVisible = node.values?.isVisible;
      break;
    }
    case 'turnInto': {
      const toId = node.values?.newActor;
      if (toId) replaceInStage(actor.id, toId, currentStage);
      break;
    }
    case 'turnAll': {
      const from = node.values?.actorFrom, to = node.values?.actorTo;
      if (from && to) {
        if (node.values?.turnEverywhere) replaceInAllStages(from, to);
        else replaceInStage(from, to, currentStage);
      }
      break;
    }
    case 'changeVariable': {
      const vid = node.values?.variable;
      const op = node.values?.operand || '+';
      const b = node.values?.b ?? 0;
      let cur = getVar(vid);
      switch (op) {
        case '+': cur += b; break;
        case '-': cur -= b; break;
        case '*': cur *= b; break;
        case '/': cur /= b; break;
        case '=': cur = b; break;
      }
      setVar(vid, cur);
      break;
    }
    case 'writeVariable':
      setVar(node.values?.variable, node.values?.value);
      break;
    case 'sendSignal':
      broadcastSignal(node.values?.signal);
      break;
    case 'ifElse': {
      const cond = resolveData(actor, node, 'boolean-condition');
      const edge = cond ? 'exec-ontrue' : 'exec-onfalse';
      return { branch: node.execEdges?.[edge] };
    }
    case 'randomBranch': {
      const outputs = node.values?.outputs || [];
      if (outputs.length === 0) break;
      const pick = outputs[Math.floor(Math.random() * outputs.length)];
      return { branch: node.execEdges?.['exec-' + pick.id] };
    }
    case 'sequentialBranch': {
      const outputs = node.values?.outputs || [];
      if (outputs.length === 0) break;
      const key = actor.id + '_' + (nodeId || '');
      const counter = seqCounters[key] || 0;
      const repeat = node.values?.repeatLast;
      let idx = counter;
      if (idx >= outputs.length) idx = repeat ? outputs.length - 1 : 0;
      seqCounters[key] = counter + 1;
      return { branch: node.execEdges?.['exec-' + outputs[idx].id] };
    }
    case 'getVariable': case 'compare': break; // data-only nodes
  }
  return null;
}

function runChain(actorId, startNodeId) {
  const actor = game.actorsById[actorId] || game.propsById[actorId];
  if (!actor || !actor.scenario) return;
  let nodeId = startNodeId;
  let steps = 0;
  const visited = new Set();
  while (nodeId && steps < 100) {
    if (visited.has(nodeId)) break;
    visited.add(nodeId);
    const node = actor.scenario[nodeId];
    if (!node) break;
    const result = execNode(actor, node, nodeId);
    if (result === 'pause') { pendingScenario = { actorId, nodeId, touchedIdx }; return; }
    if (result === 'confirm') { pendingScenario = { actorId, nodeId, touchedIdx }; return; }
    if (result && result.branch) { nodeId = result.branch; steps++; continue; }
    const next = node.execEdges?.['exec-next'];
    if (!next || next === nodeId) break;
    nodeId = next;
    steps++;
  }
}

function runScenarioChain(actorId, startNodeId) { runChain(actorId, startNodeId); touchedIdx = -1; }

function continueDialog() {
  if (!pendingScenario) return;
  const actor = game.actorsById[pendingScenario.actorId] || game.propsById[pendingScenario.actorId];
  if (!actor || !actor.scenario) { pendingScenario = null; return; }
  const pauseNode = actor.scenario[pendingScenario.nodeId];
  let nodeId = pauseNode?.execEdges?.['exec-next'];
  if (!nodeId) { pendingScenario = null; return; }
  touchedIdx = pendingScenario.touchedIdx ?? -1;
  pendingScenario = null;
  runChain(actor.id, nodeId);
}

function continueConfirm(yes) {
  if (!pendingScenario) return;
  const actor = game.actorsById[pendingScenario.actorId] || game.propsById[pendingScenario.actorId];
  if (!actor || !actor.scenario) { pendingScenario = null; return; }
  const node = actor.scenario[pendingScenario.nodeId];
  const edge = yes ? 'exec-yes' : 'exec-no';
  const nextId = node?.execEdges?.[edge];
  touchedIdx = pendingScenario.touchedIdx ?? -1;
  pendingScenario = null;
  if (nextId) runChain(actor.id, nextId);
}

function getFrame(entity, frameIdx) {
  if (!entity) return null;
  if (frameIdx === 0 || !entity.animated) return entity.frame0;
  const key = 'frame' + frameIdx;
  return entity[key] || entity.frame0;
}

function getOrRenderTile(entityId, frameIdx) {
  let entity = game.propsById[entityId];
  let isSkin = false;
  if (!entity) { entity = game.actorsById[entityId]; }
  if (!entity) { entity = game.skinsById[entityId]; isSkin = true; }
  if (!entity) return null;

  const actualIdx = isSkin ? 0 : (Math.floor(frameIdx / 8) % 3);
  const cacheKey = entityId + '_' + actualIdx;
  if (tileCache[cacheKey]) return tileCache[cacheKey];

  const frame = getFrame(entity, actualIdx);
  if (!frame) return null;

  const off = document.createElement('canvas');
  off.width = TILE; off.height = TILE;
  const offCtx = off.getContext('2d');
  const imgData = offCtx.createImageData(TILE, TILE);
  const d = imgData.data;
  const pal = game.palette;

  for (let ty = 0; ty < TILE; ty++) {
    for (let tx = 0; tx < TILE; tx++) {
      const ci = frame[ty * TILE + tx];
      const pi = (ty * TILE + tx) * 4;
      if (ci >= 0 && ci < pal.length) {
        const c = pal[ci];
        d[pi] = c.r; d[pi+1] = c.g; d[pi+2] = c.b; d[pi+3] = 255;
      }
    }
  }
  offCtx.putImageData(imgData, 0, 0);
  tileCache[cacheKey] = off;
  return off;
}

function isSolid(gx, gy) {
  if (gx < 0 || gx >= STAGE_W || gy < 0 || gy >= STAGE_H) return true;
  const idx = gy * STAGE_W + gx;
  const bgId = currentStage.background[idx];
  if (bgId && bgId !== -1 && game.propsById[bgId]?.isSolid) return true;
  const actorId = currentStage.actors[idx];
  if (actorId && actorId !== -1 && game.actorsById[actorId]?.isSolid) return true;
  return false;
}

function switchStage(stageId) {
  currentStage = game.stages.find(s => s.id === stageId);
  currentStageId = stageId;
}

function drawLayer(layer, frameIdx) {
  const ts = TILE * SCALE;
  for (let gy = 0; gy < STAGE_H; gy++) {
    for (let gx = 0; gx < STAGE_W; gx++) {
      const id = layer[gy * STAGE_W + gx];
      if (id && id !== -1) {
        const tile = getOrRenderTile(id, frameIdx);
        if (tile) ctx.drawImage(tile, gx * ts, gy * ts, ts, ts);
      }
    }
  }
}

function drawStage() {
  const bgIdx = currentStage.backgroundColor ?? 0;
  const bgc = game.palette[bgIdx] || {r:0,g:0,b:0};
  ctx.fillStyle = `rgb(${bgc.r},${bgc.g},${bgc.b})`;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  drawLayer(currentStage.background, frameCounter);
  drawLayer(currentStage.actors, frameCounter);
  if (heroSkin) {
    const tile = getOrRenderTile(heroSkin.id, 0);
    if (tile) ctx.drawImage(tile, heroX * TILE * SCALE, heroY * TILE * SCALE, TILE * SCALE, TILE * SCALE);
  }
  drawLayer(currentStage.foreground, frameCounter);

  // Dialog box
  if (dialogActive && dialogText) {
    const boxH = dialogType === 'message' ? GAME_H - 40 : 100;
    const boxY = dialogType === 'message' ? 20 : GAME_H - boxH;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
    ctx.fillRect(0, boxY, GAME_W, boxH);
    ctx.strokeStyle = '#555';
    ctx.lineWidth = 1;
    ctx.strokeRect(1, boxY, GAME_W - 2, boxH - 1);

    const fontSize = 14;
    const lineH = 18;
    ctx.fillStyle = '#fff';
    ctx.font = fontSize + 'px "PixelCode"';
    ctx.textAlign = 'left';
    const lines = dialogText.split('\n');
    let ly = boxY + lineH + 4;
    const maxW = GAME_W - 20;
    for (const rawLine of lines) {
      if (ly > boxY + boxH - lineH - 10) break;
      const words = rawLine.split(' ');
      let line = '';
      for (const w of words) {
        const test = line ? line + ' ' + w : w;
        if (ctx.measureText(test).width > maxW && line) {
          ctx.fillText(line, 10, ly);
          line = w;
          ly += lineH;
          if (ly > boxY + boxH - lineH - 10) break;
        } else {
          line = test;
        }
      }
      if (line && ly <= boxY + boxH - lineH - 10) { ctx.fillText(line, 10, ly); ly += lineH; }
    }

    ctx.fillStyle = '#888';
    ctx.font = '16px "PixelCode"';
    ctx.textAlign = 'right';
    ctx.fillText('x', GAME_W - 10, boxY + boxH - 10);
    ctx.textAlign = 'left';
  }

  // Confirm dialog
  if (confirmActive) {
    const boxH = 80;
    const boxY = GAME_H - boxH;
    ctx.fillStyle = 'rgba(0, 0, 0, 0.9)';
    ctx.fillRect(0, boxY, GAME_W, boxH);
    ctx.strokeStyle = '#888';
    ctx.lineWidth = 1;
    ctx.strokeRect(1, boxY, GAME_W - 2, boxH - 1);

    ctx.fillStyle = '#fff';
    ctx.font = '18px "PixelCode"';
    ctx.textAlign = 'center';
    ctx.fillText(confirmText, GAME_W / 2, boxY + 26);

    ctx.font = '18px "PixelCode"';
    ctx.fillStyle = confirmSelection === 0 ? '#00ff88' : '#666';
    ctx.fillText('> ' + confirmYes, GAME_W / 3, boxY + 56);
    ctx.fillStyle = confirmSelection === 1 ? '#00ff88' : '#666';
    ctx.fillText('> ' + confirmNo, (GAME_W * 2) / 3, boxY + 56);
    ctx.textAlign = 'left';
  }

  // Save/load flash
  if (saveFlashTimer > 0) {
    saveFlashTimer--;
    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(GAME_W / 2 - 60, 4, 120, 24);
    ctx.fillStyle = '#00ff88';
    ctx.font = '14px "PixelCode"';
    ctx.textAlign = 'center';
    ctx.fillText(saveFlash, GAME_W / 2, 22);
    ctx.textAlign = 'left';
  }
}

function drawMenu() {
  ctx.fillStyle = '#0a0a1a';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.fillStyle = '#00ff88';
  ctx.font = 'bold 24px "PixelCode"';
  ctx.textAlign = 'center';
  ctx.fillText('WHIMTALE PLAYER', GAME_W / 2, 40);

  if (gameFiles.length === 0) {
    ctx.fillStyle = '#ff4444';
    ctx.font = '14px "PixelCode"';
    ctx.fillText('No .whim/.whimsy games', GAME_W / 2, GAME_H / 2 - 12);
    ctx.fillText('found in games/', GAME_W / 2, GAME_H / 2 + 12);
    ctx.textAlign = 'left';
    return;
  }

  ctx.textAlign = 'left';
  if (selectedIdx < menuScroll) menuScroll = selectedIdx;
  if (selectedIdx >= menuScroll + MENU_VISIBLE) menuScroll = selectedIdx - MENU_VISIBLE + 1;

  const startY = 85;
  const end = Math.min(gameFiles.length, menuScroll + MENU_VISIBLE);
  const rowH = 26;
  for (let i = menuScroll; i < end; i++) {
    const name = gameFiles[i].name;
    const selected = i === selectedIdx;
    ctx.fillStyle = selected ? '#00ff88' : '#666';
    ctx.font = selected ? '22px "PixelCode"' : '22px "PixelCode"';
    const num = String(i + 1).padStart(2, '0');
    ctx.fillText(num + '. ' + name, 15, startY + (i - menuScroll) * rowH);
  }

}

function findTouchNode(actor) {
  if (!actor || !actor.scenario) return null;
  for (const [id, node] of Object.entries(actor.scenario)) {
    if (node.code === 'touch') return id;
  }
  return null;
}

async function startGame(fileInfo) {
  stopMusic();
  await loadGameData(fileInfo.filename);
  playMusic();
  state = 'playing';
}

// --- Save/Load (L1 = save, R1 = load) ---
let saveFlash = '';
let saveFlashTimer = 0;

function saveState() {
  try {
    const snap = {
      stageId: currentStageId,
      heroX, heroY,
      gameVars: JSON.parse(JSON.stringify(gameVars)),
      seqCounters: JSON.parse(JSON.stringify(seqCounters)),
      stages: game.stages.map(s => ({
        id: s.id,
        actors: [...s.actors],
        background: [...s.background],
        foreground: [...s.foreground],
      })),
    };
    localStorage.setItem('whimtale_save', JSON.stringify(snap));
    saveFlash = 'SAVED'; saveFlashTimer = 60;
  } catch (e) { saveFlash = 'SAVE FAILED'; saveFlashTimer = 60; }
}

function loadState() {
  try {
    const raw = localStorage.getItem('whimtale_save');
    if (!raw) { saveFlash = 'NO SAVE'; saveFlashTimer = 60; return; }
    const snap = JSON.parse(raw);
    if (!snap || !snap.stageId) { saveFlash = 'NO SAVE'; saveFlashTimer = 60; return; }
    currentStageId = snap.stageId;
    heroX = snap.heroX;
    heroY = snap.heroY;
    gameVars = snap.gameVars || {};
    seqCounters = snap.seqCounters || {};
    // Restore stage tile arrays
    for (const saved of (snap.stages || [])) {
      const stg = game.stages.find(s => s.id === saved.id);
      if (stg) {
        stg.actors = saved.actors;
        stg.background = saved.background;
        stg.foreground = saved.foreground;
      }
    }
    switchStage(currentStageId);
    dialogActive = false; confirmActive = false; pendingScenario = null;
    saveFlash = 'LOADED'; saveFlashTimer = 60;
  } catch (e) { saveFlash = 'NO SAVE'; saveFlashTimer = 60; }
}

function handleMenuInput() {
  const gp = navigator.getGamepads()?.[0];

  if (menuInputCooldown > 0) { menuInputCooldown--; return; }

  let moved = false;
  if (keys['ArrowUp'] || keys['w'] || keys['W'] || (gp && gp.buttons[12]?.pressed)) {
    selectedIdx = (selectedIdx - 1 + gameFiles.length) % gameFiles.length;
    moved = true;
  }
  if (keys['ArrowDown'] || keys['s'] || keys['S'] || (gp && gp.buttons[13]?.pressed)) {
    selectedIdx = (selectedIdx + 1) % gameFiles.length;
    moved = true;
  }

  // Page up/down
  if (keys['ArrowLeft'] || keys['a'] || keys['A'] || (gp && gp.buttons[14]?.pressed)) {
    selectedIdx = Math.max(0, selectedIdx - MENU_VISIBLE);
    moved = true;
  }
  if (keys['ArrowRight'] || keys['d'] || keys['D'] || (gp && gp.buttons[15]?.pressed)) {
    selectedIdx = Math.min(gameFiles.length - 1, selectedIdx + MENU_VISIBLE);
    moved = true;
  }

  const confirm = keys['Enter'] || keys[' '] || keys['e'] || keys['E']
    || (gp && (gp.buttons[0]?.pressed || gp.buttons[1]?.pressed));

  if (confirm && gameFiles.length > 0) {
    startGame(gameFiles[selectedIdx]);
    return;
  }

  if (moved) { menuInputCooldown = 10; }
}

function handleGameInput() {
  let dx = 0, dy = 0;
  const gp = navigator.getGamepads()?.[0];
  if (gp) {
    if (gp.buttons[12]?.pressed) dy = -1;
    if (gp.buttons[13]?.pressed) dy = 1;
    if (gp.buttons[14]?.pressed) dx = -1;
    if (gp.buttons[15]?.pressed) dx = 1;
    if (Math.abs(gp.axes[0]) > 0.5) dx = Math.sign(gp.axes[0]);
    if (Math.abs(gp.axes[1]) > 0.5) dy = Math.sign(gp.axes[1]);
    // L1 = save, R1 = load
    if (gp.buttons[4]?.pressed && inputCooldown <= 0) { saveState(); inputCooldown = 30; return; }
    if (gp.buttons[5]?.pressed && inputCooldown <= 0) { loadState(); inputCooldown = 30; return; }
  }
  // Keyboard: 1 = save, 2 = load
  if (keys['1'] && inputCooldown <= 0) { saveState(); inputCooldown = 30; return; }
  if (keys['2'] && inputCooldown <= 0) { loadState(); inputCooldown = 30; return; }
  if (keys['ArrowUp'] || keys['w'] || keys['W']) dy = -1;
  if (keys['ArrowDown'] || keys['s'] || keys['S']) dy = 1;
  if (keys['ArrowLeft'] || keys['a'] || keys['A']) dx = -1;
  if (keys['ArrowRight'] || keys['d'] || keys['D']) dx = 1;

  // A button / confirm dismisses dialogs without needing direction
  const confirmBtn = keys['Enter'] || keys[' '] || (gp && (gp.buttons[0]?.pressed || gp.buttons[1]?.pressed));
  if (confirmBtn && inputCooldown <= 0) {
    if (confirmActive) {
      confirmActive = false;
      continueConfirm(confirmSelection === 0);
      inputCooldown = 8;
      return;
    }
    if (dialogActive) {
      dialogActive = false;
      dialogText = '';
      continueDialog();
      inputCooldown = 8;
      return;
    }
  }

  if ((dx !== 0 || dy !== 0) && inputCooldown <= 0) {
    if (confirmActive) {
      if (dy !== 0) confirmSelection = confirmSelection === 0 ? 1 : 0;
      const gpa = navigator.getGamepads()?.[0];
      if (dx > 0 || keys['Enter'] || keys[' '] || (gpa && gpa.buttons[0]?.pressed)) {
        confirmActive = false;
        continueConfirm(confirmSelection === 0);
      }
      inputCooldown = 8;
      return;
    }
    if (dialogActive) {
      const gpa = navigator.getGamepads()?.[0];
      if (dx !== 0 || dy !== 0 || keys['Enter'] || keys[' '] || (gpa && gpa.buttons[0]?.pressed)) {
        dialogActive = false;
        dialogText = '';
        continueDialog();
        inputCooldown = 8;
        return;
      }
    }
    const nx = heroX + dx, ny = heroY + dy;
    const inBounds = nx >= 0 && nx < STAGE_W && ny >= 0 && ny < STAGE_H;
    const nidx = inBounds ? ny * STAGE_W + nx : -1;

    // Check for touch-triggerable actor at destination (before solid check)
    const actorId = inBounds ? currentStage.actors[nidx] : null;
    const bgId = inBounds ? currentStage.background[nidx] : null;
    let touchedId = null;
    if (actorId && actorId !== -1) touchedId = actorId;
    else if (bgId && bgId !== -1) touchedId = bgId;

    if (touchedId) {
      const entity = game.actorsById[touchedId] || game.propsById[touchedId];
      if (entity && entity.scenario) {
        const touchNode = findTouchNode(entity);
        if (touchNode) {
          pendingScenario = null;
          touchedIdx = nidx;
          runScenarioChain(touchedId, touchNode);
          if (dialogActive || confirmActive) { inputCooldown = 10; return; }
        }
      }
      if (entity && entity.isSolid) { inputCooldown = 10; return; }
    }

    // Stage exits
    for (const exit of currentStage.exits || []) {
      if (heroX === exit.xfrom && heroY === exit.yfrom) {
        heroX = exit.xto; heroY = exit.yto;
        switchStage(exit.stageto);
        inputCooldown = 12; return;
      }
    }

    // Wraps
    const w = currentStage.wraps || {};
    let newX = nx, newY = ny, newStage = currentStageId;
    if (nx < 0 && w.left && w.left !== -1) { newStage = w.left; newX = STAGE_W - 1; }
    else if (nx >= STAGE_W && w.right && w.right !== -1) { newStage = w.right; newX = 0; }
    else if (ny < 0 && w.top && w.top !== -1) { newStage = w.top; newY = STAGE_H - 1; }
    else if (ny >= STAGE_H && w.bottom && w.bottom !== -1) { newStage = w.bottom; newY = 0; }

    const stageChanged = newStage !== currentStageId;
    if (stageChanged) switchStage(newStage);
    if (stageChanged || !isSolid(newX, newY)) { heroX = newX; heroY = newY; }
    inputCooldown = 10;
  }
  if (inputCooldown > 0) inputCooldown--;
}

function processWhimtale(raw) {
  const a = raw.assets;
  const toDict = arr => { const d = {}; for (const x of arr) d[x.id] = x; return d; };
  return {
    name: raw.settings.name, palette: raw.palette, hero: a.hero,
    constants: raw.constants, stages: a.stages,
    variables: raw.variables || [],
    vinyls: a.vinyls || [],
    actorsById: toDict(a.actors), propsById: toDict(a.props), skinsById: toDict(a.skins),
    cuesById: toDict(a.cues || []),
  };
}

let musicSource = null;

function playMusic() {
  if (!audioCtx || !game || !game.vinyls || game.vinyls.length === 0) return;
  const vinyl = game.vinyls[0];
  const b64 = vinyl.data;
  if (!b64) return;
  try {
    const binary = atob(b64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    audioCtx.decodeAudioData(bytes.buffer, (buffer) => {
      if (musicSource) { try { musicSource.stop(); } catch(_){} }
      musicSource = audioCtx.createBufferSource();
      musicSource.buffer = buffer;
      musicSource.loop = true;
      const gain = audioCtx.createGain();
      gain.gain.value = vinyl.volume ?? 0.5;
      musicSource.connect(gain);
      gain.connect(audioCtx.destination);
      musicSource.start();
    });
  } catch (_) {}
}

function stopMusic() {
  if (musicSource) { try { musicSource.stop(); } catch(_){} musicSource = null; }
}

async function loadGameData(filename) {
  const resp = await fetch(filename);
  if (!resp.ok) throw new Error('Failed to load ' + filename);
  const raw = await resp.json();
  game = processWhimtale(raw);
  initVars();
  currentStageId = game.hero.stage || game.hero.startingStage;
  heroX = game.hero.x ?? game.hero.startingX ?? 7;
  heroY = game.hero.y ?? game.hero.startingY ?? 7;
  heroSkin = game.skinsById[game.hero.skin] || game.hero;
  if (heroSkin.id && !game.skinsById[heroSkin.id]) game.skinsById[heroSkin.id] = heroSkin;
  switchStage(currentStageId);
}

function gameLoop() {
  Object.assign(prevKeys, keys);
  if (state === 'menu') { handleMenuInput(); drawMenu(); }
  else { frameCounter++; handleGameInput(); drawStage(); }
  requestAnimationFrame(gameLoop);
}

async function init() {
  // Init audio
  try { audioCtx = new AudioContext(); } catch (_) {}

  // Load pixel font
  try {
    const font = new FontFace('PixelCode', 'url(fonts/PixelCode.ttf)');
    await font.load();
  } catch (_) {}

  const dir = globalThis._jsg?.rom?.romDir;
  const gamesDir = dir ? dir + '/games' : null;
  if (gamesDir) {
    try {
      const fs = await import('fs');
      const files = fs.readdirSync(gamesDir);
      gameFiles = files
        .filter(f => f.endsWith('.whim') || f.endsWith('.whimsy'))
        .map(f => ({ filename: 'games/' + f, name: f.replace(/\.(whim|whimsy)$/, '') }));
    } catch (_) {}
  }

  if (gameFiles.length === 0) {
    console.log('No .whim/.whimsy games found in games/');
  }

  requestAnimationFrame(gameLoop);
}

init().catch(e => console.error('Init failed:', e));
