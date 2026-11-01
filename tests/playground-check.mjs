// Runs dist/flappy-bundle.asm in a copy of the AArch64 Playground's emulator (build/playground-wasm).
//   goldens   lint the bundle, then every headless golden must print byte-identical output
//   envelope  the autopilot as a terminal program at 48x43, driven the way the terminal pane
//             drives it, measured against the playground's refill rates and lifetime walls
// usage, from build/: node ../tests/playground-check.mjs goldens|envelope [minutes]
import { createRequire } from 'node:module';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const { Emulator } = require(join(root, 'build/playground-wasm/aarch64_emulator.js'));
const bundle = readFileSync(join(root, 'dist/flappy-bundle.asm'), 'utf8');
const CHUNK = 1000000;
const STEP_RATE = 1000000, BYTE_RATE = 100000;
const STEP_START = 10000000, STEP_CAP = 200000000;
const BYTE_START = 4 * 1024 * 1024, BYTE_CAP = 4 * 1024 * 1024;
const STEP_WALL = STEP_START + STEP_CAP, BYTE_WALL = BYTE_START + BYTE_CAP;

// A budget starts full, gains `refill` per second slept until `cap` of refunds is spent, and the
// program spends `rate` per second; returns the seconds until it runs dry.
function lasts(start, refill, cap, rate) {
  const refunding = cap / refill;
  if (rate > refill && start / (rate - refill) <= refunding) return start / (rate - refill);
  return refunding + (start + (refill - rate) * refunding) / rate;
}

function load(args) {
  const emu = new Emulator();
  const r = emu.assemble_and_load_with_args(bundle, args);
  if (!r.success) throw new Error(`assemble failed: ${JSON.stringify(r)}`);
  return emu;
}

function goldens() {
  const lint = new Emulator().lint_source(bundle);
  console.log(`lint: ${lint.length} findings`);
  for (const f of lint) console.log(`  line ${f.line}: ${f.message}`);
  let bad = lint.length > 0;
  const dir = join(root, 'tests/golden');
  for (const f of readdirSync(dir).filter((n) => n.endsWith('.args')).sort()) {
    const name = f.slice(0, -5);
    const args = readFileSync(join(dir, f), 'utf8').trim().split(/\s+/);
    const want = readFileSync(join(dir, `${name}.out`), 'utf8');
    const emu = load(['--headless', ...args]);
    let out = '', r, limit = 0;
    do {
      r = emu.run_until_break(CHUNK);
      if (r.steps_executed >= CHUNK) limit++;
      out += emu.take_stdout();
    } while (!r.halted && !r.error);
    const exit = String(emu.get_exit_code());
    const ok = out === want && exit === '0' && limit === 0 && !r.error;
    if (!ok) bad = true;
    console.log(`${ok ? 'PASS' : 'FAIL'} ${name}${exit !== '0' ? ` exit ${exit}` : ''}${limit ? ` ${limit} chunks hit the step limit` : ''}${r.error ? ` error ${r.error}` : ''}`);
  }
  return bad ? 1 : 0;
}

function envelope(minutes) {
  const emu = load(['--autopilot', '--size', '48x43']);
  emu.set_snapshots_paused(true);
  let ms = 0, steps = 0, seen = 0, peak = 0, limit = 0, chunks = 0, r;
  let secSteps = 0, secBytes = 0, secPeakBytes = 0, secPeakSteps = 0, secStart = 0;
  let stepWallAt = null, byteWallAt = null;
  const stop = minutes * 60000;
  do {
    r = emu.run_until_break(CHUNK);
    chunks++;
    const s = emu.stdout_seen();
    const b = s - seen;
    seen = s;
    emu.take_stdout();
    steps += r.steps_executed;
    secSteps += r.steps_executed;
    secBytes += b;
    peak = Math.max(peak, r.steps_executed);
    if (r.steps_executed >= CHUNK) limit++;
    if (stepWallAt === null && steps >= STEP_WALL) stepWallAt = ms;
    if (byteWallAt === null && seen >= BYTE_WALL) byteWallAt = ms;
    ms += r.sleep_ms || 0;
    if (ms - secStart >= 1000) {
      secPeakBytes = Math.max(secPeakBytes, secBytes);
      secPeakSteps = Math.max(secPeakSteps, secSteps);
      secSteps = secBytes = 0;
      secStart = ms;
    }
  } while (!r.halted && !r.error && ms < stop);
  const secs = ms / 1000;
  const stepsPerSec = steps / secs, bytesPerSec = seen / secs;
  const why = r.error ? `error: ${r.error}` : r.halted ? `halted, exit ${emu.get_exit_code()}` : `ran the full ${minutes} minutes`;
  const stepLife = lasts(STEP_START, STEP_RATE, STEP_CAP, stepsPerSec);
  const byteLife = lasts(BYTE_START, BYTE_RATE, BYTE_CAP, bytesPerSec);
  const projected = Math.min(stepLife, byteLife) / 60;
  console.log(`virtual time ${secs.toFixed(1)} s over ${chunks} chunks; stopped: ${why}`);
  if (r.error || r.halted) console.log(`stderr: ${JSON.stringify(emu.take_stderr()).slice(0, 300)}`);
  console.log(`steps: ${steps}, ${Math.round(stepsPerSec)} per s (${(100 * stepsPerSec / STEP_RATE).toFixed(1)}% of the refill), busiest second ${secPeakSteps}`);
  console.log(`bytes: ${seen}, ${Math.round(bytesPerSec)} per s (${(100 * bytesPerSec / BYTE_RATE).toFixed(1)}% of the refill), busiest second ${secPeakBytes}`);
  console.log(`peak steps between two sleeps: ${peak}; chunks at the ${CHUNK}-step stop: ${limit}`);
  // the walls below are this script's model of the budgets; the emulator's own stop is what counts
  if (r.error) console.log(`the emulator stopped it at ${secs.toFixed(1)} s, after ${seen} bytes and ${steps} steps`);
  console.log(`model step wall (${STEP_WALL}) reached at: ${stepWallAt === null ? 'not reached' : (stepWallAt / 1000).toFixed(1) + ' s'}`);
  console.log(`model output wall (${BYTE_WALL}) reached at: ${byteWallAt === null ? 'not reached' : (byteWallAt / 1000).toFixed(1) + ' s'}`);
  console.log(`step budget lasts ${(stepLife / 60).toFixed(1)} min, output budget ${(byteLife / 60).toFixed(1)} min at these rates`);
  console.log(`projected session length: ${projected.toFixed(1)} minutes (observed stop at ${(secs / 60).toFixed(1)} min${r.error || r.halted ? '' : ', still running'})`);
  // steps and bytes under 90% of their refill on average, no second that writes more than a
  // second of refill, and no stretch near the step stop
  const ok = stepsPerSec < 0.9 * STEP_RATE && bytesPerSec < 0.9 * BYTE_RATE && secPeakBytes < BYTE_RATE && limit === 0;
  console.log(ok ? 'PASS envelope' : 'FAIL envelope');
  return ok ? 0 : 1;
}

const mode = process.argv[2];
if (mode === 'goldens') process.exit(goldens());
if (mode === 'envelope') process.exit(envelope(Number(process.argv[3] || 15)));
console.error('usage: playground-check.mjs goldens|envelope [minutes]');
process.exit(2);
