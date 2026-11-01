# Performance

What the presenter costs, how that was measured, and which changes stayed. Each change was
measured before and after with the same command on the same machine, one change at a time.
A change stayed only if the number it aimed at moved and nothing else got worse.

## The commands

Every command runs a fixed seed through 3,600 ticks of autopilot, one minute of game time.
Run them from `build/`.

| Name | Command | Reports |
|---|---|---|
| E | `node ../tests/playground-check.mjs envelope 1` | The game as the AArch64 Playground's terminal pane runs it: lite profile, s = 3 at 48x43, for 60 s of virtual time or until a wall stops it. Steps and output bytes per second, against the playground's refill of 1,000,000 steps and 100,000 bytes a second. A size after the minutes, as in `envelope 1 144x128`, runs it in a terminal of that size. |
| B1 | `qemu-aarch64 ./flappy --bench --ticks 3600 --autopilot --seed 7 --size 144x128` | Bytes per rendered frame at s = 1 in the full profile, split into cursor moves, colour codes, glyphs and the rest. |
| B3 | `qemu-aarch64 ./flappy --bench --ticks 3600 --autopilot --seed 7 --size 48x43 --lite` | The same at s = 3 in the lite profile, which renders every second tick and draws with palette indexes. |
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
| The lite profile draws with palette indexes 16 to 79, set once with OSC 4, and a palette change (day and night, the bird's colours, a fade, the flash) is an OSC 4 update of the slots that changed instead of a full repaint | E | 869,068 steps/s (86.9%), 117,602 B/s (117.6%), busiest second 133,154 bytes | 857,727 steps/s (85.8%), 78,854 B/s (78.9%), busiest second 89,494 bytes | kept: the bytes target is met, and the full profile writes the same bytes as before (B1 16,577) |
| The same change | B3 | 3,822 bytes a frame, colour codes 3,076; 23 full repaints at 48x43 | 2,429 bytes a frame, colour codes 1,721; 1 full repaint, the first frame | |
| The lite profile draws no larger than s = 3, so a terminal with room for s = 1 or s = 2 gets the s = 3 picture centred | E at 144x128 / 72x64 | s = 1 / s = 2: 3,062,689 / 1,581,224 steps/s (306.3% / 158.1%), 118,601 / 147,629 B/s; the step budget ran out at 4.8 / 17.2 s | s = 3 at both: 857,598 steps/s (85.8%), 79,421 B/s (79.4%), busiest second 90,122 bytes; ran the full 60 s | kept: at s = 1 and s = 2 the game spends more steps than the playground refills |

The before column of the two indexed colour rows is v1.0.0. The art that changed after the
rows above them had moved B3 from 3,855 to 3,822 bytes a frame. A full repaint is a frame that
writes at least as many spaces and blocks as the 48x43 screen has cells, counted in the stream
of B3's arguments with `--render-out` in place of `--bench`: 6,880,839 bytes before and
4,372,393 after.

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
| Nothing written on unchanged frames | 0 bytes, the minimum B1 and B3 report; a frame that changes no cell and no palette slot takes back its synchronized-output code | yes |
| CPU per rendered frame under 0.5 ms | 23.64 us of wall time at s = 1 (N, measured again on the current code), which bounds the CPU time | yes |
| Playground steps under 90% of the refill | 857,727 steps/s, 85.8% (E) | yes |
| Playground bytes under 90% of the refill | 78,854 B/s, 78.9% (E) | yes |
| No second of playground output over the refill | 89,494 bytes in the busiest second (E) | yes |
| No stretch between sleeps near the 1,000,000-step stop | 174,715 steps at most, during set-up; no chunk at the stop (E) | yes |

The bytes now stay under the refill, and still the output wall ends the session in today's
playground. The full check, `make envelope` (up to 15 minutes of virtual time), ran 102.0 s
before the playground stopped the game for printing too much, after 7,422,947 bytes, at
820,788 steps and 72,800 bytes a second. In 24-bit colour it stopped at 68.9 s, at 118,315
bytes a second. A sleep refunds output only up to a full budget, but each refund still counts
in full against the lifetime cap on refunds, 4 MiB. At 100,000 bytes for each second slept,
the refunds are used up after about 42 s while the budget is still full, and the 4 MiB budget
then lasts about a minute. E's model of the budgets works the same way and projects 1.6
minutes for output against 3.5 for steps. A longer session there depends on those caps.

A pipe at s = 3 has six vertical colour edges. In 24-bit colour every edge that moves needs
its own colour code, about 16 bytes, on each row the pipe covers, so the byte rate stayed near
118 KB/s while pipes were on the screen. Rows 1 to 35 of the s = 3 screen, where the pipes
are, carry almost all of it; the ground rows below cost under 3 bytes a frame each. The pipe
art is already at the four bands the art direction asks for.

Indexed colour was the lever left: set the palette once with OSC 4 and send each colour as
`ESC[38;5;Nm`. Replaying the same s = 3 stream with every 24-bit code rewritten that way saved
29.9% of its bytes in the model, which would have taken E from about 119 KB/s to about 83
KB/s. Built, it took E's bytes down 33% and B3's 36%. The model rewrote codes only and kept
the full repaints that palette steps cost; the build drops 22 of B3's 23. It stays on these
terms: the full profile, which a normal terminal gets by default, is unchanged;
@xterm/headless shows every lite frame the encoder check samples cell for cell, each palette
step included; and every way out the game controls sends OSC 104 (the smoke and harden
checks). Windows Terminal has not been checked by eye, so `--lite` there is untested.
