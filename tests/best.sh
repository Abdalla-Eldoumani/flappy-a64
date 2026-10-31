#!/usr/bin/env bash
# The best score file across runs: a run that ends writes its score, the next run reads it, a
# lower score leaves it alone, and a file that is not a number is ignored like a missing one.
# Seed 4's autopilot ends its first run at tick 1102 with a score from 10 to 19.
# usage, from build/: bash ../tests/best.sh [runner]
set -u
bad=0
dir=best
mkdir -p "$dir"
play() {
  timeout 300 "${RUNNER[@]}" ./flappy --render-out --autopilot --seed 4 --size 144x128 "$@" > /dev/null
}
# shot(name): the title frame at tick 20, where the best score shows
shot() {
  mkdir -p "$dir/$1"
  play --ticks 20 --dump-frames 20 --dump-dir "$dir/$1"
}
check() {
  if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1: got '$2', want '$3'"; bad=1; fi
}
RUNNER=("$@")

: > .flappy_best
shot empty
play --ticks 1110
score=$(cat .flappy_best)
case $score in
  1[0-9]) echo "PASS a finished run writes its score ($score)" ;;
  *) echo "FAIL a finished run wrote '$score'"; bad=1 ;;
esac

shot kept
if cmp -s "$dir/empty/20.ppm" "$dir/kept/20.ppm"; then
  echo "FAIL the next run's title does not show the saved best"; bad=1
else
  echo "PASS the next run reads the saved best"
fi

play --ticks 1110
check "an equal score leaves the file" "$(cat .flappy_best)" "$score"

printf '999\n' > .flappy_best
play --ticks 1110
check "a lower score leaves a higher best" "$(cat .flappy_best)" "999"

printf 'x7\n' > .flappy_best
shot corrupt
if cmp -s "$dir/empty/20.ppm" "$dir/corrupt/20.ppm"; then
  echo "PASS a corrupted file reads as no best"
else
  echo "FAIL a corrupted file changed the title"; bad=1
fi
play --ticks 1110
check "a corrupted file is replaced by the next best" "$(cat .flappy_best)" "$score"

printf '1234567890123456789012345\n' > .flappy_best
play --ticks 1110
check "a huge number clamps above any score and stays" "$(cat .flappy_best)" "1234567890123456789012345"

: > .flappy_best
exit $bad
