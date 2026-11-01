#!/usr/bin/env bash
# Runs every tests/golden/NAME.args through --headless and compares with NAME.out.
# usage, from build/: bash ../tests/goldens.sh [runner] ./flappy
#   --write  regenerates the .out files instead (state the reason in the commit)
set -u
dir=$(cd "$(dirname "$0")" && pwd)/golden
write=0
if [ "${1:-}" = "--write" ]; then write=1; shift; fi
bad=0
for a in "$dir"/*.args; do
  n=$(basename "$a" .args)
  # shellcheck disable=SC2046
  got=$(timeout 300 "$@" --headless $(cat "$a")) || { echo "FAIL $n (exit $?)"; bad=1; continue; }
  if [ $write = 1 ]; then
    printf '%s\n' "$got" > "$dir/$n.out"; echo "WROTE $n"
  elif [ "$got" = "$(cat "$dir/$n.out")" ]; then
    echo "PASS $n"
  else
    echo "FAIL $n"; diff <(printf '%s\n' "$got") "$dir/$n.out" | head -5; bad=1
  fi
done
exit $bad
