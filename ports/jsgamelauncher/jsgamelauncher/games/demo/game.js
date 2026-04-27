const canvas = document.getElementById('game-canvas');
const ctx = canvas.getContext('2d');
canvas.width = 640;
canvas.height = 480;

const audioCtx = new AudioContext();

function playCollectSound() {
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.type = 'sine';
  osc.frequency.setValueAtTime(880, audioCtx.currentTime);
  osc.frequency.exponentialRampToValueAtTime(1760, audioCtx.currentTime + 0.08);
  gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.2);
  osc.start();
  osc.stop(audioCtx.currentTime + 0.2);
}

const player = { x: 300, y: 220, w: 40, h: 40, speed: 4, color: '#00ff88' };
const stars = [];
const particles = [];
let score = 0;
let time = 0;

for (let i = 0; i < 5; i++) {
  stars.push({
    x: Math.random() * 580 + 30,
    y: Math.random() * 420 + 30,
    pulse: Math.random() * Math.PI * 2,
  });
}

for (let i = 0; i < 60; i++) {
  particles.push({
    x: Math.random() * 640,
    y: Math.random() * 480,
    vx: (Math.random() - 0.5) * 0.5,
    vy: (Math.random() - 0.5) * 0.5,
    size: Math.random() * 2 + 1,
    alpha: Math.random() * 0.4 + 0.1,
  });
}

const keys = {};
window.addEventListener('keydown', (e) => { keys[e.key] = true; });
window.addEventListener('keyup', (e) => { keys[e.key] = false; });

function getInput() {
  let dx = 0, dy = 0;
  const gamepads = navigator.getGamepads();
  const gp = gamepads[0];
  if (gp) {
    if (gp.buttons[12]?.pressed) dy = -1;
    if (gp.buttons[13]?.pressed) dy = 1;
    if (gp.buttons[14]?.pressed) dx = -1;
    if (gp.buttons[15]?.pressed) dx = 1;
    if (Math.abs(gp.axes[0]) > 0.3) dx = gp.axes[0];
    if (Math.abs(gp.axes[1]) > 0.3) dy = gp.axes[1];
  }
  if (keys['ArrowUp'] || keys['w']) dy = -1;
  if (keys['ArrowDown'] || keys['s']) dy = 1;
  if (keys['ArrowLeft'] || keys['a']) dx = -1;
  if (keys['ArrowRight'] || keys['d']) dx = 1;
  return { dx, dy };
}

function update() {
  time += 0.02;
  const input = getInput();
  player.x += input.dx * player.speed;
  player.y += input.dy * player.speed;
  player.x = Math.max(0, Math.min(600, player.x));
  player.y = Math.max(0, Math.min(440, player.y));

  for (let i = stars.length - 1; i >= 0; i--) {
    const s = stars[i];
    s.pulse += 0.05;
    const dx = player.x + 20 - s.x;
    const dy = player.y + 20 - s.y;
    if (Math.sqrt(dx * dx + dy * dy) < 30) {
      score++;
      s.x = Math.random() * 580 + 30;
      s.y = Math.random() * 420 + 30;
      player.color = `hsl(${(score * 47) % 360}, 80%, 60%)`;
      playCollectSound();
    }
  }

  for (const p of particles) {
    p.x += p.vx;
    p.y += p.vy;
    if (p.x < 0) p.x = 640;
    if (p.x > 640) p.x = 0;
    if (p.y < 0) p.y = 480;
    if (p.y > 480) p.y = 0;
  }
}

function render() {
  ctx.fillStyle = '#0a0a1a';
  ctx.fillRect(0, 0, 640, 480);

  for (const p of particles) {
    ctx.globalAlpha = p.alpha;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(p.x, p.y, p.size, p.size);
  }
  ctx.globalAlpha = 1;

  for (const s of stars) {
    const size = 12 + Math.sin(s.pulse) * 4;
    ctx.fillStyle = '#ffdd00';
    ctx.beginPath();
    for (let i = 0; i < 5; i++) {
      const angle = (i * 4 * Math.PI) / 5 - Math.PI / 2;
      const x = s.x + Math.cos(angle) * size;
      const y = s.y + Math.sin(angle) * size;
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.closePath();
    ctx.fill();
  }

  const bounce = Math.sin(time * 4) * 2;
  ctx.fillStyle = player.color;
  ctx.shadowColor = player.color;
  ctx.shadowBlur = 15;
  ctx.fillRect(player.x, player.y + bounce, player.w, player.h);
  ctx.shadowBlur = 0;

  ctx.fillStyle = '#ffffff';
  ctx.font = 'bold 24px monospace';
  ctx.fillText(`SCORE: ${score}`, 20, 36);

  ctx.fillStyle = '#666666';
  ctx.font = '14px monospace';
  ctx.fillText('DPAD/Arrows to move - Collect the stars!', 160, 470);
}

function gameLoop() {
  update();
  render();
  requestAnimationFrame(gameLoop);
}

gameLoop();
