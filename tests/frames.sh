#!/usr/bin/env bash
# Dumps named moments as PNGs and one contact sheet, build/frames/sheet.png, to look at.
# Each line: name seed tick size. The autopilot plays, so a seed and a tick fix the moment.
# usage, from build/: bash ../tests/frames.sh [runner]
set -u
mkdir -p frames
bad=0
moments="
title 1 20 144x128
ready_day_gold 7 61 144x128
ready_day_coral 2 61 144x128
ready_day_violet 3 61 144x128
ready_night_gold 1 61 144x128
ready_night_coral 5 61 144x128
ready_night_violet 3 2043 144x128
pipes3_s1 2 326 144x128
pipes3_s2 2 326 72x64
pipes3_s3 2 326 48x43
pipes3_s4 2 326 36x32
nosedive 3 1876 144x128
over 3 1992 144x128
"
row=()
sheet=()
while read -r name seed tick size; do
  [ -n "$name" ] || continue
  d=frames/$name
  mkdir -p "$d"
  timeout 120 "$@" ./flappy --render-out --ticks "$tick" --autopilot --seed "$seed" --size "$size" \
    --dump-frames "$tick" --dump-dir "$d" > /dev/null || { echo "FAIL $name"; bad=1; continue; }
  # whole-number upscaling keeps the pixels square: every frame ends 512 px tall
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
