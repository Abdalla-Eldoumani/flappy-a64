#!/usr/bin/env bash
# Plays the game on a pseudo-terminal: start, flap every way, pause, quit, Ctrl-C, Esc, a long
# autopilot run, and a kill. Each session must leave the terminal as it found it.
# usage, from build/: bash ../tests/pty-smoke.sh [runner]
set -u
here=$(cd "$(dirname "$0")" && pwd)
bad=0

# wraps the game so the capture shows its exit status and stty can compare the termios
session() {
  local name=$1; shift
  local opts=()
  while [ "$1" != "--" ]; do opts+=("$1"); shift; done
  shift
  timeout 60 python3 "$here/pty_run.py" --out "smoke-$name.out" "${opts[@]}" -- \
    sh -c 'f="import fcntl, os; print(fcntl.fcntl(0, fcntl.F_GETFL) & os.O_NONBLOCK)"
      { stty -g; python3 -c "$f"; } > "smoke-$0.before"; "$@"; echo "EXIT=$?"
      { stty -g; python3 -c "$f"; } > "smoke-$0.after"' \
    "$name" "${RUNNER[@]}" ./flappy "$@" > "smoke-$name.status"
}

# the game's output ends with the restore sequence; only the wrapper's EXIT line follows
verify() {
  local name=$1 want=$2 tail=$3
  if python3 - "smoke-$name.out" "$want" "$tail" <<'EOF'
import sys
d = open(sys.argv[1], "rb").read()
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m"
end = r + sys.argv[3].encode().decode("unicode_escape").encode("latin-1") + b"EXIT=" + sys.argv[2].encode() + b"\r\n"
sys.exit(0 if d.endswith(end) else 1)
EOF
  then
    if cmp -s "smoke-$name.before" "smoke-$name.after"; then echo "PASS $name"
    else echo "FAIL $name: termios or O_NONBLOCK differs after exit"; bad=1; fi
  else
    echo "FAIL $name: capture does not end with the restore sequence and EXIT=$want"
    tail -c 200 "smoke-$name.out" | od -c | tail -6; bad=1
  fi
}

RUNNER=("$@")

# flap by space, W, up arrow and a left click; pause and resume; quit with q
session keys --deadline 30 --key 1.0:20 --key 2.0:20 --key 2.4:77 --key 2.8:1b5b41 \
  --key 3.2:1b5b3c303b31303b31304d --key 3.6:70 --key 4.2:70 --key 4.6:71 -- --seed 3
verify keys 0 ""

# each flap key alone must leave the title and keep a run going: pipes, and so the pipe body
# colour of the day palette, reach the screen only in play. x is the control that must not.
pipe='118;196;52'
flapkey() {
  local name=$1 hex=$2 want=$3
  session "$name" --deadline 30 --key 1.0:$hex --key 1.6:$hex --key 2.1:$hex --key 2.6:$hex \
    --key 3.1:$hex --key 3.6:$hex --key 4.2:71 -- --seed 3
  verify "$name" 0 ""
  local got=0
  grep -qa "$pipe" "smoke-$name.out" && got=1
  if [ $got = $want ]; then echo "PASS $name reaches play: $got"
  else echo "FAIL $name reaches play: $got, want $want"; bad=1; fi
}
flapkey key-space 20 1
flapkey key-w 77 1
flapkey key-K 4b 1
flapkey key-cr 0d 1
flapkey key-lf 0a 1
flapkey key-up 1b5b41 1
flapkey key-click 1b5b3c303b31303b31304d 1
flapkey key-x 78 0

session ctrlc --deadline 30 --key 1.0:20 --key 2.0:20 --key 2.5:03 -- --seed 3
verify ctrlc 0 ""

# a lone Esc, with nothing after it, quits
session esc --deadline 30 --key 1.0:20 --key 2.0:1b -- --seed 3
verify esc 0 ""

# end to end on the autopilot for 14 s; --stats prints after the terminal is restored
session auto --deadline 40 --key 14.0:71 -- --autopilot --seed 3 --stats
if python3 - smoke-auto.out <<'EOF'
import re, sys
d = open(sys.argv[1], "rb").read()
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m"
m = re.search(re.escape(r) + rb"(\d+) (\d+) (\d+) (\d+)\r\nEXIT=0\r\n$", d)
if not m:
    sys.exit(1)
frames, ticks, dropped, ns = map(int, m.groups())
print(f"auto: frames {frames} ticks {ticks} dropped {dropped} elapsed {ns / 1e9:.2f} s")
sys.exit(0 if ticks >= 780 and frames == ticks else 1)
EOF
then
  if cmp -s smoke-auto.before smoke-auto.after; then echo "PASS auto"; else echo "FAIL auto: termios"; bad=1; fi
else
  echo "FAIL auto: no stats line, or frames and ticks off"; bad=1
fi

# a kill leaves no chance to restore; the next session must still start and quit cleanly
timeout 60 python3 "$here/pty_run.py" --out smoke-kill.out --deadline 20 --kill 2.0 \
  --key 1.0:20 -- "${RUNNER[@]}" ./flappy --seed 3 > smoke-kill.status
if grep -q "^status -15$" smoke-kill.status; then echo "PASS kill (status -15)"
else echo "FAIL kill: $(cat smoke-kill.status)"; bad=1; fi
session after --deadline 30 --key 1.0:71 -- --seed 3
verify after 0 ""

exit $bad
