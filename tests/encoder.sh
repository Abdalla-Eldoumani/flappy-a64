#!/usr/bin/env bash
# Encoder equivalence at s = 1 and s = 3: 3,600 ticks of autopilot rendered to a byte stream,
# a frame dumped every 30th tick, then replayed through xterm.js and compared cell by cell.
# The lite profile, which draws with palette indexes, is checked the same way at s = 3 and s = 4.
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
exit $bad
