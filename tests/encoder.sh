#!/usr/bin/env bash
# Encoder equivalence at s = 1 and s = 3: 3,600 ticks of autopilot rendered to a byte stream,
# a frame dumped every 30th tick, then replayed through xterm.js and compared cell by cell.
# The lite profile, which draws with palette indexes, is checked the same way at s = 3 and s = 4.
# Last, the title's zoom hint is checked against the lite profile's largest scale.
# usage, from build/: bash ../tests/encoder.sh [runner]
set -u
here=$(cd "$(dirname "$0")" && pwd)
list=$(seq -s, 30 30 3600)
bad=0
# the autopilot reaches game over, so the player's best score is put aside and put back
if [ -e .flappy_best ]; then mv .flappy_best encoder-best.real; fi
finish() {
  rm -f .flappy_best
  if [ -e encoder-best.real ]; then mv encoder-best.real .flappy_best; fi
}
trap finish EXIT
for size in 144x128 48x43; do
  d=enc-$size
  mkdir -p "$d"
  timeout 900 "$@" ./flappy --render-out --ticks 3600 --autopilot --seed 7 --size "$size" \
    --dump-frames "$list" --dump-dir "$d" > "$d/stream.bin" || { echo "FAIL render $size"; bad=1; continue; }
  mv render.idx "$d/render.idx"
  timeout 900 node "$here/encoder-check.mjs" "$d/stream.bin" "$d/render.idx" "$d" "${size%x*}" "${size#*x}" || bad=1
done
# seed 3 goes from the night title through a fade into a day run, dies, shows a silver medal and
# fades into a night run; lite draws every second tick, and every frame of those stretches is
# checked, so each palette step is
lite=$({ seq 2 2 200; seq 210 30 1830; seq 1850 2 2110; } | paste -sd,)
for size in 48x43 36x32; do
  d=enc-lite-$size
  mkdir -p "$d"
  timeout 900 "$@" ./flappy --render-out --ticks 2110 --autopilot --seed 3 --size "$size" --lite \
    --dump-frames "$lite" --dump-dir "$d" > "$d/stream.bin" || { echo "FAIL render lite $size"; bad=1; continue; }
  mv render.idx "$d/render.idx"
  timeout 900 node "$here/encoder-check.mjs" "$d/stream.bin" "$d/render.idx" "$d" "${size%x*}" "${size#*x}" indexed || bad=1
done
# the title's ZOOM OUT hint is all it draws above the wordmark (GFX_WORD_Y, in logical pixels);
# lite never draws larger than s = 3, so it shows the hint only at s = 4, and full at both
runner=("$@")
word_y=52
hint() {
  local d=enc-hint-$1-$3 flag= w n got=hidden
  if [ "$3" = lite ]; then flag=--lite; fi
  mkdir -p "$d"
  timeout 60 "${runner[@]}" ./flappy --render-out --ticks 2 --seed 1 --size "$1" $flag \
    --dump-frames 2 --dump-dir "$d" > /dev/null || { echo "FAIL render hint $1 $3"; bad=1; return; }
  # a P6 frame: the width on its second line, the pixels after its third
  w=$(sed -n 2p "$d/2.ppm" | cut -d' ' -f1)
  n=$(tail -n +4 "$d/2.ppm" | head -c $((w * 3 * (word_y / $2))) | od -An -v -tx1 -w3 | sort -u | wc -l)
  if [ "$n" -gt 1 ]; then got=shown; fi
  if [ "$got" = "$4" ]; then echo "PASS title hint $1 $3 $got"
  else echo "FAIL title hint $1 $3: $got, want $4"; bad=1; fi
}
hint 48x43 3 full shown
hint 48x43 3 lite hidden
hint 36x32 4 full shown
hint 36x32 4 lite shown
exit $bad
