// gfx_: the compositor. Builds each frame as one colour slot per display pixel into a buffer,
// at scale s, where a display pixel covers s x s logical pixels.

define(gfx_buf_r, x19)
define(gfx_i_r, x20)
define(gfx_x_r, x21)
define(gfx_g_r, x22)
define(gfx_p_r, x23)
define(gfx_n_r, x24)
define(gfx_d_r, x25)
define(gfx_bits_r, x26)
define(gfx_row_r, x27)
define(gfx_col_r, x28)
define(gfx_sc_r, x19)
define(gfx_rs_r, x20)
define(gfx_ry_r, x21)
define(gfx_y0_r, x20)
define(gfx_x1_r, x21)
define(gfx_y1_r, x22)
define(gfx_slot_r, x23)
define(gfx_x0_r, x24)
define(gfx_slot_w, w23)

GFX_DIV_OFF = 512
GFX_DIV_LO = -512
GFX_DIV_MAX = 511
GFX_SKY_SPLIT = 120
GFX_GRASS_Y = 204
GFX_STRIPE_Y = 212
GFX_STRIPE = 12
GFX_SCORE_Y = 20
GFX_DIGIT_ADV = 12
// rectangles end one past their last column; the body's last column is the one collision uses
GFX_BODY_END = SIM_BODY_X1 + 1

        .section .rodata
        .balign 8
// per scale: display width, display height, row stride (a multiple of 16), cell rows
        .global gfx_geo
gfx_geo:
        .hword  0, 0, 0, 0
        .hword  144, 256, 144, 128
        .hword  72, 128, 80, 64
        .hword  48, 86, 48, 43
        .hword  36, 64, 48, 32
// shortcut: 3 x 5 digits drawn as rectangles until the pixel font replaces them
gfx_font3:
        .hword  0x7B6F, 0x2C97, 0x73E7, 0x73CF, 0x5BC9
        .hword  0x79CF, 0x79EF, 0x7249, 0x7BEF, 0x7BCF

        .bss
        .balign 64
gfx_bg:         .skip   GFX_MAX_BUF
gfx_div:        .skip   2048
        .balign 8
        .global gfx_scale
        .global gfx_dw
        .global gfx_dh
        .global gfx_stride
gfx_scale:      .skip   8
gfx_dw:         .skip   8
gfx_dh:         .skip   8
gfx_stride:     .skip   8
gfx_digits:     .skip   16

        .text

// gfx_copy(x0 = dst, x1 = src, x2 = bytes, a multiple of 64)
        .balign 4
        .global gfx_copy
gfx_copy:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        cbz     x2, gfx_copy_done
gfx_copy_loop:
        // one instruction moves 64 bytes, which is what keeps the playground step budget
        ld1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x1], 64
        st1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x0], 64
        subs    x2, x2, 64
        b.gt    gfx_copy_loop
gfx_copy_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_d(x0 = logical coordinate) -> x0 = display coordinate, floor(v / s) from the table
        .balign 4
gfx_d:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        mov     x9, GFX_DIV_LO
        cmp     x0, x9
        csel    x0, x0, x9, ge
        mov     x9, GFX_DIV_MAX
        cmp     x0, x9
        csel    x0, x0, x9, le
        ldr     x10, =gfx_div
        add     x0, x0, GFX_DIV_OFF
        ldrsh   x0, [x10, x0, lsl 1]
        ldp     fp, lr, [sp], 16
        ret

// gfx_setup(w0 = scale): geometry, the division table and the static background for this scale
gfx_setup_alloc = -(16 + 48) & -16
gfx_setup_dealloc = 0 - gfx_setup_alloc
        .balign 4
        .global gfx_setup
gfx_setup:
        stp     fp, lr, [sp, gfx_setup_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        uxtw    gfx_sc_r, w0
        ldr     x9, =gfx_scale
        str     gfx_sc_r, [x9]
        ldr     x9, =gfx_geo
        add     x9, x9, gfx_sc_r, lsl 3
        ldrh    w10, [x9]
        ldrh    w11, [x9, 2]
        ldrh    w12, [x9, 4]
        ldr     x13, =gfx_dw
        str     x10, [x13]
        ldr     x13, =gfx_dh
        str     x11, [x13]
        ldr     x13, =gfx_stride
        str     x12, [x13]
        // floor division, so a sprite half off the left edge still steps every s pixels
        ldr     x9, =gfx_div
        mov     x10, 0
gfx_setup_div:
        sub     x11, x10, GFX_DIV_OFF
        sdiv    x12, x11, gfx_sc_r
        mul     x13, x12, gfx_sc_r
        cmp     x13, x11
        b.le    gfx_setup_dstore
        sub     x12, x12, 1
gfx_setup_dstore:
        strh    w12, [x9, x10, lsl 1]
        add     x10, x10, 1
        cmp     x10, 1024
        b.lt    gfx_setup_div
        ldr     gfx_p_r, =gfx_bg
        ldr     x9, =gfx_dh
        ldr     gfx_n_r, [x9]
        ldr     x9, =gfx_stride
        ldr     gfx_rs_r, [x9]
        mov     gfx_ry_r, 0
        b       gfx_setup_rtest
gfx_setup_row:
        mul     x9, gfx_ry_r, gfx_sc_r
        mov     w10, SLOT_SKY
        cmp     x9, GFX_SKY_SPLIT
        b.lt    gfx_setup_fill
        mov     w10, SLOT_SKY2
        cmp     x9, GROUND_Y
        b.lt    gfx_setup_fill
        mov     w10, SLOT_GROUND
gfx_setup_fill:
        // a row fill runs once per scale change; sixteen bytes a store keeps it short in steps
        dup     v0.16b, w10
        mov     x11, gfx_rs_r
gfx_setup_put:
        st1     {v0.16b}, [gfx_p_r], 16
        subs    x11, x11, 16
        b.gt    gfx_setup_put
        add     gfx_ry_r, gfx_ry_r, 1
gfx_setup_rtest:
        cmp     gfx_ry_r, gfx_n_r
        b.lt    gfx_setup_row
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], gfx_setup_dealloc
        ret

// gfx_rect(x0 = buf, x1 = x0, x2 = y0, x3 = x1, x4 = y1, w5 = slot): fills logical [x0,x1) x [y0,y1)
gfx_rect_alloc = -(16 + 48) & -16
gfx_rect_dealloc = 0 - gfx_rect_alloc
        .balign 4
gfx_rect:
        stp     fp, lr, [sp, gfx_rect_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        mov     gfx_buf_r, x0
        mov     gfx_y0_r, x2
        mov     gfx_x1_r, x3
        mov     gfx_y1_r, x4
        mov     gfx_slot_w, w5
        mov     x0, x1
        bl      gfx_d
        mov     gfx_x0_r, x0
        mov     x0, gfx_y0_r
        bl      gfx_d
        mov     gfx_y0_r, x0
        mov     x0, gfx_x1_r
        bl      gfx_d
        mov     gfx_x1_r, x0
        mov     x0, gfx_y1_r
        bl      gfx_d
        mov     gfx_y1_r, x0
        cmp     gfx_x0_r, 0
        csel    gfx_x0_r, gfx_x0_r, xzr, ge
        cmp     gfx_y0_r, 0
        csel    gfx_y0_r, gfx_y0_r, xzr, ge
        ldr     x9, =gfx_dw
        ldr     x9, [x9]
        cmp     gfx_x1_r, x9
        csel    gfx_x1_r, gfx_x1_r, x9, le
        ldr     x9, =gfx_dh
        ldr     x9, [x9]
        cmp     gfx_y1_r, x9
        csel    gfx_y1_r, gfx_y1_r, x9, le
        cmp     gfx_x0_r, gfx_x1_r
        b.ge    gfx_rect_done
        cmp     gfx_y0_r, gfx_y1_r
        b.ge    gfx_rect_done
        ldr     x9, =gfx_stride
        ldr     x9, [x9]
gfx_rect_row:
        madd    x10, gfx_y0_r, x9, gfx_buf_r
        add     x10, x10, gfx_x0_r
        sub     x11, gfx_x1_r, gfx_x0_r
gfx_rect_px:
        strb    gfx_slot_w, [x10], 1
        subs    x11, x11, 1
        b.ne    gfx_rect_px
        add     gfx_y0_r, gfx_y0_r, 1
        cmp     gfx_y0_r, gfx_y1_r
        b.lt    gfx_rect_row
gfx_rect_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], gfx_rect_dealloc
        ret

// gfx_score(x0 = buf, x1 = value): placeholder digits, white over a dark outline, centred at the top
gfx_score_alloc = -(16 + 80) & -16
gfx_score_dealloc = 0 - gfx_score_alloc
        .balign 4
gfx_score:
        stp     fp, lr, [sp, gfx_score_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        mov     gfx_buf_r, x0
        ldr     x9, =gfx_digits
        mov     x10, 0
        mov     x11, 10
gfx_score_split:
        udiv    x12, x1, x11
        msub    x13, x12, x11, x1
        strb    w13, [x9, x10]
        add     x10, x10, 1
        mov     x1, x12
        cbnz    x1, gfx_score_split
        mov     gfx_n_r, x10
        // width is k digits of 9 px with 3 px gaps
        mov     x9, GFX_DIGIT_ADV
        mul     x9, gfx_n_r, x9
        sub     x9, x9, 3
        mov     x10, LOG_W
        sub     x10, x10, x9
        asr     gfx_x_r, x10, 1
        mov     gfx_g_r, 1
gfx_score_pass:
        mov     gfx_i_r, gfx_n_r
        mov     gfx_p_r, gfx_x_r
gfx_score_digit:
        sub     gfx_i_r, gfx_i_r, 1
        ldr     x9, =gfx_digits
        ldrb    w10, [x9, gfx_i_r]
        ldr     x9, =gfx_font3
        ldrh    w10, [x9, x10, lsl 1]
        mov     gfx_bits_r, x10
        mov     gfx_d_r, 14
        mov     gfx_row_r, 0
gfx_score_row:
        mov     gfx_col_r, 0
gfx_score_col:
        lsr     x9, gfx_bits_r, gfx_d_r
        tbz     x9, 0, gfx_score_skip
        mov     x9, 3
        madd    x1, gfx_col_r, x9, gfx_p_r
        madd    x2, gfx_row_r, x9, xzr
        add     x2, x2, GFX_SCORE_Y
        add     x3, x1, 3
        add     x4, x2, 3
        mov     w5, SLOT_WHITE
        cbz     gfx_g_r, gfx_score_put
        sub     x1, x1, 1
        sub     x2, x2, 1
        add     x3, x3, 1
        add     x4, x4, 1
        mov     w5, SLOT_DARK
gfx_score_put:
        mov     x0, gfx_buf_r
        bl      gfx_rect
gfx_score_skip:
        sub     gfx_d_r, gfx_d_r, 1
        add     gfx_col_r, gfx_col_r, 1
        cmp     gfx_col_r, 3
        b.lt    gfx_score_col
        add     gfx_row_r, gfx_row_r, 1
        cmp     gfx_row_r, 5
        b.lt    gfx_score_row
        add     gfx_p_r, gfx_p_r, GFX_DIGIT_ADV
        cbnz    gfx_i_r, gfx_score_digit
        cbz     gfx_g_r, gfx_score_done
        mov     gfx_g_r, 0
        b       gfx_score_pass
gfx_score_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], gfx_score_dealloc
        ret

// gfx_frame(x0 = back): composes the current game state into back
gfx_frame_alloc = -(16 + 48) & -16
gfx_frame_dealloc = 0 - gfx_frame_alloc
        .balign 4
        .global gfx_frame
gfx_frame:
        stp     fp, lr, [sp, gfx_frame_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        mov     gfx_buf_r, x0
        ldr     x9, =gfx_dh
        ldr     x9, [x9]
        ldr     x10, =gfx_stride
        ldr     x10, [x10]
        mul     x2, x9, x10
        add     x2, x2, 63
        and     x2, x2, -64
        ldr     x1, =gfx_bg
        bl      gfx_copy
        mov     gfx_i_r, 0
gfx_frame_pipe:
        ldr     x9, =sim_s
        add     x9, x9, SIM_PIPEX
        add     x9, x9, gfx_i_r, lsl 4
        ldr     gfx_x_r, [x9]
        ldr     gfx_g_r, [x9, 8]
        cmp     gfx_x_r, LOG_W
        b.ge    gfx_frame_pnext
        cmn     gfx_x_r, SIM_PIPE_CAP_W
        b.lt    gfx_frame_pnext
        mov     x0, gfx_buf_r
        add     x1, gfx_x_r, 1
        mov     x2, GFX_DIV_LO
        add     x3, gfx_x_r, GFX_BODY_END
        sub     x4, gfx_g_r, SIM_PIPE_CAP_H
        mov     w5, SLOT_PIPE
        bl      gfx_rect
        mov     x0, gfx_buf_r
        mov     x1, gfx_x_r
        sub     x2, gfx_g_r, SIM_PIPE_CAP_H
        add     x3, gfx_x_r, SIM_PIPE_CAP_W
        mov     x4, gfx_g_r
        mov     w5, SLOT_PIPE2
        bl      gfx_rect
        mov     x0, gfx_buf_r
        mov     x1, gfx_x_r
        add     x2, gfx_g_r, SIM_GAP_H
        add     x3, gfx_x_r, SIM_PIPE_CAP_W
        add     x4, x2, SIM_PIPE_CAP_H
        mov     w5, SLOT_PIPE2
        bl      gfx_rect
        mov     x0, gfx_buf_r
        add     x1, gfx_x_r, 1
        add     x2, gfx_g_r, SIM_GAP_H
        add     x2, x2, SIM_PIPE_CAP_H
        add     x3, gfx_x_r, GFX_BODY_END
        mov     x4, GROUND_Y
        mov     w5, SLOT_PIPE
        bl      gfx_rect
gfx_frame_pnext:
        add     gfx_i_r, gfx_i_r, 1
        cmp     gfx_i_r, SIM_PIPES
        b.lt    gfx_frame_pipe
        // stripes on the grass are what show the ground scrolling
        mov     x0, gfx_buf_r
        mov     x1, 0
        mov     x2, GROUND_Y
        mov     x3, LOG_W
        mov     x4, GFX_GRASS_Y
        mov     w5, SLOT_GRASS
        bl      gfx_rect
        ldr     x9, =sim_s
        ldr     x10, [x9, SIM_GROUNDX]
        cmp     x10, GFX_STRIPE
        b.lt    gfx_frame_off
        sub     x10, x10, GFX_STRIPE
gfx_frame_off:
        neg     gfx_x_r, x10
gfx_frame_stripe:
        mov     x0, gfx_buf_r
        mov     x1, gfx_x_r
        mov     x2, GFX_GRASS_Y
        add     x3, gfx_x_r, 6
        mov     x4, GFX_STRIPE_Y
        mov     w5, SLOT_GROUND2
        bl      gfx_rect
        add     gfx_x_r, gfx_x_r, GFX_STRIPE
        cmp     gfx_x_r, LOG_W
        b.lt    gfx_frame_stripe
        ldr     x9, =sim_s
        ldr     x10, [x9, SIM_STATE]
        ldr     x11, [x9, SIM_Y]
        mov     gfx_x_r, SIM_BIRD_X
        cmp     x10, SIM_READY
        b.gt    gfx_frame_fade
        ldr     x12, [x9, SIM_BOB]
        add     x11, x11, x12
        cbnz    x10, gfx_frame_bird
        mov     gfx_x_r, SIM_TITLE_X
        b       gfx_frame_bird
gfx_frame_fade:
        // a fade from the title has no pipes parked on the field yet
        cmp     x10, SIM_FADE
        b.ne    gfx_frame_bird
        ldr     x12, [x9, SIM_PIPEX]
        cmp     x12, SIM_PIPE_NONE
        b.ne    gfx_frame_bird
        mov     gfx_x_r, SIM_TITLE_X
gfx_frame_bird:
        asr     gfx_g_r, x11, 8
        mov     x0, gfx_buf_r
        mov     x1, gfx_x_r
        mov     x2, gfx_g_r
        add     x3, gfx_x_r, SIM_BIRD_W
        add     x4, gfx_g_r, SIM_BIRD_H
        mov     w5, SLOT_BIRD
        bl      gfx_rect
        mov     x0, gfx_buf_r
        add     x1, gfx_x_r, 11
        add     x2, gfx_g_r, 2
        add     x3, gfx_x_r, 15
        add     x4, gfx_g_r, 6
        mov     w5, SLOT_WHITE
        bl      gfx_rect
        mov     x0, gfx_buf_r
        add     x1, gfx_x_r, 13
        add     x2, gfx_g_r, 3
        add     x3, gfx_x_r, 15
        add     x4, gfx_g_r, 5
        mov     w5, SLOT_DARK
        bl      gfx_rect
        ldr     x9, =sim_s
        ldr     x10, [x9, SIM_STATE]
        cbz     x10, gfx_frame_done
        cmp     x10, SIM_FADE
        b.eq    gfx_frame_done
        mov     x0, gfx_buf_r
        ldr     x1, [x9, SIM_SCORE]
        bl      gfx_score
gfx_frame_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], gfx_frame_dealloc
        ret
