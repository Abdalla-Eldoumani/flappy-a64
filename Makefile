# Builds with the aarch64 cross toolchain and runs under qemu-aarch64 on x86_64 Linux,
# or builds and runs natively on an aarch64 Linux machine. Every test runs from build/.

MODS := main tty sim art gfx term save
SRC := $(MODS:%=src/%.asm)
ASM := $(MODS:%=build/%.s)

ifeq ($(shell uname -m),aarch64)
CC := gcc
LINK :=
RUN :=
else
CC := aarch64-linux-gnu-gcc
LINK := -static
RUN := qemu-aarch64
endif
CFLAGS := -Wa,--fatal-warnings

.PHONY: all bundle m4gate goldens physics bundlecheck encoder playground envelope smoke best harden soak frames test play clean

all: build/flappy

build dist:
	mkdir -p $@

build/%.s: src/%.asm src/defs.m4 | build
	m4 src/defs.m4 $< > $@

build/flappy: $(ASM)
	$(CC) $(LINK) $(CFLAGS) $^ -o $@

# one file for the playground: the definitions once, then every source in a fixed order
bundle: dist/flappy-bundle.asm
dist/flappy-bundle.asm: src/defs.m4 $(SRC) | dist
	cat $^ > $@

build/flappy-bundle: dist/flappy-bundle.asm | build
	m4 $< > build/flappy-bundle.s
	$(CC) $(LINK) $(CFLAGS) build/flappy-bundle.s -o $@

m4gate:
	@d=$$(grep -ho 'define([A-Za-z0-9_]*' $(SRC) src/defs.m4 | sort | uniq -d); \
	if [ -n "$$d" ]; then echo "m4 gate: duplicate names: $$d"; exit 1; fi; \
	echo "m4 gate: every name defined once"

goldens: build/flappy
	cd build && bash ../tests/goldens.sh $(RUN) ./flappy

physics:
	python3 tests/physics_ref.py --classic
	python3 tests/physics_ref.py --goldens tests/golden

bundlecheck: build/flappy-bundle
	cd build && bash ../tests/goldens.sh $(RUN) ./flappy-bundle

tests/node_modules: tests/package.json tests/package-lock.json
	cd tests && npm ci --ignore-scripts
	touch $@

encoder: build/flappy tests/node_modules
	cd build && bash ../tests/encoder.sh $(RUN)

# the AArch64 Playground's emulator is not part of this repo; copy its wasm-node build to
# build/playground-wasm to run these two, which otherwise say they were skipped
PLAYGROUND := build/playground-wasm/aarch64_emulator.js

# the headless goldens, then the profile the game picks there with nothing typed
playground: bundle
	@if [ -f $(PLAYGROUND) ]; then cd build && node ../tests/playground-check.mjs goldens && \
	node ../tests/playground-check.mjs profile; \
	else echo "playground: skipped, $(PLAYGROUND) is not there"; fi

# long: plays until a playground wall or 15 virtual minutes, then reports the budget numbers
envelope: bundle
	@if [ -f $(PLAYGROUND) ]; then cd build && node ../tests/playground-check.mjs envelope; \
	else echo "envelope: skipped, $(PLAYGROUND) is not there"; fi

smoke: build/flappy tests/node_modules
	cd build && bash ../tests/pty-smoke.sh $(RUN)

# the best score file across runs: written, read back, kept, ignored when corrupted
best: build/flappy
	cd build && bash ../tests/best.sh $(RUN)

# a slow, stalled and closed terminal, a closed pipe, no terminal, extreme sizes, a best score
# file it cannot write
harden: build/flappy tests/node_modules
	cd build && bash ../tests/harden.sh $(RUN)

# long: ten minutes of autopilot at s = 1 on a pseudo-terminal
soak: build/flappy
	cd build && bash ../tests/soak.sh $(RUN)

# named moments as PNGs and one contact sheet, build/frames/sheet.png
frames: build/flappy
	cd build && bash ../tests/frames.sh $(RUN)

test: m4gate goldens physics bundlecheck encoder playground smoke best harden

play: build/flappy
	cd build && $(RUN) ./flappy

clean:
	rm -rf build/*.s build/flappy build/flappy-bundle dist
