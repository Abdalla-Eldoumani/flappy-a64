#!/usr/bin/env python3
"""Independent model of the game's per-tick simulation, written from the same constants.

  physics_ref.py --ticks N [--seed S] [--flaps t1,t2,...] [--autopilot]
      prints the lines flappy --headless prints for the same arguments
  physics_ref.py --classic
      compares one flap from rest against the classic 30 fps loop
  physics_ref.py --goldens DIR
      checks every DIR/*.args against DIR/*.out
"""
import sys, os

MASK64 = (1 << 64) - 1

# physics, Q8 per tick at 60 Hz on a 144 x 256 field
GRAVITY, FLAP_VY, MAX_FALL = 64, -576, 640
HIT_GRAVITY, HIT_MAX_FALL = 128, 960
CEIL = -24 * 256
TILT_FLAP, TILT_STEP, TILT_MIN, TILT_HIT_STEP = 90, 3, -180, 7
WING_TICKS, BOB_STEP, BOB_MAX = 6, 64, 1024
GROUND_Y, BIRD_X, BIRD_W, BIRD_LOW, BIRD_Y0 = 200, 28, 17, 11, 122
Y_MAX = (GROUND_Y - BIRD_LOW) * 256
PIPES, SPACING, FIRST_X = 4, 72, 244
CAP_W, CAP_H, GAP_H, GAP_MIN, GAP_RANGE = 26, 12, 50, 40, 71
PIPE_OFF, PIPE_MID, BIRD_MID, PIPE_NONE = -26, 13, 8, 1000
GROUND_PERIOD, OVER_LOCK, FADE_TICKS = 24, 90, 20
AP_DELAY, AP_MARGIN = 30, 35
TITLE, READY, PLAY, DYING, OVER, FADE = range(6)
WING_FRAME = (0, 1, 2, 1)
# shortcut: the box mask stands in for the bird until the art defines per-frame masks
MASKS = [[(1 << BIRD_W) - 1] * 12 for _ in range(3)]

FIELDS = ("state st y vy gc tilt wing wsub bob bobd ground score hitpipe hitt theme birdc "
          "rng tcount").split()


class Sim:
    def __init__(self, seed):
        for f in FIELDS:
            setattr(self, f, 0)
        self.px = [PIPE_NONE] * PIPES
        self.gap = [0] * PIPES
        self.rng = seed & MASK64 or 0x9E3779B97F4A7C15
        self.state = TITLE
        self.y = BIRD_Y0 * 256
        self.bobd = BOB_STEP
        self.pick_look()

    def rand(self):
        x = self.rng
        x ^= x >> 12
        x ^= (x << 25) & MASK64
        x ^= x >> 27
        self.rng = x
        return (x * 0x2545F4914F6CDD1D) & MASK64

    def pick_look(self):
        self.theme = (self.rand() * 2) >> 64
        self.birdc = (self.rand() * 3) >> 64

    def fields(self):
        out = [getattr(self, f) for f in FIELDS]
        for i in range(PIPES):
            out += [self.px[i], self.gap[i]]
        return out

    def hash(self):
        h = 0xcbf29ce484222325
        for v in self.fields():
            for b in (v & MASK64).to_bytes(8, "little"):
                h = ((h ^ b) * 0x100000001b3) & MASK64
        return h

    def bob_step(self):
        if abs(self.bob) == BOB_MAX:
            self.bobd = -self.bobd
        self.bob += self.bobd

    def wing_step(self):
        self.wsub += 1
        if self.wsub == WING_TICKS:
            self.wsub = 0
            self.wing = (self.wing + 1) & 3

    def ground_step(self):
        self.ground = (self.ground + 1) % GROUND_PERIOD

    def gravity(self, g, vmax):
        if self.gc & 1 == 0 and self.gc != 0 and self.vy < vmax:
            self.vy += g
        self.gc += 1

    def hit_test(self):
        py = self.y >> 8
        if py + BIRD_LOW >= GROUND_Y:
            return 2
        mask = MASKS[WING_FRAME[self.wing]]
        for x, gap in zip(self.px, self.gap):
            if x > BIRD_X + BIRD_W - 1 or x + CAP_W - 1 < BIRD_X:
                continue
            for j in range(12):
                row = py + j
                if row < gap - CAP_H or (gap + GAP_H + CAP_H <= row < GROUND_Y):
                    a, b = x + 1, x + CAP_W - 2
                elif row < gap or gap + GAP_H <= row < GROUND_Y:
                    a, b = x, x + CAP_W - 1
                else:
                    continue
                lo, hi = max(a - BIRD_X, 0), min(b - BIRD_X, BIRD_W - 1)
                if lo <= hi and mask[j] & (((2 << hi) - 1) & ~((1 << lo) - 1)):
                    return 1
        return 0

    def reset_run(self):
        self.state, self.st = READY, 0
        self.y, self.vy, self.gc, self.tilt = BIRD_Y0 * 256, 0, 0, 0
        self.bob, self.bobd = 0, BOB_STEP
        self.score = self.hitpipe = self.hitt = 0
        self.px = [PIPE_NONE] * PIPES
        self.gap = [0] * PIPES
        self.pick_look()

    def start_play(self):
        self.y += self.bob
        self.bob = 0
        for i in range(PIPES):
            self.px[i] = FIRST_X + SPACING * i
            self.gap[i] = GAP_MIN + ((self.rand() * GAP_RANGE) >> 64)
        self.state, self.st = PLAY, 0

    def tick(self, press):
        self.tcount += 1
        s = self.state
        if s in (TITLE, READY):
            if press and s == TITLE:
                self.state, self.st = FADE, 0
                return
            if not press:
                self.bob_step(); self.wing_step(); self.ground_step()
                self.st += 1
                return
            self.start_play()
            s = PLAY
        if s == PLAY:
            flapped = False
            if press and self.y > CEIL:
                self.vy, self.gc, flapped = FLAP_VY, 0, True
            h = self.hit_test()
            if h:
                self.hitt = self.gc = self.st = 0
                self.hitpipe = 1 if h == 1 else 0
                self.state = DYING if h == 1 else OVER
                return
            for x in self.px:
                if x + PIPE_MID == BIRD_X + BIRD_MID:
                    self.score += 1
            self.wing_step(); self.ground_step()
            if self.tilt > TILT_MIN:
                self.tilt -= TILT_STEP
            if flapped:
                self.tilt = TILT_FLAP
            self.gravity(GRAVITY, MAX_FALL)
            self.y = min(self.y + self.vy, Y_MAX)
            for i in range(PIPES):
                self.px[i] -= 1
                if self.px[i] < PIPE_OFF:
                    self.px[i] += PIPES * SPACING
                    self.gap[i] = GAP_MIN + ((self.rand() * GAP_RANGE) >> 64)
            self.st += 1
        elif s == DYING:
            self.st += 1; self.hitt += 1
            if self.hitpipe:
                self.tilt = max(self.tilt - TILT_HIT_STEP, TILT_MIN)
            self.gravity(HIT_GRAVITY, HIT_MAX_FALL)
            self.y += self.vy
            if self.y >= Y_MAX:
                self.y, self.state, self.st = Y_MAX, OVER, 0
        elif s == OVER:
            if press and self.st >= OVER_LOCK:
                self.state, self.st = FADE, 0
                return
            self.st += 1; self.hitt += 1
        elif s == FADE:
            self.st += 1
            if self.st >= FADE_TICKS:
                self.reset_run()

    def autopilot(self):
        if self.state in (TITLE, READY):
            return self.st == AP_DELAY
        if self.state == OVER:
            return self.st == OVER_LOCK + AP_DELAY
        if self.state != PLAY:
            return False
        nx, ng = None, 0
        for x, gap in zip(self.px, self.gap):
            if x + CAP_W - 1 >= BIRD_X and (nx is None or x < nx):
                nx, ng = x, gap
        return (self.y >> 8) > ng + AP_MARGIN


def headless(ticks, seed, flaps, autopilot):
    sim, out, fl = Sim(seed), [], sorted(flaps)
    k = 0
    for t in range(1, ticks + 1):
        press = False
        if autopilot:
            press = sim.autopilot()
        while k < len(fl) and fl[k] <= t:
            press = press or fl[k] == t
            k += 1
        sim.tick(press)
        if t % 60 == 0:
            out.append(f"{t} {sim.score} {sim.y} {sim.vy} {sim.state} {sim.hash():016x}")
    out.append(f"END {ticks} {sim.score} {sim.hash():016x}")
    return out


def parse(argv):
    o = {"ticks": 0, "seed": 1, "flaps": [], "autopilot": False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--ticks":
            o["ticks"] = int(argv[i + 1]); i += 1
        elif a == "--seed":
            o["seed"] = int(argv[i + 1]); i += 1
        elif a == "--flaps":
            o["flaps"] = [int(v) for v in argv[i + 1].split(",") if v]; i += 1
        elif a == "--autopilot":
            o["autopilot"] = True
        elif a == "--headless":
            pass
        else:
            raise SystemExit(f"physics_ref: unknown argument {a}")
        i += 1
    return o


def classic():
    # FlapPyBird's loop at 30 fps on a 288 px field: flap -9, +1 per frame, max 10
    def run_classic():
        y, vel, flapped, ys = 0, -9, True, [0]
        for _ in range(200):
            if vel < 10 and not flapped:
                vel += 1
            flapped = False
            y += vel
            ys.append(y)
        return ys
    ys = run_classic()
    c_apex = -min(ys) / 2
    c_t_apex = ys.index(min(ys)) * 2
    c_t_fall = next(i for i, y in enumerate(ys) if y >= 200) * 2
    sim = Sim(1)
    sim.reset_run(); sim.start_play()
    sim.px = [PIPE_NONE] * PIPES
    sim.y = y0 = 80 * 256
    yq = [sim.y]
    sim.tick(True)
    yq.append(sim.y)
    for _ in range(200):
        if sim.state != PLAY:
            break
        sim.tick(False)
        yq.append(sim.y)
    o_apex = (y0 - min(yq)) / 256
    o_t_apex = yq.index(min(yq))
    o_t_fall = next(i for i, y in enumerate(yq) if y >= y0 + 100 * 256)
    bad = 0
    for name, c, o in (("apex px", c_apex, o_apex), ("ticks to apex", c_t_apex, o_t_apex),
                       ("ticks to fall 100 px", c_t_fall, o_t_fall)):
        d = abs(o - c) / c * 100
        bad += d > 3
        print(f"{name}: classic {c} ours {o} diff {d:.2f}% {'PASS' if d <= 3 else 'FAIL'}")
    return bad


def goldens(d):
    bad = 0
    for f in sorted(os.listdir(d)):
        if not f.endswith(".args"):
            continue
        args = open(os.path.join(d, f)).read().split()
        want = open(os.path.join(d, f[:-5] + ".out")).read().splitlines()
        got = headless(**parse(args))
        ok = got == want
        bad += not ok
        print(("PASS" if ok else "FAIL"), f[:-5])
    return bad


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["--classic"]:
        sys.exit(1 if classic() else 0)
    if a[:1] == ["--goldens"]:
        sys.exit(1 if goldens(a[1]) else 0)
    print("\n".join(headless(**parse(a))))
