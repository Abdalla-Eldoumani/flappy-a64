# flappy-a64

Flappy Bird's gameplay, written in AArch64 assembly and played in a terminal. The physics, the
layout, the timing and the flow follow the original game. The art is mine. I drew the bird,
the pipes, the city, the font and the medals for this.

![The title, mid flight, and game over with a platinum medal](docs/screens.png)

It draws with half blocks and 24-bit colour at up to 60 frames a second. Each terminal cell
holds two pixels, and each frame sends only the cells that changed since the one before.

## Run it

On Windows, inside WSL (Ubuntu or Debian):

```
sudo apt install make m4 gcc-aarch64-linux-gnu libc6-dev-arm64-cross qemu-user
git clone https://github.com/Abdalla-Eldoumani/flappy-a64
cd flappy-a64
make play
```

`make play` builds a static aarch64 binary and runs it with `qemu-aarch64`. On an aarch64
Linux machine the same `make play` builds with the native `gcc` and runs the program directly.

The release carries the static binary, `flappy-linux-arm64`. An aarch64 Linux machine runs it
as it is. Anywhere else, run it as `qemu-aarch64 ./flappy-linux-arm64`.

## Controls

| Key | Does |
|---|---|
| Space, W, K, up arrow, Enter, left click | flap, start, play again |
| P | pause |
| D | debug numbers: frames a second, bytes per frame, scale |
| Q, Esc, Ctrl-C | quit |

The game keeps the best score in `.flappy_best`, in the folder it runs from. For `make play`
that is `build/`.

## Terminal size

The game is 144 by 256 pixels. At full size, s = 1, it needs a terminal 144 columns wide and
128 rows tall. A smaller window gets a smaller picture: s = 2 needs 72 by 64, s = 3 48 by 43,
and s = 4 36 by 32. Below that, the game shows the size it has and the size it needs, and
waits. At any s above 1 the title says ZOOM OUT.

In Windows Terminal:

- Ctrl and minus makes the font one point smaller, Ctrl and plus one point bigger, and Ctrl
  and 0 puts it back.
- F11, or Alt and Enter, switches full screen on and off.
- A maximised window on a 1080p screen at 100% display scaling reaches s = 1 with a font of
  about 4 to 5 points. That is my estimate, not a measurement.

## How it works

**The frame.** Every tick the game draws the whole scene into a byte buffer, one palette index
per pixel, at the scale the terminal allows. Shrinking keeps the most important colour in each
block, outlines first, so edges survive. The bird has its own small drawing for each smaller
size, and the words use a smaller pixel font.

**Half blocks.** A terminal cell shows two pixels, one above the other. When both match, the
cell is a space in that background colour or a full block in that foreground colour. Two
different pixels become an upper or a lower half block, whichever keeps the colours the
terminal already has set.

**The diff.** The presenter keeps the last frame and compares the new one eight cells at a
time, and it writes only the cells that changed. Where one to three unchanged cells sit in the
current background colour, writing them as spaces is shorter than moving the cursor, so it
does that. Synchronized output wraps each frame, so a terminal that supports it never shows
half of one. A frame where nothing changed writes nothing.

**Pacing.** Ticks run at exactly 60 a second from the monotonic clock. Two periods of
16,666,667 ns and one of 16,666,666 make 50 ms for every three ticks. A game that falls behind
runs up to five ticks to catch up and drops the rest.

Numbers from the autopilot, seed 7, 3,600 ticks, with more in
[docs/PERFORMANCE.md](docs/PERFORMANCE.md):

- At s = 1 the game writes 16.6 KB per frame on average. Three quarters of that is colour codes.
- A frame takes 23 microseconds on a native aarch64 Linux server.

The program uses twelve system calls and no others. It calls no library functions, has no
heap, and keeps every section under 1 MiB, so it can later run in the AArch64 Playground's
terminal pane.

## Build and test

- `make` builds `build/flappy`. `make bundle` writes the whole program as one file,
  `dist/flappy-bundle.asm`.
- `make test` runs the checks below. It needs python3, and Node.js 24 for the terminal
  replays. The Makefile installs `@xterm/headless` with `npm ci`.
  - goldens: headless runs print the game state every 60 ticks, and ten recorded runs must
    match byte for byte, from the normal build and from the one-file bundle.
  - physics: an independent Python model of the game must print the same lines.
  - encoder: a headless terminal replays what the presenter wrote, and every cell must match
    the frame it should show.
  - smoke: the game plays on a pseudo-terminal with every flap key, pause, a resize, a window
    too small, quit, Ctrl-C and a kill.
  - best: the best score file is written, read back, and ignored when it is not a number.
  - harden: a slow terminal, a stalled one, one that closes, a closed pipe, no terminal at all,
    sizes far too small and too large, a best score file that cannot be written, and a
    folder for frame dumps too long for the file path.
- `make frames` renders named moments to PNGs and a contact sheet. It needs netpbm.
- `make soak` plays on the autopilot for ten minutes. `make envelope` measures what a session
  costs in the playground.
- `make playground`, part of `make test`, and `make envelope` run the bundle in the AArch64
  Playground's emulator. That emulator is not in this repository: copy its wasm-node build to
  `build/playground-wasm`, or the two targets print that they were skipped.
- `./flappy --headless --ticks N --seed S` prints the game state without a terminal,
  `--autopilot` plays by itself, and `--bench` prints the cost of every frame.

## Credits

The gameplay is Dong Nguyen's Flappy Bird. The physics start from the classic constants of
FlapPyBird, which is MIT licensed. I made everything in this repository for it, the art and
the font included.

## License

MIT. See [LICENSE](LICENSE).
