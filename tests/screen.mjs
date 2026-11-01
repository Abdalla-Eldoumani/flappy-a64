// Replays a pty capture into a headless xterm.js, resizing it where the run resized, and writes
// what the terminal shows at the end as a PPM, one cell as two stacked pixels. It stops where
// the exit's restore sequence starts, because leaving the alternate screen would hide the game.
// usage, from build/: node ../tests/screen.mjs CAPTURE COLS ROWS OUT.ppm [OFFSET:CxR ...] [@OFFSET]
// OFFSET:CxR resizes after that many capture bytes; @OFFSET shows the screen at that byte.
// prints the final size and how many cells were never painted; OUT - prints the screen's text
// instead, one line per row with trailing blanks dropped
import { readFileSync, writeFileSync } from 'node:fs';
import xterm from '@xterm/headless';
import { halves } from './cells.mjs';
const { Terminal } = xterm;

const [capture, colsArg, rowsArg, out, ...args] = process.argv.slice(2);
let data = readFileSync(capture);
const cut = data.indexOf(Buffer.from('\x1b[?1006l'));
if (cut >= 0) data = data.subarray(0, cut);
const stop = args.find((a) => a.startsWith('@'));
if (stop) data = data.subarray(0, Math.min(Number(stop.slice(1)), data.length));
const resizes = args.filter((a) => !a.startsWith('@'));
const term = new Terminal({ cols: Number(colsArg), rows: Number(rowsArg), scrollback: 0, allowProposedApi: true });
const feed = (bytes) => new Promise((done) => term.write(bytes, done));
let fed = 0;
for (const r of resizes) {
  const [off, size] = r.split(':');
  const [c, w] = size.split('x').map(Number);
  const end = Math.min(Number(off), data.length);
  await feed(data.subarray(fed, end));
  fed = end;
  term.resize(c, w);
}
await feed(data.subarray(fed));

const { cols, rows } = term;
const buf = term.buffer.active;
if (out === '-') {
  for (let r = 0; r < rows; r++) console.log(buf.getLine(r).translateToString(true));
  process.exit(0);
}
const px = Buffer.alloc(cols * rows * 2 * 3);
const put = (x, y, v) => {
  const i = (y * cols + x) * 3;
  // magenta marks a cell the game never painted
  const rgb = v < 0 ? 0xff00ff : v;
  px[i] = rgb >> 16; px[i + 1] = (rgb >> 8) & 255; px[i + 2] = rgb & 255;
};
let unpainted = 0;
for (let r = 0; r < rows; r++) {
  const line = buf.getLine(r);
  for (let c = 0; c < cols; c++) {
    const [top, bottom] = halves(line.getCell(c));
    if (top < 0 || bottom < 0) unpainted++;
    put(c, 2 * r, top);
    put(c, 2 * r + 1, bottom);
  }
}
writeFileSync(out, Buffer.concat([Buffer.from(`P6\n${cols} ${rows * 2}\n255\n`), px]));
console.log(`screen ${cols}x${rows} unpainted ${unpainted}`);
