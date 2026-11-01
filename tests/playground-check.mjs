// Runs dist/flappy-bundle.asm in a copy of the AArch64 Playground's emulator (build/playground-wasm).
//   goldens   lint the bundle, then every headless golden must print byte-identical output
//   envelope  the autopilot as a terminal program at 48x43, driven the way the terminal pane
//             drives it, measured against the playground's refill rates and lifetime walls
//   profile   with no --lite typed, the game takes the lite profile, and q ends it with exit 0
//             and no error, which shows it made no syscall the playground lacks
// usage, from build/: node ../tests/playground-check.mjs goldens|envelope [minutes]|profile
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
const NS = 1e9;

// A budget starts full, gains `refill` per second slept until `cap` of refunds is spent, and the
// program spends `rate` per second; returns the seconds until it runs dry. A refund never lifts
// the budget above full, so a program under the refill banks nothing for later.
function lasts(start, refill, cap, rate) {
  const refunding = cap / refill;
  if (rate > refill && start / (rate - refill) <= refunding) return start / (rate - refill);
  return refunding + (start - Math.max(0, rate - refill) * refunding) / rate;
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
  // each budget as the emulator keeps it: what was spent less what sleeps refunded, never less
  // than nothing, and the bytes are refunded only by a sleep that refunds steps
  let stepUsed = 0, byteUsed = 0, stepBack = 0, byteBack = 0;
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
    stepUsed += r.steps_executed;
    byteUsed += b;
    if (stepWallAt === null && stepUsed > STEP_START) stepWallAt = ms;
    if (byteWallAt === null && byteUsed > BYTE_START) byteWallAt = ms;
    const ns = Math.round((r.sleep_ms || 0) * 1e6);
    const stepRefund = Math.min(Math.floor(ns * STEP_RATE / NS), STEP_CAP - stepBack);
    stepBack += stepRefund;
    stepUsed = Math.max(0, stepUsed - stepRefund);
    if (stepRefund > 0) {
      const byteRefund = Math.min(Math.floor(ns * BYTE_RATE / NS), BYTE_CAP - byteBack);
      byteBack += byteRefund;
      byteUsed = Math.max(0, byteUsed - byteRefund);
    }
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
  console.log(`model step budget (${STEP_START}, refunds up to ${STEP_CAP}) ran out at: ${stepWallAt === null ? 'not reached' : (stepWallAt / 1000).toFixed(1) + ' s'}`);
  console.log(`model output budget (${BYTE_START}, refunds up to ${BYTE_CAP}) ran out at: ${byteWallAt === null ? 'not reached' : (byteWallAt / 1000).toFixed(1) + ' s'}`);
  console.log(`step budget lasts ${(stepLife / 60).toFixed(1)} min, output budget ${(byteLife / 60).toFixed(1)} min at these rates`);
  console.log(`projected session length: ${projected.toFixed(1)} minutes (observed stop at ${(secs / 60).toFixed(1)} min${r.error || r.halted ? '' : ', still running'})`);
  // steps and bytes under 90% of their refill on average, no second that writes more than a
  // second of refill, and no stretch near the step stop
  const ok = stepsPerSec < 0.9 * STEP_RATE && bytesPerSec < 0.9 * BYTE_RATE && secPeakBytes < BYTE_RATE && limit === 0;
  console.log(ok ? 'PASS envelope' : 'FAIL envelope');
  return ok ? 0 : 1;
}

// The colour codes in SGR sequences: '2' for 24-bit, '5' for a palette index.
function colourKinds(out) {
  const kinds = new Set();
  for (const [, p] of out.matchAll(/\x1b\[([0-9;]*)m/g)) {
    const t = p.split(';');
    for (let i = 0; i < t.length; i++) {
      if ((t[i] === '38' || t[i] === '48') && i + 1 < t.length) {
        kinds.add(t[i + 1]);
        i += t[i + 1] === '2' ? 4 : 2;
      }
    }
  }
  return [...kinds].sort().join(',');
}

// Runs the game in the console with ARGS for SECONDS of virtual time, presses q, and gives it
// five more seconds to exit. Any syscall the emulator lacks would end the run with an error.
// KINDS are the colour codes it must use, and each of WANTBEFORE must show before the q.
function profileRun(name, args, seconds, kinds, wantBefore) {
  const emu = load(args);
  emu.set_snapshots_paused(true);
  let ms = 0, out = '', before = null, r;
  do {
    r = emu.run_until_break(CHUNK);
    out += emu.take_stdout();
    ms += r.sleep_ms || 0;
    if (before === null && ms >= seconds * 1000) {
      before = out;
      emu.push_stdin('q');
    }
  } while (!r.halted && !r.error && ms < (seconds + 5) * 1000);
  const restore = '\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m', unpal = '\x1b]104\x1b\\';
  const exit = String(emu.get_exit_code());
  const fails = [];
  if (r.error) fails.push(`error ${r.error}`);
  if (!r.halted || exit !== '0') fails.push(`exit ${exit}`);
  if (colourKinds(out) !== kinds) fails.push(`colour codes other than [${kinds}]`);
  for (const [what, text] of wantBefore) if (!(before || '').includes(text)) fails.push(`no ${what} before q`);
  if (!out.endsWith(restore + unpal)) fails.push('no restore and OSC 104 at the end');
  console.log(`${fails.length ? 'FAIL' : 'PASS'} ${name}: colour codes [${colourKinds(out)}], ${out.split('\x1b]4;').length - 1} OSC 4, exit ${exit}, error ${r.error || 'none'}${fails.length ? '; ' + fails.join(', ') : ''}`);
  return fails.length > 0;
}

// In today's playground TIOCGWINSZ answers ENOTTY and TCGETS gives no control character, so the
// game guesses 80x24, too small for any scale, and shows the notice, which only the lite profile
// follows with OSC 104; with a size it draws in palette indexes after an OSC 4. The playground
// never installs the SIGTERM handler, --lite or not: rt_sigaction would stop the run.
function profile() {
  let bad = profileRun('no arguments', [], 2, '', [['notice', 'terminal is 80x24'], ['OSC 104', '\x1b]104\x1b\\']]);
  bad = profileRun('--size 48x43', ['--size', '48x43'], 3, '5', [['OSC 4', '\x1b]4;']]) || bad;
  bad = profileRun('--lite --size 48x43', ['--lite', '--size', '48x43'], 3, '5', [['OSC 4', '\x1b]4;']]) || bad;
  return bad ? 1 : 0;
}

const mode = process.argv[2];
if (mode === 'goldens') process.exit(goldens());
if (mode === 'envelope') process.exit(envelope(Number(process.argv[3] || 15)));
if (mode === 'profile') process.exit(profile());
console.error('usage: playground-check.mjs goldens|envelope [minutes]|profile');
process.exit(2);
