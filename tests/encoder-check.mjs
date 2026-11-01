// Feeds a --render-out stream to a headless xterm.js, the terminal the playground uses, and at
// every dumped tick compares each playfield cell's two colours with the frame's PPM pixels.
// With "indexed" (the lite profile) every cell must be drawn with palette indexes, which resolve
// through the palette the stream has set with OSC 4 (OSC 104 forgets it); the headless terminal
// keeps no palette of its own, so the check keeps it.
// usage, from build/: node ../tests/encoder-check.mjs STREAM IDX DUMPDIR COLS ROWS [indexed]
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import xterm from '@xterm/headless';
import { halves } from './cells.mjs';
const { Terminal } = xterm;

const [stream, idxPath, dumpDir, colsArg, rowsArg, mode] = process.argv.slice(2);
const cols = Number(colsArg), rows = Number(rowsArg);
const indexed = mode === 'indexed';
const data = readFileSync(stream);
const offsets = new Map();
for (const line of readFileSync(idxPath, 'utf8').split('\n')) {
  const [t, off] = line.split(' ').map(Number);
  if (line) offsets.set(t, off);
}
const dumps = readdirSync(dumpDir).filter((f) => f.endsWith('.ppm'))
  .map((f) => Number(f.slice(0, -4))).sort((a, b) => a - b);

function readPpm(path) {
  const b = readFileSync(path);
  const head = b.subarray(0, 32).toString('latin1').split(/\s+/);
  const w = Number(head[1]), h = Number(head[2]);
  let pos = 0;
  for (let n = 0; n < 4; n++) {
    while (b[pos] !== 0x20 && b[pos] !== 0x0a) pos++;
    pos++;
  }
  return { w, h, px: b.subarray(pos) };
}

const term = new Terminal({ cols, rows, scrollback: 0, allowProposedApi: true });
const feed = (bytes) => new Promise((done) => term.write(bytes, done));
let fed = 0, mismatches = 0, cells = 0, shown = 0, rgbCells = 0, updates = 0, restores = 0;

// returning false lets the terminal's own handlers run as well
const palette = new Map();
term.parser.registerOscHandler(4, (spec) => {
  updates++;
  const f = spec.split(';');
  for (let i = 0; i + 1 < f.length; i += 2) {
    const m = /^rgb:([0-9a-f]{2})\/([0-9a-f]{2})\/([0-9a-f]{2})$/.exec(f[i + 1]);
    if (/^\d+$/.test(f[i]) && m) palette.set(Number(f[i]), parseInt(m[1] + m[2] + m[3], 16));
  }
  return false;
});
term.parser.registerOscHandler(104, (spec) => {
  restores++;
  if (spec === '') palette.clear();
  else for (const n of spec.split(';')) palette.delete(Number(n));
  return false;
});

for (const t of dumps) {
  const end = offsets.get(t);
  if (end === undefined) throw new Error(`render.idx has no tick ${t}`);
  await feed(data.subarray(fed, end));
  fed = end;
  const { w, h, px } = readPpm(join(dumpDir, `${t}.ppm`));
  const crows = h >> 1;
  const ox = (cols - w) >> 1, oy = (rows - crows) >> 1;
  const buf = term.buffer.active;
  const rgb = (x, y) => { const i = (y * w + x) * 3; return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2]; };
  for (let r = 0; r < crows; r++) {
    const line = buf.getLine(oy + r);
    for (let c = 0; c < w; c++) {
      const cell = line.getCell(ox + c);
      const [top, bottom] = halves(cell, indexed ? palette : undefined);
      cells++;
      if (indexed && (cell.isFgRGB() || cell.isBgRGB())) rgbCells++;
      const wt = rgb(c, 2 * r), wb = rgb(c, 2 * r + 1);
      if (top !== wt || bottom !== wb) {
        mismatches++;
        if (shown++ < 5) {
          console.log(`tick ${t} cell ${r},${c} char ${JSON.stringify(cell.getChars())} got ${top.toString(16)}/${bottom.toString(16)} want ${wt.toString(16)}/${wb.toString(16)}`);
        }
      }
    }
  }
}
const lite = indexed ? `, ${rgbCells} cells in 24-bit colour, ${updates} palette updates, ${restores} restores` : '';
console.log(`${stream}: ${dumps.length} frames, ${cells} cells, ${mismatches} mismatches${lite}`);
process.exit(mismatches === 0 && rgbCells === 0 && dumps.length > 0 ? 0 : 1);
