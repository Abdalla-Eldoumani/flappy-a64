// Shared definitions for every source file: frame aliases, syscalls, layout, physics.
// Constants are assembler symbols so m4 never rewrites them; only register aliases are m4.
//
// Byte budget (each section must stay under 1 MiB)
//   .bss    main  display buffers 2 x 36864           73728
//                 flap list 4096 x 4, dump list 1024 x 4 20480
//           gfx   static background                   36864
//                 division table 1024 x 2              2048
//           term  output buffer                       131072
//                 colour strings 2 x 64 x 24, decimals  7168
//           sim   state 26 x 8                           208
//           tty   termios x 2, input buffer              256
//           save  ppm row buffer                         512
//           total                                     272336
//   .rodata art   palette 64 x 4, digit font             416
//           main  messages                              under 2048

define(fp, x29)
define(lr, x30)

// syscalls (the twelve the playground implements)
SYS_FCNTL = 25
SYS_IOCTL = 29
SYS_OPENAT = 56
SYS_CLOSE = 57
SYS_LSEEK = 62
SYS_READ = 63
SYS_WRITE = 64
SYS_EXIT = 93
SYS_EXIT_GROUP = 94
SYS_NANOSLEEP = 101
SYS_CLOCK_GETTIME = 113
SYS_GETRANDOM = 278

EINTR = 4
EIO = 5
EAGAIN = 11
AT_FDCWD = -100
O_WRONLY = 1
O_CREAT = 64
O_TRUNC = 512
O_NONBLOCK = 0x800
F_GETFL = 3
F_SETFL = 4
CLOCK_MONOTONIC = 1
TCGETS = 0x5401
TCSETS = 0x5402
TIOCGWINSZ = 0x5413

// playfield, in logical pixels
LOG_W = 144
LOG_H = 256
GROUND_Y = 200

// physics, Q8 (1/256 px) per tick at 60 Hz
SIM_GRAVITY = 64
SIM_FLAP_VY = -576
SIM_MAX_FALL = 640
SIM_HIT_GRAVITY = 128
SIM_HIT_MAX_FALL = 960
SIM_CEIL = -6144
SIM_TILT_FLAP = 90
SIM_TILT_STEP = 3
SIM_TILT_MIN = -180
SIM_TILT_HIT_STEP = 7
SIM_TILT_DRAW_MAX = 40
SIM_WING_TICKS = 6
SIM_BOB_STEP = 64
SIM_BOB_MAX = 1024
SIM_BIRD_X = 28
SIM_BIRD_W = 17
SIM_BIRD_H = 12
SIM_BIRD_LOW = 11
SIM_BIRD_Y0 = 122
SIM_Y_MAX = 48384
SIM_PIPES = 4
SIM_PIPE_SPACING = 72
SIM_PIPE_WRAP = 288
SIM_PIPE_FIRST_X = 244
SIM_PIPE_CAP_W = 26
SIM_PIPE_CAP_H = 12
SIM_GAP_H = 50
SIM_GAP_MIN = 40
SIM_GAP_RANGE = 71
SIM_PIPE_OFF = -26
SIM_PIPE_NONE = 1000
SIM_SCORE_X = 23
SIM_GROUND_PERIOD = 24
SIM_OVER_LOCK = 90
SIM_FADE_TICKS = 20
SIM_AP_DELAY = 30
SIM_AP_MARGIN = 35
SIM_TITLE_X = 64

// states
SIM_TITLE = 0
SIM_READY = 1
SIM_PLAY = 2
SIM_DYING = 3
SIM_OVER = 4
SIM_FADE = 5

// sim state fields, 8 bytes each, hashed in this order
SIM_STATE = 0
SIM_ST = 8
SIM_Y = 16
SIM_VY = 24
SIM_GC = 32
SIM_TILT = 40
SIM_WING = 48
SIM_WSUB = 56
SIM_BOB = 64
SIM_BOBD = 72
SIM_GROUNDX = 80
SIM_SCORE = 88
SIM_HITPIPE = 96
SIM_HITT = 104
SIM_THEME = 112
SIM_BIRDC = 120
SIM_RNG = 128
SIM_TCOUNT = 136
SIM_PIPEX = 144
SIM_SIZE = 208
SIM_NFIELDS = 26

// colour slots
SLOT_BORDER = 0
SLOT_SKY = 1
SLOT_SKY2 = 2
SLOT_GROUND = 3
SLOT_GROUND2 = 4
SLOT_GRASS = 5
SLOT_PIPE = 6
SLOT_BIRD = 7
SLOT_WHITE = 8
SLOT_DARK = 9
SLOT_PIPE2 = 10
SLOT_COUNT = 64

// display, at scale 1
GFX_MAX_BUF = 36864
GFX_SCALE_MAX = 4
TERM_OUT_SIZE = 131072
TERM_OUT_SLACK = 4096
