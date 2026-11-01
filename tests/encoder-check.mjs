// Feeds a --render-out stream to a headless xterm.js, the terminal the playground uses, and at
// every dumped tick compares each playfield cell's two colours with the frame's PPM pixels.
// usage, from build/: node ../tests/encoder-check.mjs STREAM IDX DUMPDIR COLS ROWS
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import xterm from '@xterm/headless';
import { halves } from './cells.mjs';
const { Terminal } = xterm;

const [stream, idxPath, dumpDir, colsArg, rowsArg] = process.argv.slice(2);
const cols = Number(colsArg), rows = Number(rowsArg);
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
let fed = 0, mismatches = 0, cells = 0, shown = 0;

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
      const [top, bottom] = halves(cell);
      cells++;
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
console.log(`${stream}: ${dumps.length} frames, ${cells} cells, ${mismatches} mismatches`);
process.exit(mismatches === 0 && dumps.length > 0 ? 0 : 1);
