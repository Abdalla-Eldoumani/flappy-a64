// A half-block cell's two colours as the screen shows them: [top, bottom] as 0xRRGGBB, -1 for a
// default colour (never painted) and -2 for a character the game never writes.
export function halves(cell) {
  const ch = cell.getChars();
  const fg = cell.isFgRGB() ? cell.getFgColor() : -1;
  const bg = cell.isBgRGB() ? cell.getBgColor() : -1;
  if (ch === ' ' || ch === '') return [bg, bg];
  if (ch === '█') return [fg, fg];
  if (ch === '▀') return [fg, bg];
  if (ch === '▄') return [bg, fg];
  return [-2, -2];
}
