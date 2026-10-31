// term_: the terminal presenter. Two display pixels per cell with half blocks, 24-bit colour,
// and only the cells that changed since the last frame are written.

define(term_back_r, x19)
define(term_front_r, x20)
define(term_row_r, x21)
define(term_col_r, x22)
define(term_dw_r, x23)
define(term_stride_r, x24)
define(term_crows_r, x25)
define(term_bt_r, x26)
define(term_ft_r, x27)
define(term_k_r, x28)
define(term_s_r, x19)
define(term_c_r, x20)
define(term_r_r, x21)
define(term_n_r, x19)
define(term_top_r, x19)
define(term_bot_r, x20)
define(term_trow_r, x21)
define(term_tcol_r, x22)
define(term_nfg_r, x23)
define(term_nbg_r, x24)

TERM_REC = 24
TERM_UNKNOWN = -1
TERM_SIZE_CAP = 999
TERM_GUESS_C = 80
TERM_GUESS_R = 24
TERM_OUT_LIMIT = TERM_OUT_SIZE - TERM_OUT_SLACK
TERM_BREATH_CELLS = 800
TERM_MS = 1000000
term_cell_alloc = -(16 + 48 + 24) & -16
term_cell_dealloc = 0 - term_cell_alloc
term_cell_fgo = 64
term_cell_bgo = 72
term_cell_glypho = 80

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
// full block, upper half, lower half: three UTF-8 bytes each, indexed by glyph
term_g_full:
        .byte   0xE2, 0x96, 0x88
        .byte   0xE2, 0x96, 0x80
        .byte   0xE2, 0x96, 0x84
term_s_small:
        .ascii  "terminal "
term_s_small_end:
term_s_small2:
        .ascii  " is too small, the game needs 36x32"
term_s_small2_end:
term_s_small3:
        .byte   27
        .ascii  "[2;1H"
        .ascii  "zoom out (Ctrl and minus in Windows Terminal) or resize"
term_s_small3_end:

TERM_SETUP_LEN = term_s_setup_end - term_s_setup
TERM_RESTORE_LEN = term_s_restore_end - term_s_restore
TERM_CLEAR_LEN = term_s_clear_end - term_s_clear
TERM_SMALL_LEN = term_s_small_end - term_s_small
TERM_SMALL2_LEN = term_s_small2_end - term_s_small2
TERM_SMALL3_LEN = term_s_small3_end - term_s_small3

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
term_sync:      .skip   8
term_inited:    .skip   8
term_opened:    .skip   8
term_scale:     .skip   8
term_dw:        .skip   8
term_dh:        .skip   8
term_stride:    .skip   8
term_crows:     .skip   8
        .balign 8
        .global term_cols
        .global term_rows
term_cols:      .skip   8
term_rows:      .skip   8
term_ox:        .skip   8
term_oy:        .skip   8
term_work:      .skip   8

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
        ldrb    w1, [x9]
        add     x0, x9, 1
        bl      term_put
        ldp     fp, lr, [sp], 16
        ret

// term_putrec(x0 = record): a colour string record is a length byte then its text
        .balign 4
term_putrec:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldrb    w1, [x0]
        add     x0, x0, 1
        bl      term_put
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
        .global term_flush
term_flush:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
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
        ldr     x9, =term_scale
        str     xzr, [x9]
        bl      term_small
        mov     w0, 0
        b       term_open_done
term_open_fit:
        ldr     x9, =gfx_geo
        add     x9, x9, term_s_r, lsl 3
        ldrh    w10, [x9]
        ldrh    w11, [x9, 2]
        ldrh    w12, [x9, 4]
        ldrh    w13, [x9, 6]
        ldr     x14, =term_scale
        str     term_s_r, [x14]
        ldr     x14, =term_dw
        str     x10, [x14]
        ldr     x14, =term_dh
        str     x11, [x14]
        ldr     x14, =term_stride
        str     x12, [x14]
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

// term_small(): the too-small notice; the next frame that fits repaints everything
        .balign 4
term_small:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x0, =term_s_reset
        mov     x1, 4
        bl      term_put
        ldr     x0, =term_s_clear
        mov     x1, TERM_CLEAR_LEN
        bl      term_put
        ldr     x0, =term_s_small
        mov     x1, TERM_SMALL_LEN
        bl      term_put
        ldr     x9, =term_cols
        ldr     x0, [x9]
        bl      term_putdec
        mov     w0, 120
        bl      term_putc
        ldr     x9, =term_rows
        ldr     x0, [x9]
        bl      term_putdec
        ldr     x0, =term_s_small2
        mov     x1, TERM_SMALL2_LEN
        bl      term_put
        ldr     x0, =term_s_small3
        mov     x1, TERM_SMALL3_LEN
        bl      term_put
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
        ldp     fp, lr, [sp], 16
        ret

// term_move(x0 = row, x1 = col): cursor to a cell by the shorter of a relative or an absolute move
term_move_alloc = -(16 + 24) & -16
term_move_dealloc = 0 - term_move_alloc
        .balign 4
term_move:
        stp     fp, lr, [sp, term_move_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        str     x21, [sp, 32]
        mov     term_r_r, x0
        mov     term_c_r, x1
        ldr     x9, =term_cur_r
        ldr     x10, [x9]
        ldr     x11, =term_cur_c
        ldr     x11, [x11]
        cmp     x10, term_r_r
        b.ne    term_move_abs
        cmp     x11, term_c_r
        b.eq    term_move_done
        b.gt    term_move_abs
        sub     term_n_r, term_c_r, x11
        // bytes: ESC [ n C against ESC [ r ; c H
        ldr     x12, =term_dec
        add     x13, x12, term_n_r, lsl 2
        ldrb    w13, [x13]
        add     x13, x13, 3
        cmp     term_n_r, 1
        b.ne    term_move_cost
        mov     x13, 3
term_move_cost:
        add     x14, x12, term_r_r, lsl 2
        ldrb    w14, [x14]
        add     x15, x12, term_c_r, lsl 2
        ldrb    w15, [x15]
        add     x14, x14, x15
        add     x14, x14, 4
        cmp     x13, x14
        b.gt    term_move_abs
        bl      term_putesc
        cmp     term_n_r, 1
        b.eq    term_move_cuf
        mov     x0, term_n_r
        bl      term_putdec
term_move_cuf:
        mov     w0, 67
        bl      term_putc
        b       term_move_done
term_move_abs:
        bl      term_putesc
        mov     x0, term_r_r
        bl      term_putdec
        mov     w0, 59
        bl      term_putc
        mov     x0, term_c_r
        bl      term_putdec
        mov     w0, 72
        bl      term_putc
term_move_done:
        ldp     x19, x20, [sp, 16]
        ldr     x21, [sp, 32]
        ldp     fp, lr, [sp], term_move_dealloc
        ret

// term_cell(w0 = top slot, w1 = bottom slot, x2 = row, x3 = col): one changed cell
        .balign 4
term_cell:
        stp     fp, lr, [sp, term_cell_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        mov     term_top_r, x0
        mov     term_bot_r, x1
        mov     term_trow_r, x2
        mov     term_tcol_r, x3
        // flushing between cells keeps every write on whole sequences
        ldr     x9, =term_len
        ldr     x9, [x9]
        ldr     x10, =TERM_OUT_LIMIT
        cmp     x9, x10
        b.lt    term_cell_room
        bl      term_flush
term_cell_room:
        ldr     x9, =term_sync
        ldr     x10, [x9]
        cbnz    x10, term_cell_synced
        mov     x10, 1
        str     x10, [x9]
        ldr     x0, =term_s_sync_on
        mov     x1, 8
        bl      term_put
term_cell_synced:
        mov     x0, term_trow_r
        mov     x1, term_tcol_r
        bl      term_move
        // the glyph follows the pen, so most cells need no colour code at all
        ldr     x10, =term_pen_fg
        ldr     x10, [x10]
        ldr     x11, =term_pen_bg
        ldr     x11, [x11]
        mov     term_nfg_r, x10
        mov     term_nbg_r, x11
        cmp     term_top_r, term_bot_r
        b.ne    term_cell_split
        mov     x9, 0
        cmp     x11, term_top_r
        b.eq    term_cell_colour
        mov     x9, 1
        cmp     x10, term_top_r
        b.eq    term_cell_colour
        mov     x9, 0
        mov     term_nbg_r, term_top_r
        b       term_cell_colour
term_cell_split:
        cmp     x10, term_top_r
        cset    x12, ne
        cmp     x11, term_bot_r
        cinc    x12, x12, ne
        cmp     x10, term_bot_r
        cset    x13, ne
        cmp     x11, term_top_r
        cinc    x13, x13, ne
        cmp     x12, x13
        b.gt    term_cell_lower
        mov     x9, 2
        mov     term_nfg_r, term_top_r
        mov     term_nbg_r, term_bot_r
        b       term_cell_colour
term_cell_lower:
        mov     x9, 3
        mov     term_nfg_r, term_bot_r
        mov     term_nbg_r, term_top_r
term_cell_colour:
        str     x9, [sp, term_cell_glypho]
        cmp     term_nfg_r, x10
        cset    x12, ne
        cmp     term_nbg_r, x11
        cset    x13, ne
        orr     x14, x12, x13
        cbz     x14, term_cell_glyph
        str     x13, [sp, term_cell_bgo]
        str     x12, [sp, term_cell_fgo]
        bl      term_putesc
        ldr     x12, [sp, term_cell_fgo]
        cbz     x12, term_cell_bgonly
        ldr     x0, =term_fg
        mov     x9, TERM_REC
        madd    x0, term_nfg_r, x9, x0
        bl      term_putrec
        ldr     x13, [sp, term_cell_bgo]
        cbz     x13, term_cell_cend
        mov     w0, 59
        bl      term_putc
term_cell_bgonly:
        ldr     x0, =term_bg
        mov     x9, TERM_REC
        madd    x0, term_nbg_r, x9, x0
        bl      term_putrec
term_cell_cend:
        mov     w0, 109
        bl      term_putc
        ldr     x9, =term_pen_fg
        str     term_nfg_r, [x9]
        ldr     x9, =term_pen_bg
        str     term_nbg_r, [x9]
term_cell_glyph:
        ldr     x9, [sp, term_cell_glypho]
        cbnz    x9, term_cell_block
        mov     w0, 32
        bl      term_putc
        b       term_cell_moved
term_cell_block:
        ldr     x0, =term_g_full
        sub     x9, x9, 1
        mov     x10, 3
        madd    x0, x9, x10, x0
        mov     x1, 3
        bl      term_put
term_cell_moved:
        // with autowrap off the cursor stays put on the last column
        ldr     x9, =term_cur_r
        str     term_trow_r, [x9]
        add     x10, term_tcol_r, 1
        ldr     x11, =term_cur_c
        str     x10, [x11]
        ldr     x12, =term_cols
        ldr     x12, [x12]
        cmp     term_tcol_r, x12
        b.lt    term_cell_done
        mov     x10, TERM_UNKNOWN
        str     x10, [x9]
term_cell_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], term_cell_dealloc
        ret

// term_breathe(): in the playground a long repaint must sleep 1 ms every 200,000 steps or it is stopped
        .balign 4
term_breathe:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =main_pace
        ldr     x9, [x9]
        cbz     x9, term_breathe_done
        ldr     x9, =term_work
        ldr     x10, [x9]
        add     x10, x10, 1
        str     x10, [x9]
        cmp     x10, TERM_BREATH_CELLS
        b.lt    term_breathe_done
        str     xzr, [x9]
        ldr     x0, =TERM_MS
        bl      tty_sleep
term_breathe_done:
        ldp     fp, lr, [sp], 16
        ret

// present_frame(x0 = back, x1 = stride, x2 = palette, w3 = flags; bit 0 means the palette changed)
present_frame_alloc = -(16 + 80) & -16
present_frame_dealloc = 0 - present_frame_alloc
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
        mov     term_back_r, x0
        mov     term_stride_r, x1
        tbz     w3, 0, term_pf_pal
        mov     x0, x2
        bl      term_colours
        ldr     x9, =term_full
        mov     x10, 1
        str     x10, [x9]
term_pf_pal:
        ldr     x9, =term_sync
        str     xzr, [x9]
        ldr     x9, =term_bad
        ldr     x10, [x9]
        cbz     x10, term_pf_full
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
term_pf_full:
        ldr     x9, =term_last
        ldr     term_front_r, [x9]
        ldr     x9, =term_full
        ldr     x10, [x9]
        cbz     x10, term_pf_rows
        str     xzr, [x9]
        mov     term_front_r, 0
        ldr     x9, =term_sync
        mov     x10, 1
        str     x10, [x9]
        ldr     x0, =term_s_sync_on
        mov     x1, 8
        bl      term_put
        ldr     x0, =term_s_reset
        mov     x1, 4
        bl      term_put
        bl      term_putesc
        ldr     x0, =term_bg
        bl      term_putrec
        mov     w0, 109
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
        ldr     x9, =term_dw
        ldr     term_dw_r, [x9]
        ldr     x9, =term_crows
        ldr     term_crows_r, [x9]
        mov     term_row_r, 0
        b       term_pf_rtest
term_pf_row:
        lsl     x9, term_row_r, 1
        mul     x9, x9, term_stride_r
        add     term_bt_r, term_back_r, x9
        mov     term_ft_r, 0
        cbz     term_front_r, term_pf_cols
        add     term_ft_r, term_front_r, x9
term_pf_cols:
        mov     term_col_r, 0
term_pf_block:
        cbz     term_ft_r, term_pf_walk
        // eight cells at a time: both pixel rows unchanged means nothing to send
        ldr     x10, [term_bt_r, term_col_r]
        ldr     x11, [term_ft_r, term_col_r]
        cmp     x10, x11
        b.ne    term_pf_walk
        add     x12, term_bt_r, term_stride_r
        ldr     x10, [x12, term_col_r]
        add     x12, term_ft_r, term_stride_r
        ldr     x11, [x12, term_col_r]
        cmp     x10, x11
        b.eq    term_pf_bnext
term_pf_walk:
        mov     term_k_r, 0
term_pf_cell:
        add     x9, term_col_r, term_k_r
        cmp     x9, term_dw_r
        b.ge    term_pf_bnext
        ldrb    w0, [term_bt_r, x9]
        add     x12, term_bt_r, term_stride_r
        ldrb    w1, [x12, x9]
        cbz     term_ft_r, term_pf_send
        ldrb    w13, [term_ft_r, x9]
        add     x12, term_ft_r, term_stride_r
        ldrb    w14, [x12, x9]
        cmp     w0, w13
        b.ne    term_pf_send
        cmp     w1, w14
        b.eq    term_pf_knext
term_pf_send:
        ldr     x12, =term_oy
        ldr     x2, [x12]
        add     x2, x2, term_row_r
        ldr     x12, =term_ox
        ldr     x3, [x12]
        add     x3, x3, x9
        bl      term_cell
        bl      term_breathe
term_pf_knext:
        add     term_k_r, term_k_r, 1
        cmp     term_k_r, 8
        b.lt    term_pf_cell
term_pf_bnext:
        add     term_col_r, term_col_r, 8
        cmp     term_col_r, term_dw_r
        b.lt    term_pf_block
        add     term_row_r, term_row_r, 1
term_pf_rtest:
        cmp     term_row_r, term_crows_r
        b.lt    term_pf_row
        ldr     x9, =term_sync
        ldr     x10, [x9]
        cbz     x10, term_pf_flush
        ldr     x0, =term_s_sync_off
        mov     x1, 8
        bl      term_put
term_pf_flush:
        bl      term_flush
        ldr     x9, =term_last
        str     term_back_r, [x9]
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
