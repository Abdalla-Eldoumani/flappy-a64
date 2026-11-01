// A half-block cell's two colours as the screen shows them: [top, bottom] as 0xRRGGBB, -1 for a
// default colour (never painted), -2 for a character the game never writes and -3 for a palette
// index no OSC 4 has set. Palette colours resolve through PALETTE, a Map of index to 0xRRGGBB,
// when one is given.
export function halves(cell, palette) {
  const ch = cell.getChars();
  const fg = colour(cell.isFgRGB(), cell.isFgPalette(), cell.getFgColor(), palette);
  const bg = colour(cell.isBgRGB(), cell.isBgPalette(), cell.getBgColor(), palette);
  if (ch === ' ' || ch === '') return [bg, bg];
  if (ch === '█') return [fg, fg];
  if (ch === '▀') return [fg, bg];
  if (ch === '▄') return [bg, fg];
  return [-2, -2];
}

function colour(rgb, indexed, value, palette) {
  if (rgb) return value;
  if (indexed && palette) return palette.get(value) ?? -3;
  return -1;
}
