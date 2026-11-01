#!/usr/bin/env bash
# Dumps named moments as PNGs and one contact sheet, build/frames/sheet.png, to look at.
# Each line: name seed tick size best. The autopilot plays, so a seed and a tick fix the
# moment; best is what .flappy_best holds before the run (0 leaves it empty).
# usage, from build/: bash ../tests/frames.sh [runner]
set -u
mkdir -p frames
bad=0
# the player's best score is put aside for the moments and put back at the end
if [ -e .flappy_best ]; then mv .flappy_best frames-best.real; fi
finish() {
  rm -f .flappy_best
  if [ -e frames-best.real ]; then mv frames-best.real .flappy_best; fi
}
trap finish EXIT
moments="
title_s1 1 20 144x128 42
title_s2 1 20 72x64 42
title_s3 1 20 48x43 42
title_s4 1 20 36x32 42
fade 1 41 144x128 0
ready_fadein 1 56 144x128 0
ready_day_gold 7 70 144x128 0
ready_day_coral 2 70 144x128 0
ready_day_violet 3 70 144x128 0
ready_night_gold 1 70 144x128 0
ready_night_coral 5 70 144x128 0
ready_night_violet 6 70 144x128 0
pipes3_s1 2 326 144x128 0
pipes3_s2 2 326 72x64 0
pipes3_s3 2 326 48x43 0
pipes3_s4 2 326 36x32 0
flash 2 10508 144x128 0
nosedive 2 10520 144x128 0
over_drop 1 6435 144x128 0
over_bounce 1 6441 144x128 0
over_slide 1 6455 144x128 0
over_count 1 6479 144x128 0
over_none 18 999 144x128 99
over_bronze 4 1217 144x128 0
over_silver 3 2007 144x128 0
over_gold 28 2799 144x128 0
over_platinum_s1 1 6544 144x128 0
over_platinum_s2 1 6544 72x64 0
over_platinum_s3 1 6544 48x43 0
over_platinum_s4 1 6544 36x32 0
"
row=()
sheet=()
while read -r name seed tick size best; do
  [ -n "$name" ] || continue
  d=frames/$name
  mkdir -p "$d"
  if [ "$best" = 0 ]; then : > .flappy_best; else printf '%s\n' "$best" > .flappy_best; fi
  timeout 300 "$@" ./flappy --render-out --ticks "$tick" --autopilot --seed "$seed" --size "$size" \
    --dump-frames "$tick" --dump-dir "$d" > /dev/null || { echo "FAIL $name"; bad=1; continue; }
  # whole-number upscaling keeps the pixels square, to at most 512 px tall
  s=$((512 / $(head -c 32 "$d/$tick.ppm" | sed -n 2p | cut -d' ' -f2)))
  pnmscale "$s" "$d/$tick.ppm" > "frames/$name.ppm"
  pnmtopng "frames/$name.ppm" > "frames/$name.png"
  row+=("frames/$name.ppm")
  if [ ${#row[@]} = 7 ]; then pnmcat -lr -jtop -white "${row[@]}" > "frames/row${#sheet[@]}.ppm"; sheet+=("frames/row${#sheet[@]}.ppm"); row=(); fi
  echo "frames/$name.png"
done <<< "$moments"
if [ ${#row[@]} -gt 0 ]; then pnmcat -lr -jtop -white "${row[@]}" > "frames/row${#sheet[@]}.ppm"; sheet+=("frames/row${#sheet[@]}.ppm"); fi
pnmcat -tb -jleft -white "${sheet[@]}" | pnmtopng > frames/sheet.png
echo "frames/sheet.png"
exit $bad
