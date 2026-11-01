#!/usr/bin/env python3
"""Runs a command on a pseudo-terminal with timed input, the way a person at a terminal would.

  pty_run.py [options] -- command args...
    --size CxR          window size before exec (default 144x128)
    --deadline S        hard limit in seconds; the child is killed past it (default 20)
    --key T:HEX         send bytes (hex) at T seconds; repeatable
    --resize T:CxR      change the window size at T seconds; repeatable
    --kill T            send SIGTERM to the child at T seconds
    --close T           close the master at T seconds, as closing the window does, then wait
                        for the child until the deadline
    --stall T:S         read nothing for S seconds from T; repeatable
    --read-delay MS     pause between reads of at most --read-size bytes (slow terminal)
    --read-size N       bytes per read (default 65536)
    --out FILE          where the capture goes (default pty.out)
  Prints "key T N", "resize T N" or "close T N" for each event (N = bytes captured when it
  fired), then "status N" (the exit status, or -signal) and "bytes N".
"""
import os, pty, sys, time, select, struct, fcntl, termios, signal


def winsize(fd, cols, rows):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def parse(argv):
    o = {"size": (144, 128), "deadline": 20.0, "events": [], "kill": None, "close": None,
         "stalls": [], "delay": 0.0, "rsize": 65536, "out": "pty.out"}
    i = 0
    while i < len(argv) and argv[i] != "--":
        a, v = argv[i], argv[i + 1] if i + 1 < len(argv) else ""
        if a == "--size":
            c, r = v.lower().split("x"); o["size"] = (int(c), int(r))
        elif a == "--deadline":
            o["deadline"] = float(v)
        elif a == "--key":
            t, h = v.split(":"); o["events"].append((float(t), "key", bytes.fromhex(h)))
        elif a == "--resize":
            t, s = v.split(":"); c, r = s.lower().split("x")
            o["events"].append((float(t), "resize", (int(c), int(r))))
        elif a == "--kill":
            o["kill"] = float(v)
        elif a == "--close":
            o["close"] = float(v)
        elif a == "--stall":
            t, d = v.split(":"); o["stalls"].append((float(t), float(d)))
        elif a == "--read-delay":
            o["delay"] = float(v) / 1000
        elif a == "--read-size":
            o["rsize"] = int(v)
        elif a == "--out":
            o["out"] = v
        else:
            raise SystemExit(f"pty_run: unknown option {a}")
        i += 2
    o["cmd"] = argv[i + 1:]
    o["events"].sort(key=lambda e: e[0])
    return o


def main():
    o = parse(sys.argv[1:])
    pid, fd = pty.fork()
    if pid == 0:
        winsize(0, *o["size"])
        os.execvp(o["cmd"][0], o["cmd"])
    start = time.monotonic()
    cap, status, events, killed = bytearray(), None, list(o["events"]), False
    fired = []
    while True:
        now = time.monotonic() - start
        while events and events[0][0] <= now:
            t, kind, v = events.pop(0)
            fired.append(f"{kind} {t} {len(cap)}")
            if kind == "key":
                os.write(fd, v)
            else:
                winsize(fd, *v)
        if o["kill"] is not None and not killed and now >= o["kill"]:
            os.kill(pid, signal.SIGTERM); killed = True
        if o["close"] is not None and now >= o["close"]:
            os.close(fd)
            fired.append(f"close {o['close']} {len(cap)}")
            while status is None and time.monotonic() - start < o["deadline"]:
                p, st = os.waitpid(pid, os.WNOHANG)
                if p:
                    status = os.waitstatus_to_exitcode(st)
                else:
                    time.sleep(0.01)
            if status is None:
                os.kill(pid, signal.SIGKILL)
            break
        # once reaped the pid may belong to no one, so only a live child is killed
        if now >= o["deadline"] and status is None:
            os.kill(pid, signal.SIGKILL)
        if status is None:
            p, st = os.waitpid(pid, os.WNOHANG)
            if p:
                status = os.waitstatus_to_exitcode(st)
        if now < o["deadline"] and any(a <= now < a + d for a, d in o["stalls"]):
            time.sleep(0.01)
            continue
        r, _, _ = select.select([fd], [], [], 0.01)
        if r:
            try:
                data = os.read(fd, o["rsize"])
            except OSError:
                data = b""
            if not data:
                break
            cap += data
            if o["delay"]:
                time.sleep(o["delay"])
        elif status is not None:
            break
    if status is None:
        _, st = os.waitpid(pid, 0)
        status = os.waitstatus_to_exitcode(st)
    with open(o["out"], "wb") as f:
        f.write(cap)
    for line in fired:
        print(line)
    print("status", status)
    print("bytes", len(cap))


if __name__ == "__main__":
    main()
