// term_: the terminal presenter. Two display pixels per cell with half blocks, 24-bit colour,
// and only the cells that changed since the last frame are written.

define(term_bt_r, x19)
define(term_ft_r, x20)
define(term_stride_r, x21)
define(term_col_r, x22)
define(term_diff_r, x23)
define(term_out_r, x24)
define(term_curc_r, x25)
define(term_pfg_r, x26)
define(term_pbg_r, x27)
define(term_cells_r, x28)
define(term_bb_r, x5)
define(term_fb_r, x6)
define(term_rdw_r, x7)
define(term_s_r, x19)
define(term_c_r, x20)
define(term_r_r, x21)
define(term_lrow_r, x19)
define(term_lcol_r, x20)
define(term_zw_r, x19)
define(term_zn_r, x20)
define(term_zc_r, x21)
define(term_zr_r, x22)
define(term_mrow_r, x19)
define(term_mtip_r, x20)
define(term_mlen_r, x21)

TERM_REC = 24
TERM_UNKNOWN = -1
TERM_SIZE_CAP = 999
TERM_GUESS_C = 80
TERM_GUESS_R = 24
TERM_OUT_LIMIT = TERM_OUT_SIZE - TERM_OUT_SLACK
TERM_BREATH_CELLS = 800
TERM_MS = 1000000
// ESC and the first final byte of a sequence, which the bench sorts by, and the three finals the
// encoder writes; ESC [ goes out as one halfword
TERM_ESC = 27
TERM_FINAL = 64
TERM_FINAL_CUP = 72
TERM_FINAL_CUF = 67
TERM_FINAL_SGR = 109
TERM_CSI = 0x5B1B
// a cursor column past any display, so the first cell of a row goes there by row and column
TERM_FAR = 4000
// ESC [ C jumps one cell in 3 bytes and ESC [ n C up to nine in 4, so a gap of at most this many
// cells costs fewer bytes as spaces, but only when every one of them is the pen's background
TERM_GAP = 3
TERM_SPACE = 32
// the diff compares a block of eight cells as one 64-bit word; a cell's byte starts at a bit
// index that is a multiple of eight, which TERM_BYTE_BITS rounds down to
TERM_BLOCK = 8
TERM_BYTE_BITS = 0x38
TERM_BYTE_MASK = 0xFF
// every byte of a block's mask set: every cell is sent
TERM_ALL_CELLS = -1
// the notice's lines: what the terminal is, what the game needs, then four lines of how
TERM_SMALL_LINES = 6
// gfx_geo's entry for the largest scale, which is the smallest display: its columns and rows
TERM_GEO_MIN = GFX_SCALE_MAX * 8
TERM_GEO_MIN_ROWS = TERM_GEO_MIN + 6

        .section .rodata
term_s_setup:
        .byte   27
        .ascii  "[?1049h"
        .byte   27
        .ascii  "[?25l"
        .byte   27
        .ascii  "[?7l"
        .byte   27
        .ascii  "[?1000h"
        .byte   27
        .ascii  "[?1006h"
term_s_setup_end:
term_s_restore:
        .byte   27
        .ascii  "[?1006l"
        .byte   27
        .ascii  "[?1000l"
        .byte   27
        .ascii  "[?7h"
        .byte   27
        .ascii  "[?25h"
        .byte   27
        .ascii  "[?1049l"
        .byte   27
        .ascii  "[0m"
term_s_restore_end:
term_s_sync_on:
        .byte   27
        .ascii  "[?2026h"
term_s_sync_off:
        .byte   27
        .ascii  "[?2026l"
term_s_reset:
        .byte   27
        .ascii  "[0m"
term_s_clear:
        .byte   27
        .ascii  "[2J"
        .byte   27
        .ascii  "[1;1H"
term_s_clear_end:
// space, full block, upper half, lower half, indexed by glyph: the space is one byte and each
// block three UTF-8 bytes, each padded to a word
        .balign 4
term_glyphs:
        .byte   TERM_SPACE, 0, 0, 0
        .byte   0xE2, 0x96, 0x88, 0
        .byte   0xE2, 0x96, 0x80, 0
        .byte   0xE2, 0x96, 0x84, 0
// the too-small notice, one short line each so a narrow terminal still shows them whole
term_s_small:
        .ascii  "terminal is "
term_s_small_end:
term_s_small2:
        .ascii  "the game needs "
term_s_small2_end:
term_s_tips:
        .asciz  "to zoom out in"
        .asciz  "Windows Terminal,"
        .asciz  "press Ctrl and minus"
        .asciz  "or make it bigger"
        .asciz  ""

TERM_SETUP_LEN = term_s_setup_end - term_s_setup
TERM_RESTORE_LEN = term_s_restore_end - term_s_restore
TERM_CLEAR_LEN = term_s_clear_end - term_s_clear
TERM_SMALL_LEN = term_s_small_end - term_s_small
TERM_SMALL2_LEN = term_s_small2_end - term_s_small2

        .bss
        .balign 16
term_out:       .skip   TERM_OUT_SIZE
term_fg:        .skip   1536
term_bg:        .skip   1536
term_dec:       .skip   4000
term_len:       .skip   8
        .balign 8
        .global term_total
term_total:     .skip   8
term_pen_fg:    .skip   8
term_pen_bg:    .skip   8
term_cur_r:     .skip   8
term_cur_c:     .skip   8
term_last:      .skip   8
term_full:      .skip   8
term_bad:       .skip   8
        .balign 8
        .global term_bench
        .global term_bsplit
term_bench:     .skip   8
// bench byte counts: cursor moves, colours, glyphs, everything else
term_bsplit:    .skip   TERM_SPLIT_BYTES
// bytes the flushes of a bench frame have counted so far; term_bench_take adds the rest
term_bframe:    .skip   8
term_inited:    .skip   8
term_opened:    .skip   8
term_dw:        .skip   8
term_crows:     .skip   8
        .balign 8
term_cols:      .skip   8
term_rows:      .skip   8
term_ox:        .skip   8
term_oy:        .skip   8

        .text

// term_put(x0 = src, x1 = len): appends bytes to the output buffer
        .balign 4
term_put:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_len
        ldr     x10, [x9]
        ldr     x11, =term_out
        add     x11, x11, x10
        add     x10, x10, x1
        str     x10, [x9]
        cbz     x1, term_put_done
term_put_loop:
        ldrb    w12, [x0], 1
        strb    w12, [x11], 1
        subs    x1, x1, 1
        b.ne    term_put_loop
term_put_done:
        ldp     fp, lr, [sp], 16
        ret

// term_putc(w0 = byte)
        .balign 4
term_putc:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_len
        ldr     x10, [x9]
        ldr     x11, =term_out
        strb    w0, [x11, x10]
        add     x10, x10, 1
        str     x10, [x9]
        ldp     fp, lr, [sp], 16
        ret

// term_putdec(x0 = 0..999): decimal digits from the table, never a divide
        .balign 4
term_putdec:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_dec
        add     x9, x9, x0, lsl 2
        ldrb    w1, [x9], 1
        // an entry is a length and three digits, so one word moves any of them
        ldr     w12, [x9]
        ldr     x9, =term_len
        ldr     x10, [x9]
        ldr     x11, =term_out
        str     w12, [x11, x10]
        add     x10, x10, x1
        str     x10, [x9]
        ldp     fp, lr, [sp], 16
        ret

// term_putrec(x0 = record): a colour string record is a length byte then its text
        .balign 4
term_putrec:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldrb    w1, [x0], 1
        // a record's text is at most 16 bytes and records sit TERM_REC apart, so one pair of
        // words moves any of them; the bytes past its end are overwritten by what follows
        ldp     x12, x13, [x0]
        ldr     x9, =term_len
        ldr     x10, [x9]
        ldr     x11, =term_out
        add     x11, x11, x10
        stp     x12, x13, [x11]
        add     x10, x10, x1
        str     x10, [x9]
        ldp     fp, lr, [sp], 16
        ret

// term_putesc(): ESC [
        .balign 4
term_putesc:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        mov     w0, 27
        bl      term_putc
        mov     w0, 91
        bl      term_putc
        ldp     fp, lr, [sp], 16
        ret

// term_flush(): writes the buffer; a failed write leaves the screen state unknown
        .balign 4
term_flush:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        // a bench counts the bytes instead of writing them, and only once the buffer is full:
        // a bigger frame is counted a buffer at a time, and any other stays in the buffer for
        // term_bench_take, outside the time the bench measures
        ldr     x9, =term_bench
        ldr     x9, [x9]
        cbz     x9, term_flush_write
        ldr     x9, =term_len
        ldr     x9, [x9]
        ldr     x10, =TERM_OUT_LIMIT
        cmp     x9, x10
        b.lt    term_flush_done
        bl      term_bench_count
        ldr     x9, =term_bframe
        ldr     x10, [x9]
        add     x10, x10, x0
        str     x10, [x9]
        b       term_flush_done
term_flush_write:
        ldr     x9, =term_len
        ldr     x2, [x9]
        cbz     x2, term_flush_done
        str     xzr, [x9]
        ldr     x9, =term_total
        ldr     x10, [x9]
        add     x10, x10, x2
        str     x10, [x9]
        mov     w0, 1
        ldr     x1, =term_out
        bl      tty_write_all
        cbz     w0, term_flush_done
        cmp     w0, 2
        b.eq    term_flush_gone
        ldr     x9, =term_bad
        mov     x10, 1
        str     x10, [x9]
        b       term_flush_done
term_flush_gone:
        mov     w0, 0
        bl      main_exit
term_flush_done:
        ldp     fp, lr, [sp], 16
        ret

// term_bench_count() -> x0 = bytes in the buffer, sorted into term_bsplit, counted and dropped
        .balign 4
term_bench_count:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_len
        ldr     x0, [x9]
        str     xzr, [x9]
        ldr     x9, =term_total
        ldr     x10, [x9]
        add     x10, x10, x0
        str     x10, [x9]
        ldr     x9, =term_out
        ldr     x10, =term_bsplit
        mov     x11, 0
        b       term_bench_count_test
term_bench_count_byte:
        ldrb    w12, [x9, x11]
        cmp     w12, TERM_ESC
        b.eq    term_bench_count_seq
        // a glyph byte, or the space that paints a cell
        mov     x13, TERM_SPLIT_GLYPH
        add     x11, x11, 1
        mov     x14, 1
        b       term_bench_count_add
term_bench_count_seq:
        // an escape runs from ESC [ through its final byte, the first one from @ on
        add     x15, x11, 2
term_bench_count_scan:
        ldrb    w12, [x9, x15]
        add     x15, x15, 1
        cmp     w12, TERM_FINAL
        b.lo    term_bench_count_scan
        sub     x14, x15, x11
        mov     x11, x15
        mov     x13, TERM_SPLIT_OTHER
        cmp     w12, TERM_FINAL_CUP
        b.eq    term_bench_count_cursor
        cmp     w12, TERM_FINAL_CUF
        b.eq    term_bench_count_cursor
        cmp     w12, TERM_FINAL_SGR
        b.ne    term_bench_count_add
        mov     x13, TERM_SPLIT_COLOUR
        b       term_bench_count_add
term_bench_count_cursor:
        mov     x13, TERM_SPLIT_CURSOR
term_bench_count_add:
        ldr     x12, [x10, x13]
        add     x12, x12, x14
        str     x12, [x10, x13]
term_bench_count_test:
        cmp     x11, x0
        b.lt    term_bench_count_byte
        ldp     fp, lr, [sp], 16
        ret

// term_bench_take() -> x0 = bytes the bench frame produced, counted and dropped
        .balign 4
        .global term_bench_take
term_bench_take:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        bl      term_bench_count
        ldr     x9, =term_bframe
        ldr     x10, [x9]
        add     x0, x0, x10
        str     xzr, [x9]
        ldp     fp, lr, [sp], 16
        ret

// term_init(): the 0..999 decimal table, built once by counting so nothing divides later
        .balign 4
term_init:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_dec
        mov     x10, 0
        mov     w11, 0
        mov     w12, 0
        mov     w13, 0
term_init_loop:
        add     w14, w11, 48
        add     w15, w12, 48
        add     w1, w13, 48
        cmp     x10, 10
        b.ge    term_init_two
        mov     w2, 1
        strb    w2, [x9]
        strb    w1, [x9, 1]
        b       term_init_next
term_init_two:
        cmp     x10, 100
        b.ge    term_init_three
        mov     w2, 2
        strb    w2, [x9]
        strb    w15, [x9, 1]
        strb    w1, [x9, 2]
        b       term_init_next
term_init_three:
        mov     w2, 3
        strb    w2, [x9]
        strb    w14, [x9, 1]
        strb    w15, [x9, 2]
        strb    w1, [x9, 3]
term_init_next:
        add     x9, x9, 4
        add     w13, w13, 1
        cmp     w13, 10
        b.ne    term_init_count
        mov     w13, 0
        add     w12, w12, 1
        cmp     w12, 10
        b.ne    term_init_count
        mov     w12, 0
        add     w11, w11, 1
term_init_count:
        add     x10, x10, 1
        cmp     x10, 1000
        b.lt    term_init_loop
        ldp     fp, lr, [sp], 16
        ret

// term_build(x0 = record, w1 = 3 for fg or 4 for bg, x2 = palette entry): "38;2;R;G;B"
        .balign 4
term_build:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        add     x9, x0, 1
        strb    w1, [x9], 1
        mov     w10, 56
        strb    w10, [x9], 1
        mov     w10, 59
        strb    w10, [x9], 1
        mov     w10, 50
        strb    w10, [x9], 1
        mov     x11, 0
term_build_loop:
        mov     w10, 59
        strb    w10, [x9], 1
        ldrb    w12, [x2, x11]
        ldr     x13, =term_dec
        add     x13, x13, x12, lsl 2
        ldrb    w14, [x13]
term_build_dig:
        ldrb    w15, [x13, 1]
        strb    w15, [x9], 1
        add     x13, x13, 1
        subs    w14, w14, 1
        b.ne    term_build_dig
        add     x11, x11, 1
        cmp     x11, 3
        b.lt    term_build_loop
        sub     x10, x9, x0
        sub     x10, x10, 1
        strb    w10, [x0]
        ldp     fp, lr, [sp], 16
        ret

// term_colours(x0 = palette): rebuilds every slot's colour strings when the palette changes
term_colours_alloc = -(16 + 24) & -16
term_colours_dealloc = 0 - term_colours_alloc
        .balign 4
term_colours:
        stp     fp, lr, [sp, term_colours_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        str     x21, [sp, 32]
        mov     term_s_r, x0
        mov     term_c_r, 0
term_colours_loop:
        ldr     x0, =term_fg
        mov     x9, TERM_REC
        madd    x0, term_c_r, x9, x0
        mov     w1, 51
        add     x2, term_s_r, term_c_r, lsl 2
        bl      term_build
        ldr     x0, =term_bg
        mov     x9, TERM_REC
        madd    x0, term_c_r, x9, x0
        mov     w1, 52
        add     x2, term_s_r, term_c_r, lsl 2
        bl      term_build
        add     term_c_r, term_c_r, 1
        cmp     term_c_r, SLOT_COUNT
        b.lt    term_colours_loop
        ldp     x19, x20, [sp, 16]
        ldr     x21, [sp, 32]
        ldp     fp, lr, [sp], term_colours_dealloc
        ret

// present_open(x0 = logical w, x1 = logical h) -> w0 = scale 1..4, or 0 when the terminal is too small
present_open_alloc = -(16 + 24) & -16
present_open_dealloc = 0 - present_open_alloc
        .balign 4
        .global present_open
present_open:
        stp     fp, lr, [sp, present_open_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        str     x21, [sp, 32]
        ldr     x9, =term_inited
        ldr     x10, [x9]
        cbnz    x10, term_open_setup
        mov     x10, 1
        str     x10, [x9]
        bl      term_init
term_open_setup:
        ldr     x9, =term_opened
        ldr     x10, [x9]
        cbnz    x10, term_open_size
        mov     x10, 1
        str     x10, [x9]
        ldr     x0, =term_s_setup
        mov     x1, TERM_SETUP_LEN
        bl      term_put
term_open_size:
        ldr     x9, =main_size_c
        ldr     x0, [x9]
        ldr     x9, =main_size_r
        ldr     x1, [x9]
        cbnz    x0, term_open_have
        bl      tty_size
        cbnz    w0, term_open_have
        // shortcut: an unknown size is taken as 80 x 24 until a pane can report its size
        mov     x0, TERM_GUESS_C
        mov     x1, TERM_GUESS_R
term_open_have:
        // shortcut: the decimal table ends at 999, so a larger size is clamped; widen it if that bites
        mov     x9, TERM_SIZE_CAP
        cmp     x0, x9
        csel    x0, x0, x9, le
        cmp     x1, x9
        csel    x1, x1, x9, le
        mov     term_c_r, x0
        mov     term_r_r, x1
        ldr     x9, =term_cols
        str     x0, [x9]
        ldr     x9, =term_rows
        str     x1, [x9]
        mov     term_s_r, 1
term_open_try:
        ldr     x9, =gfx_geo
        add     x9, x9, term_s_r, lsl 3
        ldrh    w10, [x9]
        ldrh    w11, [x9, 6]
        cmp     term_c_r, x10
        b.lt    term_open_next
        cmp     term_r_r, x11
        b.ge    term_open_fit
term_open_next:
        add     term_s_r, term_s_r, 1
        cmp     term_s_r, GFX_SCALE_MAX
        b.le    term_open_try
        bl      term_small
        mov     w0, 0
        b       term_open_done
term_open_fit:
        ldr     x9, =gfx_geo
        add     x9, x9, term_s_r, lsl 3
        ldrh    w10, [x9]
        ldrh    w13, [x9, 6]
        ldr     x14, =term_dw
        str     x10, [x14]
        ldr     x14, =term_crows
        str     x13, [x14]
        sub     x14, term_c_r, x10
        lsr     x14, x14, 1
        add     x14, x14, 1
        ldr     x15, =term_ox
        str     x14, [x15]
        sub     x14, term_r_r, x13
        lsr     x14, x14, 1
        add     x14, x14, 1
        ldr     x15, =term_oy
        str     x14, [x15]
        ldr     x9, =term_full
        mov     x10, 1
        str     x10, [x9]
        mov     x0, term_s_r
term_open_done:
        ldp     x19, x20, [sp, 16]
        ldr     x21, [sp, 32]
        ldp     fp, lr, [sp], present_open_dealloc
        ret

// term_line(x0 = row, x1 = length) -> w0 = 1 with the cursor where a centred line of that
// length starts, or 0 when the row is off the screen
term_line_alloc = -(16 + 16) & -16
term_line_dealloc = 0 - term_line_alloc
        .balign 4
term_line:
        stp     fp, lr, [sp, term_line_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        mov     term_lrow_r, x0
        mov     w0, 0
        ldr     x9, =term_rows
        ldr     x9, [x9]
        cmp     term_lrow_r, x9
        b.gt    term_line_done
        // a line wider than the terminal starts at the left edge and is cut at the right
        ldr     x9, =term_cols
        ldr     x9, [x9]
        subs    x9, x9, x1
        csel    x9, x9, xzr, gt
        lsr     x9, x9, 1
        add     term_lcol_r, x9, 1
        bl      term_putesc
        mov     x0, term_lrow_r
        bl      term_putdec
        mov     w0, 59
        bl      term_putc
        mov     x0, term_lcol_r
        bl      term_putdec
        mov     w0, TERM_FINAL_CUP
        bl      term_putc
        mov     w0, 1
term_line_done:
        ldp     x19, x20, [sp, 16]
        ldp     fp, lr, [sp], term_line_dealloc
        ret

// term_sizeline(x0 = row, x1 = words, x2 = their length, x3 = columns, x4 = rows): a centred
// line of the notice, the words then the size
term_sizeline_alloc = -(16 + 32) & -16
term_sizeline_dealloc = 0 - term_sizeline_alloc
        .balign 4
term_sizeline:
        stp     fp, lr, [sp, term_sizeline_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        mov     term_zw_r, x1
        mov     term_zn_r, x2
        mov     term_zc_r, x3
        mov     term_zr_r, x4
        ldr     x9, =term_dec
        add     x10, x9, term_zc_r, lsl 2
        ldrb    w10, [x10]
        add     x11, x9, term_zr_r, lsl 2
        ldrb    w11, [x11]
        add     x1, term_zn_r, x10
        add     x1, x1, x11
        add     x1, x1, 1
        bl      term_line
        cbz     w0, term_sizeline_done
        mov     x0, term_zw_r
        mov     x1, term_zn_r
        bl      term_put
        mov     x0, term_zc_r
        bl      term_putdec
        mov     w0, 120
        bl      term_putc
        mov     x0, term_zr_r
        bl      term_putdec
term_sizeline_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     fp, lr, [sp], term_sizeline_dealloc
        ret

// term_small(): the too-small notice, centred; the next frame that fits repaints everything
term_small_alloc = -(16 + 24) & -16
term_small_dealloc = 0 - term_small_alloc
        .balign 4
term_small:
        stp     fp, lr, [sp, term_small_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        str     x21, [sp, 32]
        ldr     x0, =term_s_reset
        mov     x1, 4
        bl      term_put
        ldr     x0, =term_s_clear
        mov     x1, TERM_CLEAR_LEN
        bl      term_put
        // centred on the rows there are, from the top when there are fewer than its lines
        ldr     x9, =term_rows
        ldr     x9, [x9]
        subs    x9, x9, TERM_SMALL_LINES
        csel    x9, x9, xzr, gt
        lsr     x9, x9, 1
        add     term_mrow_r, x9, 1
        mov     x0, term_mrow_r
        ldr     x1, =term_s_small
        mov     x2, TERM_SMALL_LEN
        ldr     x9, =term_cols
        ldr     x3, [x9]
        ldr     x9, =term_rows
        ldr     x4, [x9]
        bl      term_sizeline
        add     term_mrow_r, term_mrow_r, 1
        mov     x0, term_mrow_r
        ldr     x1, =term_s_small2
        mov     x2, TERM_SMALL2_LEN
        ldr     x9, =gfx_geo
        ldrh    w3, [x9, TERM_GEO_MIN]
        ldrh    w4, [x9, TERM_GEO_MIN_ROWS]
        bl      term_sizeline
        add     term_mrow_r, term_mrow_r, 1
        ldr     term_mtip_r, =term_s_tips
term_small_tip:
        // each tip is a zero-terminated line, and an empty one ends them
        mov     term_mlen_r, -1
term_small_len:
        add     term_mlen_r, term_mlen_r, 1
        ldrb    w9, [term_mtip_r, term_mlen_r]
        cbnz    w9, term_small_len
        cbz     term_mlen_r, term_small_end
        mov     x0, term_mrow_r
        mov     x1, term_mlen_r
        bl      term_line
        cbz     w0, term_small_next
        mov     x0, term_mtip_r
        mov     x1, term_mlen_r
        bl      term_put
term_small_next:
        add     term_mtip_r, term_mtip_r, term_mlen_r
        add     term_mtip_r, term_mtip_r, 1
        add     term_mrow_r, term_mrow_r, 1
        b       term_small_tip
term_small_end:
        bl      term_flush
        ldr     x9, =term_pen_fg
        mov     x10, TERM_UNKNOWN
        str     x10, [x9]
        ldr     x9, =term_pen_bg
        str     x10, [x9]
        ldr     x9, =term_cur_r
        str     x10, [x9]
        ldr     x9, =term_full
        mov     x10, 1
        str     x10, [x9]
        ldp     x19, x20, [sp, 16]
        ldr     x21, [sp, 32]
        ldp     fp, lr, [sp], term_small_dealloc
        ret

// term_breathe(): in the playground a long repaint must sleep 1 ms every 200,000 steps or it is stopped
        .balign 4
term_breathe:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =main_pace
        ldr     x9, [x9]
        cbz     x9, term_breathe_done
        ldr     x0, =TERM_MS
        bl      tty_sleep
term_breathe_done:
        ldp     fp, lr, [sp], 16
        ret

// present_frame(x0 = back, x1 = stride, x2 = palette, w3 = flags; bit 0 means the palette changed)
present_frame_alloc = -(16 + 80 + 64) & -16
present_frame_dealloc = 0 - present_frame_alloc
present_frame_back = 96
present_frame_front = 104
present_frame_mark = 112
present_frame_srow = 120
present_frame_erow = 128
present_frame_dw = 136
present_frame_ox = 144
present_frame_due = 152
        .balign 4
        .global present_frame
present_frame:
        stp     fp, lr, [sp, present_frame_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        str     x0, [sp, present_frame_back]
        mov     term_stride_r, x1
        tbz     w3, 0, term_pf_pal
        mov     x0, x2
        bl      term_colours
        ldr     x9, =term_full
        mov     x10, 1
        str     x10, [x9]
term_pf_pal:
        ldr     x9, =term_bad
        ldr     x10, [x9]
        cbz     x10, term_pf_sync
        // a frame was cut mid-sequence: CAN ends it and nothing about the pen is assumed
        str     xzr, [x9]
        mov     w0, 24
        bl      term_putc
        ldr     x0, =term_s_reset
        mov     x1, 4
        bl      term_put
        ldr     x9, =term_full
        mov     x10, 1
        str     x10, [x9]
term_pf_sync:
        // synchronized output opens every frame; a frame that sends no cell takes it back
        ldr     x9, =term_len
        ldr     x10, [x9]
        str     x10, [sp, present_frame_mark]
        ldr     x0, =term_s_sync_on
        mov     x1, 8
        bl      term_put
        ldr     x9, =term_last
        ldr     x10, [x9]
        str     x10, [sp, present_frame_front]
        ldr     x9, =term_full
        ldr     x10, [x9]
        cbz     x10, term_pf_rows
        str     xzr, [x9]
        str     xzr, [sp, present_frame_front]
        ldr     x0, =term_s_reset
        mov     x1, 4
        bl      term_put
        bl      term_putesc
        ldr     x0, =term_bg
        bl      term_putrec
        mov     w0, TERM_FINAL_SGR
        bl      term_putc
        ldr     x0, =term_s_clear
        mov     x1, TERM_CLEAR_LEN
        bl      term_put
        ldr     x9, =term_pen_fg
        mov     x10, TERM_UNKNOWN
        str     x10, [x9]
        ldr     x9, =term_pen_bg
        mov     x10, SLOT_BORDER
        str     x10, [x9]
        ldr     x9, =term_cur_r
        mov     x10, 1
        str     x10, [x9]
        ldr     x9, =term_cur_c
        str     x10, [x9]
term_pf_rows:
        // the cell loop keeps the pen, the cursor and the output position in registers
        ldr     x9, =term_pen_fg
        ldr     term_pfg_r, [x9]
        ldr     x9, =term_pen_bg
        ldr     term_pbg_r, [x9]
        ldr     x9, =term_out
        ldr     x10, =term_len
        ldr     x10, [x10]
        add     term_out_r, x9, x10
        mov     term_cells_r, 0
        mov     x9, TERM_BREATH_CELLS
        str     x9, [sp, present_frame_due]
        ldr     x9, =term_dw
        ldr     x9, [x9]
        str     x9, [sp, present_frame_dw]
        ldr     x9, =term_ox
        ldr     x9, [x9]
        str     x9, [sp, present_frame_ox]
        ldr     x9, =term_oy
        ldr     x9, [x9]
        str     x9, [sp, present_frame_srow]
        ldr     x10, =term_crows
        ldr     x10, [x10]
        add     x9, x9, x10
        str     x9, [sp, present_frame_erow]
        ldr     term_bt_r, [sp, present_frame_back]
        ldr     term_ft_r, [sp, present_frame_front]
        b       term_pf_rtest
term_pf_row:
        // a nearly full buffer is written out between rows, so every write ends on whole
        // sequences; the slack holds the longest row
        ldr     x9, =term_out
        sub     x10, term_out_r, x9
        ldr     x11, =TERM_OUT_LIMIT
        cmp     x10, x11
        b.lt    term_pf_room
        ldr     x9, =term_len
        str     x10, [x9]
        bl      term_flush
        ldr     x9, =term_out
        ldr     x10, =term_len
        ldr     x10, [x10]
        add     term_out_r, x9, x10
term_pf_room:
        // the cursor is known in this row only if the last cell sent was in it
        mov     term_curc_r, TERM_FAR
        ldr     x9, =term_cur_r
        ldr     x9, [x9]
        ldr     x10, [sp, present_frame_srow]
        cmp     x9, x10
        b.ne    term_pf_cols
        ldr     x9, =term_cur_c
        ldr     x9, [x9]
        ldr     x10, [sp, present_frame_ox]
        sub     term_curc_r, x9, x10
term_pf_cols:
        // the row's bottom pixel rows and the display width stay in caller-saved registers,
        // since nothing in the row calls out
        add     term_bb_r, term_bt_r, term_stride_r
        add     term_fb_r, term_ft_r, term_stride_r
        ldr     term_rdw_r, [sp, present_frame_dw]
        mov     term_col_r, 0
term_pf_block:
        cbz     term_ft_r, term_pf_all
        // eight cells at a time: both pixel rows unchanged means nothing to send
        ldr     x10, [term_bt_r, term_col_r]
        ldr     x11, [term_ft_r, term_col_r]
        ldr     x12, [term_bb_r, term_col_r]
        ldr     x13, [term_fb_r, term_col_r]
        cmp     x10, x11
        ccmp    x12, x13, 0, eq
        b.eq    term_pf_bnext
        // a byte of the mask per cell, set where either pixel row changed
        eor     term_diff_r, x10, x11
        eor     x12, x12, x13
        orr     term_diff_r, term_diff_r, x12
        b       term_pf_edge
term_pf_all:
        // with no front buffer every cell is sent
        mov     term_diff_r, TERM_ALL_CELLS
term_pf_edge:
        // the last block can reach past the display's right edge into the row padding
        sub     x9, term_rdw_r, term_col_r
        cmp     x9, TERM_BLOCK
        b.ge    term_pf_cell
        lsl     x9, x9, 3
        mov     x10, 1
        lsl     x10, x10, x9
        sub     x10, x10, 1
        and     term_diff_r, term_diff_r, x10
        cbz     term_diff_r, term_pf_bnext
term_pf_cell:
        // the lowest set byte is the next changed cell; clearing it moves on to the one after
        rbit    x9, term_diff_r
        clz     x9, x9
        and     x9, x9, TERM_BYTE_BITS
        mov     x10, TERM_BYTE_MASK
        lsl     x10, x10, x9
        bic     term_diff_r, term_diff_r, x10
        add     x9, term_col_r, x9, lsr 3
        ldrb    w10, [term_bt_r, x9]
        ldrb    w11, [term_bb_r, x9]
        add     term_cells_r, term_cells_r, 1
        // a cursor to the left in this row moves forward, which is never longer than going
        // there by row and column; anything else goes by row and column
        subs    x12, x9, term_curc_r
        b.eq    term_pf_pen
        cmp     x12, TERM_SIZE_CAP
        b.hi    term_pf_abs
        cmp     x12, TERM_GAP
        b.hi    term_pf_jump
        // a cursor in the border to the left has no cells of this display to rewrite
        tbnz    term_curc_r, 63, term_pf_jump
        mov     x13, term_curc_r
term_pf_gap:
        ldrb    w14, [term_bt_r, x13]
        cmp     x14, term_pbg_r
        b.ne    term_pf_jump
        ldrb    w14, [term_bb_r, x13]
        cmp     x14, term_pbg_r
        b.ne    term_pf_jump
        add     x13, x13, 1
        cmp     x13, x9
        b.lt    term_pf_gap
        mov     w14, TERM_SPACE
term_pf_spaces:
        strb    w14, [term_out_r], 1
        subs    x12, x12, 1
        b.ne    term_pf_spaces
        b       term_pf_pen
term_pf_jump:
        mov     w13, TERM_CSI
        strh    w13, [term_out_r], 2
        cmp     x12, 1
        b.eq    term_pf_cuf
        ldr     x13, =term_dec
        add     x13, x13, x12, lsl 2
        ldrb    w14, [x13], 1
        // an entry is a length and three digits, so one word moves any of them
        ldr     w15, [x13]
        str     w15, [term_out_r]
        add     term_out_r, term_out_r, x14
term_pf_cuf:
        mov     w13, TERM_FINAL_CUF
        strb    w13, [term_out_r], 1
        b       term_pf_pen
term_pf_abs:
        mov     w13, TERM_CSI
        strh    w13, [term_out_r], 2
        ldr     x13, =term_dec
        ldr     x14, [sp, present_frame_srow]
        add     x14, x13, x14, lsl 2
        ldrb    w15, [x14], 1
        ldr     w14, [x14]
        str     w14, [term_out_r]
        add     term_out_r, term_out_r, x15
        mov     w14, 59
        strb    w14, [term_out_r], 1
        ldr     x14, [sp, present_frame_ox]
        add     x14, x14, x9
        add     x14, x13, x14, lsl 2
        ldrb    w15, [x14], 1
        ldr     w14, [x14]
        str     w14, [term_out_r]
        add     term_out_r, term_out_r, x15
        mov     w14, TERM_FINAL_CUP
        strb    w14, [term_out_r], 1
term_pf_pen:
        // the glyph follows the pen, so most cells need no colour code at all
        mov     x13, term_pfg_r
        mov     x14, term_pbg_r
        cmp     w10, w11
        b.ne    term_pf_split
        mov     x15, 0
        cmp     term_pbg_r, x10
        b.eq    term_pf_colour
        mov     x15, 1
        cmp     term_pfg_r, x10
        b.eq    term_pf_colour
        mov     x15, 0
        mov     x14, x10
        b       term_pf_colour
term_pf_split:
        cmp     term_pfg_r, x10
        cset    x12, ne
        cmp     term_pbg_r, x11
        cinc    x12, x12, ne
        cmp     term_pfg_r, x11
        cset    x0, ne
        cmp     term_pbg_r, x10
        cinc    x0, x0, ne
        cmp     x12, x0
        b.gt    term_pf_lower
        mov     x15, 2
        mov     x13, x10
        mov     x14, x11
        b       term_pf_colour
term_pf_lower:
        mov     x15, 3
        mov     x13, x11
        mov     x14, x10
term_pf_colour:
        cmp     x13, term_pfg_r
        cset    x12, ne
        cmp     x14, term_pbg_r
        cset    x0, ne
        orr     x1, x12, x0
        cbz     x1, term_pf_glyph
        mov     w1, TERM_CSI
        strh    w1, [term_out_r], 2
        cbz     x12, term_pf_bgonly
        ldr     x1, =term_fg
        mov     x2, TERM_REC
        madd    x1, x13, x2, x1
        ldrb    w2, [x1], 1
        // a record's text is at most 16 bytes and records sit TERM_REC apart, so one pair of
        // words moves any of them; the bytes past its end are overwritten by what follows
        ldp     x3, x4, [x1]
        stp     x3, x4, [term_out_r]
        add     term_out_r, term_out_r, x2
        cbz     x0, term_pf_cend
        mov     w1, 59
        strb    w1, [term_out_r], 1
term_pf_bgonly:
        ldr     x1, =term_bg
        mov     x2, TERM_REC
        madd    x1, x14, x2, x1
        ldrb    w2, [x1], 1
        ldp     x3, x4, [x1]
        stp     x3, x4, [term_out_r]
        add     term_out_r, term_out_r, x2
term_pf_cend:
        mov     w1, TERM_FINAL_SGR
        strb    w1, [term_out_r], 1
        mov     term_pfg_r, x13
        mov     term_pbg_r, x14
term_pf_glyph:
        // a space is one byte and a block three, each stored as a word
        ldr     x1, =term_glyphs
        ldr     w2, [x1, x15, lsl 2]
        str     w2, [term_out_r]
        add     term_out_r, term_out_r, 1
        cbz     x15, term_pf_sent
        add     term_out_r, term_out_r, 2
term_pf_sent:
        add     term_curc_r, x9, 1
        cbnz    term_diff_r, term_pf_cell
term_pf_bnext:
        add     term_col_r, term_col_r, TERM_BLOCK
        cmp     term_col_r, term_rdw_r
        b.lt    term_pf_block
        // where this row left the cursor; the next frame starts from it when its first
        // changed cell is in this same row
        cmp     term_curc_r, TERM_FAR
        b.eq    term_pf_breath
        ldr     x9, [sp, present_frame_ox]
        add     x9, x9, term_curc_r
        ldr     x10, [sp, present_frame_srow]
        ldr     x11, =term_cols
        ldr     x11, [x11]
        cmp     x9, x11
        b.le    term_pf_here
        // with autowrap off the cursor stays put on the last column
        mov     x10, TERM_UNKNOWN
term_pf_here:
        ldr     x11, =term_cur_r
        str     x10, [x11]
        ldr     x11, =term_cur_c
        str     x9, [x11]
term_pf_breath:
        ldr     x9, [sp, present_frame_due]
        cmp     term_cells_r, x9
        b.lt    term_pf_next
        add     x9, term_cells_r, TERM_BREATH_CELLS
        str     x9, [sp, present_frame_due]
        bl      term_breathe
term_pf_next:
        add     term_bt_r, term_bt_r, term_stride_r, lsl 1
        cbz     term_ft_r, term_pf_down
        add     term_ft_r, term_ft_r, term_stride_r, lsl 1
term_pf_down:
        ldr     x9, [sp, present_frame_srow]
        add     x9, x9, 1
        str     x9, [sp, present_frame_srow]
term_pf_rtest:
        ldr     x9, [sp, present_frame_srow]
        ldr     x10, [sp, present_frame_erow]
        cmp     x9, x10
        b.lt    term_pf_row
        ldr     x9, =term_pen_fg
        str     term_pfg_r, [x9]
        ldr     x9, =term_pen_bg
        str     term_pbg_r, [x9]
        ldr     x9, =term_out
        sub     x10, term_out_r, x9
        ldr     x11, =term_len
        str     x10, [x11]
        cbnz    term_cells_r, term_pf_close
        // nothing changed, so nothing is written
        ldr     x10, [sp, present_frame_mark]
        str     x10, [x11]
        b       term_pf_flush
term_pf_close:
        ldr     x0, =term_s_sync_off
        mov     x1, 8
        bl      term_put
term_pf_flush:
        bl      term_flush
        ldr     x9, =term_last
        ldr     x10, [sp, present_frame_back]
        str     x10, [x9]
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], present_frame_dealloc
        ret

// present_close(): undoes the terminal setup in reverse order
        .balign 4
        .global present_close
present_close:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =term_opened
        ldr     x10, [x9]
        cbz     x10, term_close_done
        str     xzr, [x9]
        ldr     x9, =term_bad
        ldr     x10, [x9]
        cbz     x10, term_close_seq
        mov     w0, 24
        bl      term_putc
term_close_seq:
        ldr     x0, =term_s_restore
        mov     x1, TERM_RESTORE_LEN
        bl      term_put
        bl      term_flush
term_close_done:
        ldp     fp, lr, [sp], 16
        ret
