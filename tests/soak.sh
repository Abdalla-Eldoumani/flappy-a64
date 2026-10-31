#!/usr/bin/env bash
# Ten minutes of autopilot at s = 1 on a pseudo-terminal: it must not crash, its frames must be
# within 1% of the elapsed time at 60 a second, and the best score file must still hold a number
# no lower than the one it started from.
# usage, from build/: bash ../tests/soak.sh [runner]; SOAK_SECONDS shortens it for a trial
set -u
here=$(cd "$(dirname "$0")" && pwd)
secs=${SOAK_SECONDS:-600}

# the player's best score is put aside and put back at the end; the soak starts from 1
if [ -e .flappy_best ]; then mv .flappy_best soak-best.real; fi
finish() {
  rm -f .flappy_best
  if [ -e soak-best.real ]; then mv soak-best.real .flappy_best; fi
}
trap finish EXIT
echo 1 > .flappy_best

timeout $((secs + 120)) python3 "$here/pty_run.py" --out soak.out --size 144x128 \
  --deadline $((secs + 60)) --key "$secs:71" -- "$@" ./flappy --autopilot --stats > soak.status
python3 - soak.out soak.status <<'EOF'
import re, sys
d = open(sys.argv[1], "rb").read()
st = open(sys.argv[2]).read()
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m"
m = re.search(re.escape(r) + rb"(\d+) (\d+) (\d+) (\d+)\r\n$", d)
status = re.search(r"status (-?\d+)", st)
if not m or not status:
    print("FAIL soak: no stats line after the restore, or no exit status")
    sys.exit(1)
frames, ticks, dropped, ns = map(int, m.groups())
want = ns / 1e9 * 60
off = abs(frames - want) / want
print(f"soak: status {status.group(1)}, frames {frames}, ticks {ticks}, dropped {dropped}, "
      f"elapsed {ns / 1e9:.1f} s, {100 * off:.2f}% from 60 a second")
sys.exit(0 if status.group(1) == "0" and off <= 0.01 else 1)
EOF
s=$?
best=$(cat .flappy_best 2> /dev/null)
if [[ "$best" =~ ^[0-9]+$ ]] && [ "$best" -ge 1 ]; then echo "best score file: $best"
else echo "FAIL soak: best score file holds '$best', not a number of at least 1"; s=1; fi
[ $s = 0 ] && echo "PASS soak"
exit $s
