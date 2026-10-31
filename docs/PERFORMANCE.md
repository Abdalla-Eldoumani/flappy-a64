# Performance

What the presenter costs, how that was measured, and which changes stayed. Each change was
measured before and after with the same command on the same machine, one change at a time.
A change stayed only if the number it aimed at moved and nothing else got worse.

## The commands

Every command runs a fixed seed through 3,600 ticks of autopilot, one minute of game time.
Run them from `build/`.

| Name | Command | Reports |
|---|---|---|
| E | `node ../tests/playground-check.mjs envelope 1` | The game as the AArch64 Playground's terminal pane runs it: lite profile, s = 3 at 48x43, for 60 s of virtual time or until a wall stops it. Steps and output bytes per second, against the playground's refill of 1,000,000 steps and 100,000 bytes a second. |
| B1 | `qemu-aarch64 ./flappy --bench --ticks 3600 --autopilot --seed 7 --size 144x128` | Bytes per rendered frame at s = 1 in the full profile, split into cursor moves, colour codes, glyphs and the rest. |
| B3 | `qemu-aarch64 ./flappy --bench --ticks 3600 --autopilot --seed 7 --size 48x43 --lite` | The same at s = 3 in the lite profile, which renders every second tick. |
| N | `./flappy --bench --ticks 3600 --autopilot --seed 7 --size 144x128`, built natively | Time per rendered frame on a native aarch64 Linux server, the mean of three runs. It is wall time from the monotonic clock, so it bounds the CPU time from above. |

E takes its seed from the playground's getrandom, which gives the same value on every run, so
its runs are as repeatable as the others. Under qemu the nanoseconds `--bench` prints measure
the emulator, so only N, on real hardware, is used for time.

The bytes depend on `build/.flappy_best`, because the title screen shows the best score, and
every autopilot run in `build/` rewrites that file. The numbers here were taken with a best
score of 12 in it; with no file at all B1's starting point reads 16,798 instead of 16,799.
N also moves by up to 2% between sessions on the server: a second set of runs gave 67.98 us
before and 22.90 us after.

## Changes

| Change | Command | Before | After | Outcome |
|---|---|---|---|---|
| Starting point | E | | 2,136,419 steps/s (213.6%), 86,753 B/s; the step budget ran out at 8.8 s | |
| Starting point | B1 / B3 | | 16,799 / 3,938 bytes a frame; colour codes are 74% / 79% of them | |
| Starting point | N | | 68.98 us a frame | |
| Colour codes and decimal numbers are copied as whole words instead of byte by byte | E | 2,136,419 steps/s, out at 8.8 s | 1,925,909 steps/s (192.6%), out at 10.8 s | kept |
| A changed block of eight cells finds its changed cells with a byte mask instead of testing all eight | E | 1,925,909 steps/s, out at 10.8 s | 1,806,465 steps/s (180.6%), out at 12.4 s | kept: a moving pipe edge changes one or two cells of a block, and the rest are now skipped |
| The cell encoder runs inside `present_frame`, with the pen, the cursor column and the output position in registers and no call per cell | E | 1,806,465 steps/s (180.6%), out at 12.4 s | 878,657 steps/s (87.9%), 121,303 B/s; ran the full 60 s | kept |
| The three kept changes together | N | 68.98 us a frame | 23.30 us a frame | |
| The three kept changes together | B1 / B3 | 16,799 / 3,938 | 16,799 / 3,938, the same bytes | |
| A solid cell the pen misses replaces the colour the last cell did not show, so two colours that take turns both stay in the pen | B1 / B3 | 16,799 / 3,938 | 16,919 / 3,930 | reverted: colour codes fell 4%, but the extra full blocks cost more than that at s = 1 |
| The same change | E | 878,657 steps/s, 121,303 B/s | 887,835 steps/s, 122,189 B/s | |
| Short gaps rewritten as spaces (below), tried on top of the change above | E | 878,657 steps/s, 121,303 B/s | 907,905 steps/s (90.8%), 118,559 B/s | set aside until steps had room |
| An unchanged block is tested with four loads and one compare pair, and the row's bottom pixel rows and width stay in registers for the row | E | 878,657 steps/s (87.9%) | 841,767 steps/s (84.2%), the same bytes | kept |
| A gap of one to three unchanged cells that are all the pen's background is written as spaces instead of jumped, which is fewer bytes | E | 841,767 steps/s, 121,303 B/s | 868,907 steps/s (86.9%), 118,559 B/s | kept: 2.3% fewer bytes, the target still missed, for 3.2% more steps that stay under 90% |
| The same change | B1 / B3 | 16,799 / 3,938 | 16,577 / 3,855 | |
| Every kept change | N | 68.98 us a frame | 23.32 us a frame | |
| Lite renders every third tick instead of every second | B3 | 1,800 frames of 3,938 bytes, 7.09 MB | 1,200 frames of 5,810 bytes, 6.97 MB | dropped: a pipe edge crosses a cell boundary 20 times a second at either rate, so the bytes barely move and the motion gets choppier |

A probe of only the first 120 ticks, mostly the title screen, showed no change for the byte
mask; E, which reaches the pipes, did. Every outcome above rests on E, B1, B3 or N.

Steps were the wall at the start (213.6% of the refill, out at 8.8 s), so the changes that cut
steps came before the ones that cut bytes. Colour codes already set the foreground and the
background in one sequence when both change. Wider SIMD loads were not needed: the time per
frame is twenty times under its target.

Gap rewriting was modelled before it was built. The s = 3 lite stream of B3's run (the same
arguments with `--render-out` in place of `--bench`), replayed on a model screen, has 146,346
cursor-forward moves, and rewriting the skipped cells with the pen as it stands would save
148,559 of its 7,089,008 bytes (2.1%). Built, it saved 148,532 bytes of that stream, and 1.3%
at s = 1.
Spaces win only when every skipped cell is the pen's background: `ESC[C` jumps one cell in 3
bytes and `ESC[nC` up to nine in 4, so one, two or three spaces are shorter and four are not.
Checking the skipped cells costs steps, so it waited for the cheaper block test above.

## Where it stands

| Target | Measured | Met |
|---|---|---|
| s = 1 full profile under 24 KB a frame on average in play | 16,577 bytes (B1) | yes |
| Nothing written on unchanged frames | 0 bytes, the minimum B1 and B3 report; a frame that changes no cell takes back its synchronized-output code | yes |
| CPU per rendered frame under 0.5 ms | 23.18 us of wall time at s = 1 (N, measured again on the final code), which bounds the CPU time | yes |
| Playground steps under 90% of the refill | 868,907 steps/s, 86.9% (E) | yes |
| Playground bytes under 90% of the refill | 118,559 B/s, 118.6% (E) | no |
| No stretch between sleeps near the 1,000,000-step stop | 170,526 steps at most, during set-up; no chunk at the stop (E) | yes |

The playground session is now bound by output, not steps. E projects 1.2 minutes, when the
8 MiB of output (4 MiB at the start and 4 MiB of refill) runs out, against 4.0 minutes for the
steps. The full check, `make envelope` (up to 15 minutes of virtual time), saw it happen: the
playground stopped the game at 68.4 s for printing too much, after 8,151,477 bytes, at
869,411 steps and 119,236 bytes a second.

A pipe at s = 3 has six vertical colour edges. Every edge that moves needs its own colour code,
about 16 bytes, on each row the pipe covers, so the byte rate stays near 118 KB/s while pipes
are on the screen. Rows 1 to 35 of the s = 3 screen, where the pipes are, carry almost all of
it; the ground rows below cost under 3 bytes a frame each. The pipe art is already at the four
bands the art direction asks for.

The lever left is an indexed-colour mode: set the palette once with OSC 4 and send each colour
as `ESC[38;5;Nm`. Replaying the same s = 3 stream with every 24-bit code rewritten that way
saves 29.9% of its bytes, which would take E from about 119 KB/s to about 83 KB/s. It is not
built, because it may only stay if Windows Terminal and @xterm/headless show the same screen
and the palette is restored on exit, and the Windows Terminal side has to be checked by eye.
