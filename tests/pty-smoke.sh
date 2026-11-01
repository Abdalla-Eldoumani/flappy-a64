#!/usr/bin/env bash
# Plays the game on a pseudo-terminal: start, flap every way, pause, quit, Ctrl-C, Esc, a long
# autopilot run, the profile each terminal gets, and kills. Each session must leave the terminal
# as it found it.
# usage, from build/: bash ../tests/pty-smoke.sh [runner]
set -u
here=$(cd "$(dirname "$0")" && pwd)
bad=0
# an interrupt ends the run after the session it lands in; the sessions run in the foreground
# group, so Ctrl-C reaches them at once
trap 'exit 130' INT
trap 'exit 143' TERM
# the autopilot sessions reach game over, so the player's best score is put aside and put back
if [ -e .flappy_best ]; then mv .flappy_best smoke-best.real; fi
finish() {
  rm -f .flappy_best
  if [ -e smoke-best.real ]; then mv smoke-best.real .flappy_best; fi
}
trap finish EXIT

# wraps the game so the capture shows its exit status and stty can compare the termios; a
# --kill reaches the wrapper too, which outlives it to report the game's status
session() {
  local name=$1; shift
  local opts=()
  while [ "$1" != "--" ]; do opts+=("$1"); shift; done
  shift
  timeout --foreground 60 python3 "$here/pty_run.py" --out "smoke-$name.out" "${opts[@]}" -- \
    sh -c 'f="import fcntl, os; print(fcntl.fcntl(0, fcntl.F_GETFL) & os.O_NONBLOCK)"
      trap : TERM
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
# The first pipe shows about 1.7 s into play; q waits over 3 s past the press that starts play,
# so a loaded machine still gets there.
pipe='118;196;52'
flapkey() {
  local name=$1 hex=$2 want=$3
  session "$name" --deadline 30 --key 1.0:$hex --key 1.6:$hex --key 2.1:$hex --key 2.6:$hex \
    --key 3.1:$hex --key 3.6:$hex --key 5.2:71 -- --seed 3
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

# the lite profile sets the terminal's palette, so q, Ctrl-C and Esc each end with the restore
# and then OSC 104, which gives the terminal its own palette back
unpal='\x1b]104\x1b\\'
for k in q:71 ctrlc:03 esc:1b; do
  session "lite-${k%%:*}" --size 48x43 --deadline 30 --key 1.0:20 --key 2.0:20 --key "3.0:${k#*:}" \
    -- --lite --seed 3
  verify "lite-${k%%:*}" 0 "$unpal"
done

# the too-small notice gives the palette back when it replaces the picture, the picture's return
# sends the game's palette again before it, and q on the notice ends like any other way out
session lite-small --size 48x43 --deadline 30 --key 1.0:20 --resize 2.0:30x20 --resize 3.5:48x43 \
  --resize 5.0:30x20 --key 6.5:71 -- --lite --seed 3
verify lite-small 0 "$unpal"
if python3 - smoke-lite-small.out <<'EOF'
import sys
d = open(sys.argv[1], "rb").read()
osc4, unpal, notice = b"\x1b]4;", b"\x1b]104\x1b\\", b"terminal is"
first = d.find(osc4)
gone = d.find(unpal, first)
back = d.find(osc4, gone)
again = d.find(unpal, back)
sys.exit(0 if 0 <= first < gone < back < again and notice in d[first:gone] and notice in d[back:again] else 1)
EOF
then echo "PASS lite-small: the palette goes back with the notice and returns with the picture"
else echo "FAIL lite-small: no palette restore with the notice, or no palette before the picture's return"; bad=1; fi

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
# a catch-up tick on a loaded machine costs a frame, so frames need only be within 1% of the
# ticks, as in the soak
sys.exit(0 if ticks >= 780 and frames >= 0.99 * ticks else 1)
EOF
then
  if cmp -s smoke-auto.before smoke-auto.after; then echo "PASS auto"; else echo "FAIL auto: termios"; bad=1; fi
else
  echo "FAIL auto: no stats line, or frames and ticks off"; bad=1
fi

# at(session, time): how many capture bytes had arrived when that event fired
at() { awk -v t="$2" '$2 == t { print $3 }' "smoke-$1.status"; }

# a whole game by hand: title, ready, play, a fall to the ground, game over with a press inside
# its lockout that must change nothing, restart, pause, resume, play again, quit. The screen at
# each step comes from replaying the capture in a terminal emulator. Resizes to the same size
# only mark the title (0.9) and play (2.6) moments.
session walk --deadline 40 --resize 0.9:144x128 --key 1.0:20 --key 1.8:20 --resize 2.6:144x128 \
  --key 3.6:20 --key 5.0:20 --key 6.0:70 --resize 6.6:144x128 --key 7.6:70 --key 8.0:20 \
  --key 8.6:71 -- --seed 3
verify walk 0 ""
for t in 0.9 1.8 2.6 3.6 5.0 6.0 6.6; do
  timeout 60 node "$here/screen.mjs" smoke-walk.out 144 128 "smoke-walk-$t.ppm" "@$(at walk "$t")" > /dev/null
done
if python3 - smoke-walk "$(at walk 6.6)" "$(at walk 7.6)" <<'EOF'
import sys
def colours(path, rows=None):
    b = open(path, "rb").read().split(b"\n", 3)
    w = int(b[1].split()[0])
    px = b[3][:rows * w * 3] if rows else b[3]
    return {px[i:i + 3] for i in range(0, len(px), 3)}
# the panel, the orange of the big words, and the score's white, which only ready and play
# show in the top rows
panel, word, white = bytes([238, 228, 170]), bytes([252, 168, 48]), bytes([255, 255, 255])
n, paused, resumed = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
title, ready, play, press, over, again = (colours(f"{n}-{t}.ppm") for t in ("0.9", "1.8", "2.6", "3.6", "5.0", "6.0"))
top = {t: white in colours(f"{n}-{t}.ppm", 40) for t in ("0.9", "1.8", "2.6", "6.0")}
bad = []
if word not in title or top["0.9"] or panel in title:
    bad.append("no title screen at the start")
if word not in ready or not top["1.8"] or panel in ready:
    bad.append("no get ready screen before play")
if word in play or not top["2.6"] or panel in play:
    bad.append("no play screen after the flap")
if panel not in press:
    bad.append("the press meant for the lockout did not land on the game over screen")
if panel not in over:
    bad.append("no game over panel after the fall, or the press in the lockout restarted")
if panel in again or word not in again or not top["6.0"]:
    bad.append("no get ready screen after the restart")
if open(f"{n}-6.0.ppm", "rb").read() == open(f"{n}-6.6.ppm", "rb").read():
    bad.append("pausing drew nothing")
if resumed != paused:
    bad.append(f"{resumed - paused} bytes written while paused")
if len(open(f"{n}.out", "rb").read()) <= resumed:
    bad.append("nothing drawn after resuming")
if bad:
    print("; ".join(bad))
sys.exit(1 if bad else 0)
EOF
then echo "PASS walk: title, ready, play, over, lockout, restart, pause, resume"
else echo "FAIL walk"; bad=1; fi

# D shows the debug numbers in the top left corner, where nothing else is pure white
session debug --deadline 30 --resize 1.5:144x128 --key 2.0:64 --resize 3.5:144x128 --key 4.0:71 \
  -- --autopilot --seed 3
verify debug 0 ""
for t in 1.5 3.5; do
  timeout 60 node "$here/screen.mjs" smoke-debug.out 144 128 "smoke-debug-$t.ppm" "@$(at debug "$t")" > /dev/null
done
if python3 - smoke-debug <<'EOF'
import sys
def corner_white(path):
    b = open(path, "rb").read().split(b"\n", 3)
    w = int(b[1].split()[0])
    px = b[3]
    return any(px[(y * w + x) * 3:(y * w + x) * 3 + 3] == b"\xff\xff\xff" for y in range(40) for x in range(60))
sys.exit(0 if not corner_white(f"{sys.argv[1]}-1.5.ppm") and corner_white(f"{sys.argv[1]}-3.5.ppm") else 1)
EOF
then echo "PASS debug: the overlay appears after D"
else echo "FAIL debug: no overlay after D, or white in the corner before it"; bad=1; fi

# a resize mid-play repaints at the new scale with its border, then back at the first
session resize --deadline 30 --resize 3.0:60x50 --resize 5.0:144x128 --key 7.0:71 -- --autopilot --seed 3
verify resize 0 ""
r1=$(at resize 3.0); r2=$(at resize 5.0)
s3=$(timeout 60 node "$here/screen.mjs" smoke-resize.out 144 128 smoke-resize-s3.ppm "$r1:60x50" "@$r2")
s1=$(timeout 60 node "$here/screen.mjs" smoke-resize.out 144 128 smoke-resize-s1.ppm "$r1:60x50" "$r2:144x128")
if [ "$s3" = "screen 60x50 unpainted 0" ] && [ "$s1" = "screen 144x128 unpainted 0" ]; then
  echo "PASS resize: $s3; $s1"
else echo "FAIL resize: $s3; $s1"; bad=1; fi

# too small: a centred message with the size it has, the size it needs and how to get there, as
# the terminal shows it; growing the window starts the game
session small --size 30x20 --deadline 30 --resize 2.0:48x43 --key 4.0:71 -- --seed 3
verify small 0 ""
grown=$(at small 2.0)
note=$(timeout 60 node "$here/screen.mjs" smoke-small.out 30 20 - "@$grown")
want=$(printf '%s\n' '' '' '' '' '' '' '' '      terminal is 30x20' '     the game needs 36x32' \
  '        to zoom out in' '      Windows Terminal,' '     press Ctrl and minus' \
  '      or make it bigger' '' '' '' '' '' '' '')
sm=$(timeout 60 node "$here/screen.mjs" smoke-small.out 30 20 smoke-small.ppm "$grown:48x43")
if [ "$note" = "$want" ] && [ "$sm" = "screen 48x43 unpainted 0" ]; then
  echo "PASS small: centred notice, then $sm"
else
  echo "FAIL small: $sm; the screen at 30x20 was:"; printf '%s\n' "$note" | sed 's/^/  |/'; bad=1
fi

# narrower than the notice's lines: a line wider than the terminal is never drawn, so each size
# goes under its words and the tips are left out
session narrow --size 16x10 --deadline 30 --key 2.0:71 -- --seed 3
verify narrow 0 ""
quit=$(at narrow 2.0)
note=$(timeout 60 node "$here/screen.mjs" smoke-narrow.out 16 10 - "@$quit")
want=$(printf '%s\n' '' '' '' '  terminal is' '     16x10' ' the game needs' '     36x32' '' '' '')
if [ "$note" = "$want" ]; then echo "PASS narrow: each size under its words, no tips"
else
  echo "FAIL narrow: the screen at 16x10 was:"; printf '%s\n' "$note" | sed 's/^/  |/'; bad=1
fi

# the profile with nothing typed. A terminal whose control characters all read 0, as only the
# playground's TCGETS gives them, takes the lite profile at the size it reports: 80x70 is s = 2
# with its first cell at 4;5 (the 80x24 guessed for no size fits no scale), and the polling takes
# a resize to 50x45 to s = 3, first cell at 2;2. A normal terminal takes 24-bit colour and a frame
# every tick, and --lite still forces the lite profile there.
session prof-cc --cc-off --size 80x70 --deadline 30 --resize 3.0:50x45 --key 5.0:71 \
  -- --autopilot --seed 3 --stats
session prof-full --size 48x43 --deadline 30 --key 4.0:71 -- --autopilot --seed 3 --stats
session prof-lite --size 48x43 --deadline 30 --key 4.0:71 -- --autopilot --seed 3 --stats --lite
for p in prof-cc:lite prof-full:full prof-lite:lite; do
  n=${p%%:*}
  if python3 - "smoke-$n.out" "${p#*:}" "$(at "$n" 3.0)" <<'EOF'
import re, sys
name, d = sys.argv[1][6:-4], open(sys.argv[1], "rb").read()
lite, at = sys.argv[2] == "lite", sys.argv[3]
r = b"\x1b[?1006l\x1b[?1000l\x1b[?7h\x1b[?25h\x1b[?1049l\x1b[0m" + (b"\x1b]104\x1b\\" if lite else b"")
m = re.search(re.escape(r) + rb"(\d+) (\d+) \d+ \d+\r\nEXIT=0\r\n$", d)
# the colour codes: 2 for 24-bit, 5 for a palette index
kinds = set()
for p in re.findall(rb"\x1b\[([0-9;]*)m", d):
    t, i = p.split(b";"), 0
    while i < len(t):
        if t[i] in (b"38", b"48") and i + 1 < len(t):
            kinds.add(t[i + 1].decode()); i += 5 if t[i + 1] == b"2" else 3
        else:
            i += 1
bad = []
if not m:
    bad.append("no restore, stats line and EXIT=0 at the end")
    frames = ticks = 0
else:
    frames, ticks = int(m[1]), int(m[2])
if kinds != ({"5"} if lite else {"2"}):
    bad.append(f"colour codes {sorted(kinds)}")
if (b"\x1b]4;" in d) != lite:
    bad.append("OSC 4 where it should not be, or none where it should")
# lite draws every second tick; within 1% of the ticks allows a catch-up tick on a loaded machine
if ticks < 120 or (frames > 0.55 * ticks if lite else frames < 0.99 * ticks):
    bad.append(f"frames {frames} for ticks {ticks}")
if at:
    cut = int(at)
    if b"\x1b[4;5H" not in d[:cut] or b"\x1b[2;2H" not in d[cut:]:
        bad.append("not s = 2 at 80x70, then s = 3 after the resize")
print(f"{name}: {'lite' if lite else 'full'}, colour codes {sorted(kinds)}, frames {frames} ticks {ticks}" + (f"; {'; '.join(bad)}" if bad else ""))
sys.exit(1 if bad else 0)
EOF
  then
    if cmp -s "smoke-$n.before" "smoke-$n.after"; then echo "PASS $n"; else echo "FAIL $n: termios"; bad=1; fi
  else echo "FAIL $n"; bad=1; fi
done

# SIGTERM in --lite gives the terminal back as q does, the palette too, and the game exits 143, as
# a shell reports a death by SIGTERM
session lite-term --size 48x43 --deadline 30 --key 1.0:20 --kill 3.0 -- --lite --seed 3
verify lite-term 143 "$unpal"

# a kill leaves no chance to restore; the next session must still start and quit cleanly
timeout --foreground 60 python3 "$here/pty_run.py" --out smoke-kill.out --deadline 20 --kill 2.0 \
  --key 1.0:20 -- "${RUNNER[@]}" ./flappy --seed 3 > smoke-kill.status
if grep -q "^status -15$" smoke-kill.status; then echo "PASS kill (status -15)"
else echo "FAIL kill: $(cat smoke-kill.status)"; bad=1; fi
# with the playground's sign the lite profile installs no handler, as in the playground, where
# rt_sigaction would stop the game, so SIGTERM ends it as it ends the full profile
timeout --foreground 60 python3 "$here/pty_run.py" --out smoke-cckill.out --cc-off --deadline 20 \
  --kill 2.0 --key 1.0:20 -- "${RUNNER[@]}" ./flappy --seed 3 > smoke-cckill.status
if grep -q "^status -15$" smoke-cckill.status && grep -qaF "$(printf '\033]4;')" smoke-cckill.out; then
  echo "PASS cc-off kill: lite, no handler (status -15)"
else echo "FAIL cc-off kill: $(cat smoke-cckill.status)"; bad=1; fi
session after --deadline 30 --key 1.0:71 -- --seed 3
verify after 0 ""

exit $bad
