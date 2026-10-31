// Shared definitions for every source file: frame aliases, syscalls, layout, physics.
// Constants are assembler symbols so m4 never rewrites them; only register aliases are m4.
//
// Byte budget, from size -A on each object (each section must stay under 1 MiB)
//   .bss    main  display buffers 2 x 36864                     73728
//                 flap list 4096 x 4, dump list 1024 x 4        20480
//                 line, path, settings, debug text, bench        1248
//           gfx   logical scratch 240 x 256                     61440
//                 static background                             36864
//                 rotated bird, 69 boxes of 24 x 24             39744
//                 ground strip 240 x 56                         13440
//                 UI words baked for the scale                  16384
//                 text bitmap, debug overlay                     8704
//                 division table, sprites, digits, tables        6344
//           term  output buffer                                131072
//                 colour strings 2 x 64 x 24, decimals, state    7280
//           art   palette, legend map                             392
//           sim   state 26 x 8, masks 36 x 4                      352
//           tty   termios x 2, input buffer, decoder              304
//           save  ppm row buffer, header, best score              592
//                 total                                        418368
//   .rodata art   palettes, sprites, fonts, UI words             8744
//           rest  messages and tables                             863
//                 total                                          9607

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
O_RDONLY = 0
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

// physics, Q8 (1/256 px) per tick at 60 Hz; each tuning value is set once, the rest derive
SIM_GRAVITY = 64
SIM_FLAP_VY = -576
SIM_MAX_FALL = 640
SIM_HIT_GRAVITY = 128
SIM_HIT_MAX_FALL = 960
SIM_CEIL_PX = -24
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
SIM_PIPES = 4
SIM_PIPE_SPACING = 72
SIM_PIPE_FIRST_X = 244
SIM_PIPE_CAP_W = 26
SIM_PIPE_CAP_H = 12
SIM_GAP_H = 50
SIM_GAP_MIN = 40
SIM_GAP_RANGE = 71
SIM_PIPE_NONE = 1000
SIM_THEMES = 2
SIM_COLOURS = 3
SIM_GROUND_PERIOD = 24
SIM_OVER_LOCK = 90
SIM_FADE_TICKS = 20
SIM_AP_DELAY = 30
SIM_AP_MARGIN = 16
SIM_TITLE_X = 64
// medals: one per GFX_MEDAL_STEP points, bronze to platinum; the hit flash fades this long
GFX_MEDAL_STEP = 10
GFX_MEDALS = 4
GFX_FLASH_TICKS = 18

// art geometry, shared because the sprites are decoded and placed in other files
ART_FRAMES = 3
ART_CLOUD_W = 48
ART_CLOUD_H = 12
ART_CLOUD_PX = ART_CLOUD_W * ART_CLOUD_H
ART_CITY_W = 48
ART_CITY_H = 26
ART_CITY_PX = ART_CITY_W * ART_CITY_H
ART_BUSH_W = 36
ART_BUSH_H = 16
ART_BUSH_PX = ART_BUSH_W * ART_BUSH_H
ART_GROUND_H = 12
ART_GROUND_PX = SIM_GROUND_PERIOD * ART_GROUND_H
ART_CAP_PX = SIM_PIPE_CAP_W * SIM_PIPE_CAP_H
ART_BODY_W = SIM_PIPE_CAP_W - 2
// the bird drawn again at scales 2 to 4, where shrinking would lose it
ART_BIRD2_W = 9
ART_BIRD2_H = 6
ART_BIRD3_W = 6
ART_BIRD3_H = 4
ART_BIRD4_W = 5
ART_BIRD4_H = 3
// glyph text: w x h characters plus a slash between rows
ART_BIG_W = 6
ART_BIG_H = 10
ART_BIG_STEP = ART_BIG_W * ART_BIG_H + ART_BIG_H - 1
ART_F5_W = 5
ART_F5_H = 7
ART_F5_STEP = ART_F5_W * ART_F5_H + ART_F5_H - 1
ART_F3_W = 3
ART_F3_H = 5
ART_F3_STEP = ART_F3_W * ART_F3_H + ART_F3_H - 1
ART_DIGIT0 = 26
ART_CLEAR = 46
ART_ON = 43
ART_SLASH = 47
ART_CHAR_A = 65
ART_CHAR_0 = 48
ART_DIGIT_LAST = 9
ART_LINE = 95
ART_MEDAL1 = 15
ART_MEDAL2 = 8
ART_MEDAL3 = 5
ART_SPARK1 = 5
ART_SPARK2 = 3
ART_SPARK3 = 1
ART_UI_WORDS = 13

SIM_CEIL = SIM_CEIL_PX * 256
SIM_Y0_Q8 = SIM_BIRD_Y0 * 256
SIM_Y_MAX = (GROUND_Y - SIM_BIRD_LOW) * 256
SIM_BIRD_X1 = SIM_BIRD_X + SIM_BIRD_W - 1
SIM_BIRD_MID = SIM_BIRD_W / 2
SIM_PIPE_MID = SIM_PIPE_CAP_W / 2
SIM_CAP_X1 = SIM_PIPE_CAP_W - 1
SIM_BODY_X1 = SIM_PIPE_CAP_W - 2
SIM_PIPE_OFF = 0 - SIM_PIPE_CAP_W
SIM_PIPE_WRAP = SIM_PIPES * SIM_PIPE_SPACING
SIM_SCORE_X = SIM_BIRD_X + SIM_BIRD_MID - SIM_PIPE_MID
SIM_NEXT_X = SIM_BIRD_X - SIM_CAP_X1
SIM_LOW_CAP = SIM_GAP_H + SIM_PIPE_CAP_H
SIM_MASK_LAST = SIM_BIRD_W - 1
SIM_MASK_BYTES = SIM_BIRD_H * 4
SIM_MASK_ROWS = ART_FRAMES * SIM_BIRD_H
SIM_MASKS_SIZE = ART_FRAMES * SIM_MASK_BYTES
SIM_AP_OVER = SIM_OVER_LOCK + SIM_AP_DELAY
SIM_AP_BIRD = SIM_BIRD_H / 2
SIM_AP_GAP = SIM_GAP_H / 2 + SIM_AP_MARGIN

// states; the title is 0, the zeroed field, so code tests it with cbz and cbnz
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

// colour slots: what each pixel stores; a palette maps them to RGB
SLOT_BORDER = 0
SLOT_SKY1 = 1
SLOT_SKY2 = 2
SLOT_CLOUD = 3
SLOT_CLOUD2 = 4
SLOT_CITY = 5
SLOT_CITY2 = 6
SLOT_WINDOW = 7
SLOT_BUSH = 8
SLOT_BUSH2 = 9
SLOT_GLINE = 10
SLOT_GRASS = 11
SLOT_GRASS2 = 12
SLOT_GRASSDK = 13
SLOT_DIRT = 14
SLOT_DIRT2 = 15
SLOT_POUT = 16
SLOT_PLIGHT = 17
SLOT_PMID = 18
SLOT_PDARK = 19
SLOT_BOUT = 20
SLOT_BODY = 21
SLOT_BSHADE = 22
SLOT_BELLY = 23
SLOT_WING = 24
SLOT_EYE = 25
SLOT_PUPIL = 26
SLOT_BEAK = 27
SLOT_BEAK2 = 28
SLOT_WHITE = 29
SLOT_TOUT = 30
SLOT_PANEL = 31
SLOT_PEDGE = 32
SLOT_LABEL = 33
SLOT_WORD = 34
SLOT_NEW = 35
SLOT_MED1 = 36
SLOT_MED2 = 37
SLOT_MED3 = 38
SLOT_COUNT = 64
// a decoded sprite pixel with this value is transparent
SLOT_CLEAR = 255

// display, at scale 1
GFX_MAX_BUF = LOG_W * LOG_H
GFX_SCALE_MAX = 4
TERM_OUT_SIZE = 131072
// the encoder checks for room only between rows, so the slack holds the longest row: at s = 1
// a first cell of at most 49 bytes, 143 more of at most 45, and 16 that word stores write past
// the end, under 6.5 KB
TERM_OUT_SLACK = 8192
