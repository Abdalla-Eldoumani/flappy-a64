#!/usr/bin/env bash
# The game when things go wrong: a slow terminal, a stalled one, a terminal that closes, a
# closed pipe, stdin that is not a terminal, sizes far too small and far too large, and a best
# score file it cannot write. Each case checks how the game ends and that nothing else broke.
# usage, from build/: bash ../tests/harden.sh [runner]
set -u
here=$(cd "$(dirname "$0")" && pwd)
RUNNER=("$@")
bad=0
say() { if [ "$1" = 0 ]; then echo "PASS $2"; else echo "FAIL $2"; bad=1; fi; }

# a pty session; prints pty_run's report, the capture lands in harden-NAME.out
run() {
  local name=$1; shift
  local opts=()
  while [ "$1" != "--" ]; do opts+=("$1"); shift; done
  shift
  timeout 120 python3 "$here/pty_run.py" --out "harden-$name.out" "${opts[@]}" -- "$@"
}
status() { awk '$1 == "status" { print $2 }' <<< "$1"; }

# true when the capture ends with the restore sequence, and, given a byte, contains it
ends_clean() {
  python3 - "$1" "${2:-}" <<'EOF'
import sys
d = open(sys.argv[1], "rb").read()
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m"
ok = d.endswith(r)
if sys.argv[2]:
    ok = ok and bytes.fromhex(sys.argv[2]) in d
sys.exit(0 if ok else 1)
EOF
}

# the screen the capture leaves, cut where the restore starts: every cell painted
painted() {
  [ "$(timeout 60 node "$here/screen.mjs" "harden-$1.out" "$2" "$3" "harden-$1.ppm")" = \
    "screen $2x$3 unpainted 0" ]
}

# slow terminal: 256 bytes every 5 ms is far below what play writes, so writes come back short
# or with EAGAIN; the game falls behind, drops ticks, and still quits cleanly
r=$(run slow --size 48x43 --deadline 60 --read-size 256 --read-delay 5 \
  --key 1.0:20 --key 2.0:20 --key 6.0:71 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
ends_clean harden-slow.out; e=$?
painted slow 48 43; p=$?
say $(( $(status "$r") != 0 || e || p )) "slow terminal: status $(status "$r"), clean end, every cell painted"

# stalled terminal: nothing is read for 4 s, so a frame cannot finish within the 2 s cap; the
# next frame must start with CAN and ESC[0m and repaint everything
r=$(run stall --size 48x43 --deadline 60 --stall 2.0:4 \
  --key 1.0:20 --key 9.0:71 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
ends_clean harden-stall.out 181b5b306d; e=$?
painted stall 48 43; p=$?
say $(( $(status "$r") != 0 || e || p )) "stalled terminal: status $(status "$r"), CAN then a repaint, clean end"

# the terminal closes: with SIGHUP ignored, the next write returns EIO and the game exits 0
# without a word; with SIGHUP as it comes, the signal ends it first
r=$(run eio --size 48x43 --deadline 20 --close 2.0 -- \
  sh -c 'trap "" HUP; exec "$@"' sh "${RUNNER[@]}" ./flappy --autopilot --seed 3)
say $(( $(status "$r") != 0 )) "terminal closed, SIGHUP ignored: status $(status "$r") from EIO"
r=$(run hup --size 48x43 --deadline 20 --close 2.0 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
s=$(status "$r")
say $(( s != -1 && s != 0 )) "terminal closed: status $s (-1 is SIGHUP)"

# a closed pipe: SIGPIPE ends the game with 141, and the best score file is left as it was
had=0
if [ -e .flappy_best ]; then cp .flappy_best harden-best.keep; had=1; fi
timeout 60 "${RUNNER[@]}" ./flappy --render-out --ticks 600 --autopilot --seed 7 --size 144x128 | head -c 1000 > /dev/null
s=${PIPESTATUS[0]}
same=0
if [ $had = 1 ]; then cmp -s .flappy_best harden-best.keep || same=1; fi
say $(( s != 141 || same )) "closed pipe: status $s, best score file unchanged"

# stdin not a terminal: one line on stderr, status 2
timeout 20 "${RUNNER[@]}" ./flappy < /dev/null > harden-notty.out 2> harden-notty.err
s=$?
grep -q "stdin is not a terminal" harden-notty.err; g=$?
say $(( s != 2 || g || $(wc -l < harden-notty.err) != 1 )) "stdin not a terminal: status $s, $(wc -l < harden-notty.err) line on stderr"

# sizes: 1x1 shows the notice and waits for q; 2000x2000 is taken as 999x999 and plays
r=$(run tiny --size 144x128 --deadline 20 --key 2.0:71 -- "${RUNNER[@]}" ./flappy --size 1x1)
ends_clean harden-tiny.out; e=$?
say $(( $(status "$r") != 0 || e )) "--size 1x1: status $(status "$r"), clean end"
r=$(run huge --size 144x128 --deadline 20 --key 1.0:20 --key 3.0:71 -- "${RUNNER[@]}" ./flappy --size 2000x2000 --autopilot)
ends_clean harden-huge.out; e=$?
say $(( $(status "$r") != 0 || e )) "--size 2000x2000: status $(status "$r"), clean end"

# a best score file that cannot be written: a directory in its place; runs that end still exit 0
moved=0
if [ -e .flappy_best ]; then mv .flappy_best harden-best.real; moved=1; fi
mkdir .flappy_best
timeout 60 "${RUNNER[@]}" ./flappy --render-out --ticks 1500 --autopilot --seed 7 --size 48x43 > /dev/null
s=$?
[ -d .flappy_best ]; d=$?
rmdir .flappy_best
if [ $moved = 1 ]; then mv harden-best.real .flappy_best; fi
say $(( s != 0 || d )) "best score file not writable: status $s, nothing replaced it"
exit $bad
