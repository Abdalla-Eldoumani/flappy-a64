#!/usr/bin/env bash
# The game when things go wrong: a slow terminal, a stalled one, a terminal that closes, a
# closed pipe, stdin that is not a terminal, sizes far too small and far too large, and a best
# score file it cannot write. Each case checks how the game ends and that nothing else broke; a
# failing case names the checks that failed.
# usage, from build/: bash ../tests/harden.sh [runner]
set -u
here=$(cd "$(dirname "$0")" && pwd)
RUNNER=("$@")
bad=0
fails=""

# the player's best score is put aside for the run and put back at the end, even on an interrupt
if [ -e .flappy_best ]; then mv .flappy_best harden-best.real; fi
finish() {
  if [ -d .flappy_best ]; then rmdir .flappy_best; else rm -f .flappy_best; fi
  if [ -e harden-best.real ]; then mv harden-best.real .flappy_best; fi
}
trap finish EXIT

fail() { fails="$fails, $1"; }
report() {
  if [ -z "$fails" ]; then echo "PASS $1"; else echo "FAIL $1:${fails#,}"; bad=1; fi
  fails=""
}

# a pty session; prints pty_run's report, the capture lands in harden-NAME.out
run() {
  local name=$1; shift
  local opts=()
  while [ "$1" != "--" ]; do opts+=("$1"); shift; done
  shift
  timeout 120 python3 "$here/pty_run.py" --out "harden-$name.out" "${opts[@]}" -- "$@"
}
# the exit status pty_run reported, or "none" when it reported nothing
status() { awk '$1 == "status" { print $2; f = 1 } END { if (!f) print "none" }' <<< "$1"; }
# how many capture bytes had arrived when the key at time T went in
keyat() { awk -v t="$2" '$1 == "key" && $2 == t { print $3 }' <<< "$1"; }

# a check on a capture, in python: ends: it ends with the restore sequence; whole: every frame
# that opened synchronized output closed it, and nothing was cut (no CAN); recover: a frame was
# cut, CAN and ESC[0m follow, and the next frame clears the screen and paints every cell of
# COLSxROWS; has: it holds the bytes HEX; after: the restore starts at or after byte N
cap() {
  python3 - "$@" <<'EOF'
import re, sys
what, path = sys.argv[1], sys.argv[2]
d = open(path, "rb").read()
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m"
on, off = b"\x1b[?2026h", b"\x1b[?2026l"
ok = False
if what == "ends":
    ok = d.endswith(r)
elif what == "whole":
    ok = d.count(on) == d.count(off) > 0 and b"\x18" not in d
elif what == "recover":
    cols, rows = map(int, sys.argv[3].split("x"))
    i = d.find(b"\x18")
    if i > 0 and d[i:i + 5] == b"\x18\x1b[0m":
        s = d.find(on, i)
        e = d.find(off, s)
        frame = d[s:e] if s > 0 and e > 0 else b""
        text = re.sub(rb"\x1b\[[0-9;?]*[@-~]", b"", frame)
        cells = text.count(b" ") + text.count(b"\xe2\x96")
        ok = b"\x1b[2J" in frame and cells >= cols * rows
elif what == "has":
    ok = bytes.fromhex(sys.argv[3]) in d
elif what == "after":
    ok = sys.argv[3].isdigit() and d.find(r) >= int(sys.argv[3])
sys.exit(0 if ok else 1)
EOF
}

# the screen the capture leaves, cut where the restore starts: every cell painted
painted() {
  [ "$(timeout 60 node "$here/screen.mjs" "harden-$1.out" "$2" "$3" "harden-$1.ppm")" = \
    "screen $2x$3 unpainted 0" ]
}

# slow terminal: 256 bytes every 5 ms is far below what play writes, so writes come back short
# or with EAGAIN; every frame must still arrive whole, and the game quits cleanly
r=$(run slow --size 48x43 --deadline 60 --read-size 256 --read-delay 5 \
  --key 1.0:20 --key 2.0:20 --key 6.0:71 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
s=$(status "$r")
[ "$s" = 0 ] || fail "status $s"
cap ends harden-slow.out || fail "no restore at the end"
cap whole harden-slow.out || fail "a frame did not arrive whole"
painted slow 48 43 || fail "cells left unpainted"
report "slow terminal: short writes and EAGAIN, every frame whole, clean end"

# stalled terminal: nothing is read for 8 s, well past the 2,000 waits of 1 ms that end a frame
# early; the next frame must start with CAN and ESC[0m and repaint the whole screen
r=$(run stall --size 48x43 --deadline 60 --stall 2.0:8 \
  --key 1.0:20 --key 13.0:71 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
s=$(status "$r")
[ "$s" = 0 ] || fail "status $s"
cap ends harden-stall.out || fail "no restore at the end"
cap recover harden-stall.out 48x43 || fail "no CAN with a full repaint after the stall"
painted stall 48 43 || fail "cells left unpainted"
report "stalled terminal: a frame cut, then CAN, ESC[0m and a full repaint, clean end"

# the terminal closes: with SIGHUP ignored, the next write returns EIO and the game exits 0
# without a word; with SIGHUP as it comes, the signal ends it first
r=$(run eio --size 48x43 --deadline 20 --close 2.0 -- \
  sh -c 'trap "" HUP; exec "$@"' sh "${RUNNER[@]}" ./flappy --autopilot --seed 3)
s=$(status "$r")
[ "$s" = 0 ] || fail "status $s"
report "terminal closed with SIGHUP ignored: EIO, status 0"
r=$(run hup --size 48x43 --deadline 20 --close 2.0 -- "${RUNNER[@]}" ./flappy --autopilot --seed 3)
s=$(status "$r")
[ "$s" = -1 ] || fail "status $s"
report "terminal closed: SIGHUP ends it, status -1"

# a closed pipe: SIGPIPE ends the game with 141. The cut comes in the first frame, long before a
# run ends, so the best score check only shows that starting and drawing leave the file alone.
echo 5 > .flappy_best
timeout 60 "${RUNNER[@]}" ./flappy --render-out --ticks 600 --autopilot --seed 7 --size 144x128 | head -c 1000 > /dev/null
s=${PIPESTATUS[0]}
[ "$s" = 141 ] || fail "status $s"
[ "$(cat .flappy_best)" = 5 ] || fail "best score file changed"
rm -f .flappy_best
report "closed pipe: status 141, the best score file untouched by the start"

# stdin not a terminal: one line on stderr, status 2
timeout 20 "${RUNNER[@]}" ./flappy < /dev/null > harden-notty.out 2> harden-notty.err
s=$?
[ "$s" = 2 ] || fail "status $s"
[ "$(wc -l < harden-notty.err)" = 1 ] || fail "stderr is not one line"
grep -q "stdin is not a terminal" harden-notty.err || fail "no message"
[ -s harden-notty.out ] && fail "wrote to stdout"
report "stdin not a terminal: status 2, one line on stderr"

# 1x1: no line of the notice fits one column, and a line wider than the terminal is never
# drawn, so the screen is cleared and left empty; the game waits for q
r=$(run tiny --size 144x128 --deadline 20 --key 2.0:71 -- "${RUNNER[@]}" ./flappy --size 1x1)
s=$(status "$r")
[ "$s" = 0 ] || fail "status $s"
cap ends harden-tiny.out || fail "no restore at the end"
cap has harden-tiny.out "$(printf '\033[2J' | od -An -tx1 | tr -d ' \n')" || fail "no clear"
cap has harden-tiny.out "$(printf 'terminal' | od -An -tx1 | tr -d ' \n')" && fail "a notice line wider than the terminal"
cap after harden-tiny.out "$(keyat "$r" 2.0)" || fail "quit before the q"
report "--size 1x1: a cleared screen with no line wider than it, waits for q, clean end"

# 2000x2000 is taken as 999x999, the size the decimal table reaches: the s = 1 picture (144 x
# 128 cells) is centred there, so the first cell goes to row 436, column 428
r=$(run huge --size 144x128 --deadline 20 --key 1.0:20 --key 3.0:71 -- "${RUNNER[@]}" ./flappy --size 2000x2000 --autopilot)
s=$(status "$r")
[ "$s" = 0 ] || fail "status $s"
cap ends harden-huge.out || fail "no restore at the end"
cap has harden-huge.out "$(printf '\033[436;428H' | od -An -tx1 | tr -d ' \n')" || fail "not centred in 999x999"
report "--size 2000x2000: clamped to 999x999, clean end"

# a best score file that cannot be written: a directory in its place, since chmod means nothing
# to root, which WSL runs as; the run still exits 0 and nothing replaces the directory. The same
# run with no file then writes one, so the first run did reach a new best and tried to write it.
mkdir .flappy_best
timeout 60 "${RUNNER[@]}" ./flappy --render-out --ticks 1500 --autopilot --seed 7 --size 48x43 > /dev/null
s=$?
[ "$s" = 0 ] || fail "status $s"
[ -d .flappy_best ] || fail "the directory was replaced"
rmdir .flappy_best
timeout 60 "${RUNNER[@]}" ./flappy --render-out --ticks 1500 --autopilot --seed 7 --size 48x43 > /dev/null
grep -qx '[1-9][0-9]*' .flappy_best 2> /dev/null || fail "the same run writes no best, so nothing was tried"
rm -f .flappy_best
report "best score file not writable: status 0, nothing replaced it, a write was tried"
exit $bad
