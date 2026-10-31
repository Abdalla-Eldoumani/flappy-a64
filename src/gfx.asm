// gfx_: the compositor. A scale change bakes the background, ground, pipes, bird and digits
// from the logical art; each frame is then row copies and masked blits of those bakes.

define(gfx_buf_r, x19)
define(gfx_src_r, x20)
define(gfx_dst_r, x21)
define(gfx_w_r, x22)
define(gfx_h_r, x23)
define(gfx_y_r, x24)
define(gfx_x_r, x25)
define(gfx_s_r, x26)
define(gfx_k_r, x27)
define(gfx_n_r, x28)
define(gfx_fill32_r, w26)
define(gfx_edge32_r, w19)
define(gfx_out32_r, w28)
define(gfx_ang_r, x19)
define(gfx_frm_r, x20)
define(gfx_box_r, x24)
define(gfx_w32_r, w22)
define(gfx_h32_r, w23)
define(gfx_txt_r, x19)
define(gfx_gw_r, x20)
define(gfx_gh_r, x21)
define(gfx_step_r, x22)
define(gfx_adv_r, x23)
define(gfx_dig_r, x24)
define(gfx_sc_r, x19)
define(gfx_gy_r, x20)
define(gfx_gy0_r, x21)
define(gfx_gs_r, x22)
define(gfx_row_r, x21)
define(gfx_cx_r, x26)
define(gfx_bx_r, x27)
define(gfx_r0_r, x20)
define(gfx_r1_r, x21)
define(gfx_r2_r, x22)
define(gfx_r3_r, x23)
define(gfx_cnt_r, x20)
define(gfx_dadv_r, x21)
define(gfx_dw_r, x22)
define(gfx_px_r, x23)
define(gfx_py_r, x24)
define(gfx_fa_r, x20)
define(gfx_fb_r, x21)
define(gfx_fc_r, x22)
define(gfx_fd_r, x23)
define(gfx_fe_r, x24)
define(gfx_fd32_r, w23)

GFX_DIV_OFF = 512
GFX_DIV_LO = -512
GFX_DIV_MAX = 511
GFX_LSTRIDE = 240
GFX_STRIP_W = 240
GFX_SKY_SPLIT = 128
GFX_CLOUD_Y = 130
GFX_CITY_Y = 158
GFX_BUSH_Y = 184
GFX_DIRT_Y = 212
GFX_SCORE_Y = 18
GFX_BOX = 24
// baked angles run from SIM_TILT_DRAW_MAX down to SIM_TILT_MIN, a step apart
GFX_ANGLE_STEP = 10
GFX_ANGLES = (SIM_TILT_DRAW_MAX - SIM_TILT_MIN) / GFX_ANGLE_STEP + 1
GFX_ANGLE_LAST = GFX_ANGLES - 1
GFX_ANGLE_ROUND = GFX_ANGLE_STEP / 2
GFX_CLEAR = 255
GFX_BREATH = 200000
GFX_MS = 1000000
// a byte times this is that byte in all eight lanes of a word
GFX_BYTES8 = 0x0101010101010101
GFX_DIGIT_BYTES = 96
// x times this, shifted right 16, is x / GFX_ANGLE_STEP for every tilt the sim reaches
GFX_STEP_RECIP = 65536 / GFX_ANGLE_STEP + 1
// instructions each heavy init loop spends per unit of work, counted toward the next sleep
GFX_COST_TILE = 16
GFX_COST_SHRINK = 32
GFX_COST_ROTATE = 48
GFX_COST_OUTLINE = 300
GFX_COST_DIV = 12
GFX_LOGIC_BYTES = GFX_LSTRIDE * LOG_H
GFX_STRIP_BYTES = GFX_STRIP_W * (LOG_H - GROUND_Y)
GFX_ROT_BYTES = GFX_ANGLES * ART_FRAMES * GFX_BOX * GFX_BOX
GFX_DIV_SIZE = GFX_DIV_OFF * 2
GFX_DIV_COST = GFX_DIV_SIZE * GFX_COST_DIV
GFX_DIV_BYTES = GFX_DIV_SIZE * 2
GFX_BODY_STRIDE = 32
// big digits keep a pixel between outlines; font digits share one outline column
GFX_BIG_ADV = ART_BIG_W + 3
GFX_F5_ADV = ART_F5_W + 1
GFX_F3_ADV = ART_F3_W + 1
GFX_F5_DIGITS = ART_DIGIT0 * ART_F5_STEP
GFX_F3_DIGITS = ART_DIGIT0 * ART_F3_STEP

        .section .rodata
// per scale: display width, display height, row stride (a multiple of 16), cell rows
        .balign 8
        .global gfx_geo
gfx_geo:
        .hword  0, 0, 0, 0
        .hword  144, 256, 144, 128
        .hword  72, 128, 80, 64
        .hword  48, 86, 48, 43
        .hword  36, 64, 48, 32
// per scale: hand-drawn bird frame width and height
gfx_birdwh:
        .hword  0, 0, 17, 12, 9, 6, 6, 4, 5, 3

        .bss
        .balign 64
gfx_logic:      .skip   GFX_LOGIC_BYTES
gfx_bg:         .skip   GFX_MAX_BUF
gfx_ground:     .skip   GFX_STRIP_BYTES
gfx_rot:        .skip   GFX_ROT_BYTES
gfx_div:        .skip   GFX_DIV_BYTES
gfx_sprite:     .skip   1280
gfx_cap:        .skip   320
gfx_body:       .skip   GFX_BODY_STRIDE
gfx_digit:      .skip   960
gfx_bits:       .skip   128
gfx_nums:       .skip   16
        .balign 8
        .global gfx_dw
        .global gfx_dh
        .global gfx_stride
gfx_scale:      .skip   8
gfx_dw:         .skip   8
gfx_dh:         .skip   8
gfx_stride:     .skip   8
gfx_groundy:    .skip   8
gfx_gstride:    .skip   8
gfx_capw:       .skip   8
gfx_caph:       .skip   8
gfx_bodyw:      .skip   8
gfx_box:        .skip   8
gfx_rotox:      .skip   8
gfx_rotoy:      .skip   8
gfx_digw:       .skip   8
gfx_digh:       .skip   8
gfx_digadv:     .skip   8
gfx_work:       .skip   8

        .text

// gfx_copy(x0 = dst, x1 = src, x2 = bytes, a multiple of 64)
        .balign 4
gfx_copy:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        cbz     x2, gfx_copy_done
gfx_copy_loop:
        // one instruction moves 64 bytes, and the playground meters instructions, not bytes
        ld1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x1], 64
        st1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x0], 64
        subs    x2, x2, 64
        b.gt    gfx_copy_loop
gfx_copy_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_span(x0 = dst, x1 = src, x2 = bytes): an opaque row copy, 16 bytes at a time
        .balign 4
gfx_span:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        b       gfx_span_test
gfx_span_wide:
        ld1     {v0.16b}, [x1], 16
        st1     {v0.16b}, [x0], 16
        sub     x2, x2, 16
gfx_span_test:
        cmp     x2, 16
        b.ge    gfx_span_wide
        cbz     x2, gfx_span_done
gfx_span_byte:
        ldrb    w9, [x1], 1
        strb    w9, [x0], 1
        subs    x2, x2, 1
        b.ne    gfx_span_byte
gfx_span_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_mask(x0 = dst, x1 = src, x2 = bytes): copies only the src bytes that are not transparent
        .balign 4
gfx_mask:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        movi    v31.16b, GFX_CLEAR
        b       gfx_mask_test
gfx_mask_wide:
        // sixteen pixels per compare and select, so a sprite row costs a few steps
        ld1     {v0.16b}, [x1], 16
        ld1     {v1.16b}, [x0]
        cmeq    v2.16b, v0.16b, v31.16b
        bif     v1.16b, v0.16b, v2.16b
        st1     {v1.16b}, [x0], 16
        sub     x2, x2, 16
gfx_mask_test:
        cmp     x2, 16
        b.ge    gfx_mask_wide
        cbz     x2, gfx_mask_done
gfx_mask_byte:
        ldrb    w9, [x1], 1
        cmp     w9, GFX_CLEAR
        b.eq    gfx_mask_skip
        strb    w9, [x0]
gfx_mask_skip:
        add     x0, x0, 1
        subs    x2, x2, 1
        b.ne    gfx_mask_byte
gfx_mask_done:
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

// gfx_up(x0 = logical size) -> x0 = display size, rounded up
        .balign 4
gfx_up:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =gfx_scale
        ldr     x9, [x9]
        add     x0, x0, x9
        sub     x0, x0, 1
        bl      gfx_d
        ldp     fp, lr, [sp], 16
        ret

// gfx_breath(x0 = instructions just run): a 1 ms sleep every 200,000, as the playground needs
        .balign 4
        .global gfx_breath
gfx_breath:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =gfx_work
        ldr     x10, [x9]
        add     x10, x10, x0
        ldr     x11, =GFX_BREATH
        cmp     x10, x11
        b.lt    gfx_breath_keep
        mov     x10, 0
        str     x10, [x9]
        ldr     x0, =GFX_MS
        bl      tty_sleep
        b       gfx_breath_done
gfx_breath_keep:
        str     x10, [x9]
gfx_breath_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_fill(w0 = slot, x1 = first row, x2 = end row): fills whole rows of the logical scratch
        .balign 4
gfx_fill:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        and     x0, x0, 255
        ldr     x12, =GFX_BYTES8
        mul     x12, x0, x12
        ldr     x9, =gfx_logic
        mov     x10, GFX_LSTRIDE
        madd    x9, x1, x10, x9
        sub     x11, x2, x1
        mul     x11, x11, x10
        cbz     x11, gfx_fill_done
gfx_fill_loop:
        str     x12, [x9], 8
        subs    x11, x11, 8
        b.gt    gfx_fill_loop
gfx_fill_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_tile(x0 = sprite, x1 = w, x2 = h, x3 = logical row, x4 = width): repeats it across the scratch
        .balign 4
gfx_tile:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =gfx_logic
        mov     x10, GFX_LSTRIDE
        madd    x9, x3, x10, x9
        mov     x11, 0
gfx_tile_row:
        mul     x12, x11, x1
        add     x12, x0, x12
        mov     x13, 0
        mov     x14, 0
gfx_tile_px:
        ldrb    w15, [x12, x14]
        cmp     w15, GFX_CLEAR
        b.eq    gfx_tile_next
        strb    w15, [x9, x13]
gfx_tile_next:
        add     x14, x14, 1
        cmp     x14, x1
        csel    x14, x14, xzr, lt
        add     x13, x13, 1
        cmp     x13, x4
        b.lt    gfx_tile_px
        add     x9, x9, x10
        add     x11, x11, 1
        cmp     x11, x2
        b.lt    gfx_tile_row
        mov     x0, GFX_COST_TILE
        mul     x0, x0, x4
        mul     x0, x0, x2
        bl      gfx_breath
        ldp     fp, lr, [sp], 16
        ret

// gfx_shrink(x0 = src, x1 = w, x2 = h, x3 = src stride, x4 = dst, x5 = dst stride)
// Each s x s block keeps its highest-priority slot, so outlines and eyes survive scaling down.
gfx_shrink_alloc = -(16 + 80) & -16
gfx_shrink_dealloc = 0 - gfx_shrink_alloc
        .balign 4
gfx_shrink:
        stp     fp, lr, [sp, gfx_shrink_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        mov     gfx_src_r, x0
        mov     gfx_w_r, x1
        mov     gfx_h_r, x2
        mov     gfx_k_r, x3
        mov     gfx_dst_r, x4
        mov     gfx_n_r, x5
        ldr     x9, =gfx_scale
        ldr     gfx_s_r, [x9]
        mov     gfx_y_r, 0
gfx_shrink_row:
        mov     gfx_x_r, 0
        mov     x15, gfx_dst_r
gfx_shrink_px:
        mov     w0, GFX_CLEAR
        mov     x1, -1
        add     x2, gfx_y_r, gfx_s_r
        cmp     x2, gfx_h_r
        csel    x2, x2, gfx_h_r, le
        add     x3, gfx_x_r, gfx_s_r
        cmp     x3, gfx_w_r
        csel    x3, x3, gfx_w_r, le
        ldr     x6, =art_prio
        mov     x4, gfx_y_r
gfx_shrink_by:
        madd    x7, x4, gfx_k_r, gfx_src_r
        mov     x5, gfx_x_r
gfx_shrink_bx:
        ldrb    w8, [x7, x5]
        cmp     w8, GFX_CLEAR
        b.eq    gfx_shrink_bnext
        ldrb    w9, [x6, x8]
        cmp     x9, x1
        b.le    gfx_shrink_bnext
        mov     x1, x9
        mov     w0, w8
gfx_shrink_bnext:
        add     x5, x5, 1
        cmp     x5, x3
        b.lt    gfx_shrink_bx
        add     x4, x4, 1
        cmp     x4, x2
        b.lt    gfx_shrink_by
        strb    w0, [x15], 1
        add     gfx_x_r, gfx_x_r, gfx_s_r
        cmp     gfx_x_r, gfx_w_r
        b.lt    gfx_shrink_px
        mul     x0, gfx_w_r, gfx_s_r
        mov     x9, GFX_COST_SHRINK
        mul     x0, x0, x9
        bl      gfx_breath
        add     gfx_dst_r, gfx_dst_r, gfx_n_r
        add     gfx_y_r, gfx_y_r, gfx_s_r
        cmp     gfx_y_r, gfx_h_r
        b.lt    gfx_shrink_row
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], gfx_shrink_dealloc
        ret

// gfx_glyph(x0 = text, x1 = w, x2 = h, x3 = dest): a glyph's pixels as bytes, 1 on and 0 off
        .balign 4
gfx_glyph:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        mul     x9, x1, x2
gfx_glyph_loop:
        ldrb    w10, [x0], 1
        cmp     w10, ART_SLASH
        b.eq    gfx_glyph_loop
        cmp     w10, ART_ON
        cset    w10, eq
        strb    w10, [x3], 1
        subs    x9, x9, 1
        b.ne    gfx_glyph_loop
        ldp     fp, lr, [sp], 16
        ret

// gfx_on(x0 = bits, x1 = w, x2 = h, x3 = x, x4 = y) -> x0 = 1 when that pixel is on
        .balign 4
gfx_on:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        cmp     x3, x1
        b.hs    gfx_on_no
        cmp     x4, x2
        b.hs    gfx_on_no
        madd    x9, x4, x1, x3
        ldrb    w0, [x0, x9]
        b       gfx_on_done
gfx_on_no:
        mov     x0, 0
gfx_on_done:
        ldp     fp, lr, [sp], 16
        ret

// gfx_outline(x0 = bits, x1 = w, x2 = h, x3 = dest, w4 = fill, w5 = edge): a sprite of
// (w + 2) x (h + 2) whose on pixels take fill and whose off pixels touching them take edge
gfx_outline_alloc = -(16 + 80) & -16
gfx_outline_dealloc = 0 - gfx_outline_alloc
        .balign 4
gfx_outline:
        stp     fp, lr, [sp, gfx_outline_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        mov     gfx_src_r, x0
        mov     gfx_w_r, x1
        mov     gfx_h_r, x2
        mov     gfx_dst_r, x3
        mov     gfx_fill32_r, w4
        mov     gfx_edge32_r, w5
        mov     gfx_y_r, 0
gfx_outline_row:
        mov     gfx_x_r, 0
gfx_outline_px:
        // pixel (x - 1, y - 1) of the glyph sits under this one
        mov     x0, gfx_src_r
        mov     x1, gfx_w_r
        mov     x2, gfx_h_r
        sub     x3, gfx_x_r, 1
        sub     x4, gfx_y_r, 1
        bl      gfx_on
        mov     gfx_out32_r, gfx_fill32_r
        cbnz    x0, gfx_outline_put
        mov     gfx_out32_r, gfx_edge32_r
        mov     gfx_k_r, 0
gfx_outline_near:
        mov     x0, gfx_src_r
        mov     x1, gfx_w_r
        mov     x2, gfx_h_r
        mov     x9, 3
        udiv    x10, gfx_k_r, x9
        msub    x11, x10, x9, gfx_k_r
        add     x3, gfx_x_r, x11
        sub     x3, x3, 2
        add     x4, gfx_y_r, x10
        sub     x4, x4, 2
        bl      gfx_on
        cbnz    x0, gfx_outline_put
        add     gfx_k_r, gfx_k_r, 1
        cmp     gfx_k_r, 9
        b.lt    gfx_outline_near
        mov     gfx_out32_r, GFX_CLEAR
gfx_outline_put:
        strb    gfx_out32_r, [gfx_dst_r], 1
        add     gfx_x_r, gfx_x_r, 1
        add     x9, gfx_w_r, 2
        cmp     gfx_x_r, x9
        b.lt    gfx_outline_px
        add     x0, gfx_w_r, 2
        mov     x9, GFX_COST_OUTLINE
        mul     x0, x0, x9
        bl      gfx_breath
        add     gfx_y_r, gfx_y_r, 1
        add     x9, gfx_h_r, 2
        cmp     gfx_y_r, x9
        b.lt    gfx_outline_row
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], gfx_outline_dealloc
        ret

// gfx_rotate(x0 = frame, x1 = w, x2 = h, x3 = dest box, x4 = box, x5 = sin, x6 = cos, Q14)
// Inverse mapping in half-pixel units, so the frame turns about its own centre.
        .balign 4
gfx_rotate:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        mov     x7, 0
gfx_rot_row:
        lsl     x8, x7, 1
        add     x8, x8, 1
        sub     x8, x8, x4
        mov     x9, 0
gfx_rot_px:
        lsl     x10, x9, 1
        add     x10, x10, 1
        sub     x10, x10, x4
        mul     x11, x10, x6
        msub    x11, x8, x5, x11
        asr     x11, x11, 14
        mul     x12, x10, x5
        madd    x12, x8, x6, x12
        asr     x12, x12, 14
        add     x11, x11, x1
        asr     x11, x11, 1
        add     x12, x12, x2
        asr     x12, x12, 1
        mov     w13, GFX_CLEAR
        cmp     x11, x1
        b.hs    gfx_rot_put
        cmp     x12, x2
        b.hs    gfx_rot_put
        madd    x14, x12, x1, x11
        ldrb    w13, [x0, x14]
gfx_rot_put:
        strb    w13, [x3], 1
        add     x9, x9, 1
        cmp     x9, x4
        b.lt    gfx_rot_px
        add     x7, x7, 1
        cmp     x7, x4
        b.lt    gfx_rot_row
        ldp     fp, lr, [sp], 16
        ret

// gfx_bake_bird(): the scale's three wing frames, turned to each of the 23 tilts
gfx_bake_bird_alloc = -(16 + 48) & -16
gfx_bake_bird_dealloc = 0 - gfx_bake_bird_alloc
        .balign 4
gfx_bake_bird:
        stp     fp, lr, [sp, gfx_bake_bird_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        ldr     x9, =gfx_scale
        ldr     x9, [x9]
        ldr     x10, =gfx_birdwh
        add     x10, x10, x9, lsl 2
        ldrh    gfx_w32_r, [x10]
        ldrh    gfx_h32_r, [x10, 2]
        ldr     x0, =art_bird1
        cmp     x9, 2
        b.lt    gfx_bake_text
        ldr     x0, =art_bird2
        b.eq    gfx_bake_text
        ldr     x0, =art_bird3
        cmp     x9, 3
        b.eq    gfx_bake_text
        ldr     x0, =art_bird4
gfx_bake_text:
        ldr     x1, =art_l_bird
        mul     x2, gfx_w_r, gfx_h_r
        add     x2, x2, x2, lsl 1
        ldr     x3, =gfx_sprite
        bl      art_decode
        mov     x0, GFX_BOX
        bl      gfx_d
        mov     gfx_box_r, x0
        ldr     x9, =gfx_box
        str     gfx_box_r, [x9]
        // the box sits so that an unturned frame lands where the unrotated sprite would
        mov     x10, 1
        sub     x10, x10, gfx_box_r
        add     x11, x10, gfx_w_r
        asr     x11, x11, 1
        neg     x11, x11
        ldr     x9, =gfx_rotox
        str     x11, [x9]
        add     x11, x10, gfx_h_r
        asr     x11, x11, 1
        neg     x11, x11
        ldr     x9, =gfx_rotoy
        str     x11, [x9]
        ldr     gfx_dst_r, =gfx_rot
        mov     gfx_ang_r, 0
gfx_bake_angle:
        mov     gfx_frm_r, 0
gfx_bake_frame:
        ldr     x0, =gfx_sprite
        mul     x9, gfx_w_r, gfx_h_r
        madd    x0, gfx_frm_r, x9, x0
        mov     x1, gfx_w_r
        mov     x2, gfx_h_r
        mov     x3, gfx_dst_r
        mov     x4, gfx_box_r
        ldr     x9, =art_trig
        add     x9, x9, gfx_ang_r, lsl 2
        ldrsh   x5, [x9]
        ldrsh   x6, [x9, 2]
        bl      gfx_rotate
        mul     x9, gfx_box_r, gfx_box_r
        add     gfx_dst_r, gfx_dst_r, x9
        mov     x0, GFX_COST_ROTATE
        mul     x0, x0, x9
        bl      gfx_breath
        add     gfx_frm_r, gfx_frm_r, 1
        cmp     gfx_frm_r, ART_FRAMES
        b.lt    gfx_bake_frame
        add     gfx_ang_r, gfx_ang_r, 1
        cmp     gfx_ang_r, GFX_ANGLES
        b.lt    gfx_bake_angle
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], gfx_bake_bird_dealloc
        ret

// gfx_bake_digits(): outlined score digits drawn at display size: big at scale 1, then 5 x 7
// and 3 x 5 fonts, because shrinking the big ones leaves unreadable smudges
gfx_bake_digits_alloc = -(16 + 48) & -16
gfx_bake_digits_dealloc = 0 - gfx_bake_digits_alloc
        .balign 4
gfx_bake_digits:
        stp     fp, lr, [sp, gfx_bake_digits_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        ldr     x9, =gfx_scale
        ldr     x9, [x9]
        ldr     gfx_txt_r, =art_big
        mov     gfx_gw_r, ART_BIG_W
        mov     gfx_gh_r, ART_BIG_H
        mov     gfx_step_r, ART_BIG_STEP
        mov     gfx_adv_r, GFX_BIG_ADV
        cmp     x9, 1
        b.eq    gfx_digits_size
        ldr     gfx_txt_r, =art_font5
        add     gfx_txt_r, gfx_txt_r, GFX_F5_DIGITS
        mov     gfx_gw_r, ART_F5_W
        mov     gfx_gh_r, ART_F5_H
        mov     gfx_step_r, ART_F5_STEP
        mov     gfx_adv_r, GFX_F5_ADV
        cmp     x9, 2
        b.eq    gfx_digits_size
        ldr     gfx_txt_r, =art_font3
        add     gfx_txt_r, gfx_txt_r, GFX_F3_DIGITS
        mov     gfx_gw_r, ART_F3_W
        mov     gfx_gh_r, ART_F3_H
        mov     gfx_step_r, ART_F3_STEP
        mov     gfx_adv_r, GFX_F3_ADV
gfx_digits_size:
        add     x9, gfx_gw_r, 2
        ldr     x10, =gfx_digw
        str     x9, [x10]
        add     x9, gfx_gh_r, 2
        ldr     x10, =gfx_digh
        str     x9, [x10]
        ldr     x10, =gfx_digadv
        str     gfx_adv_r, [x10]
        mov     gfx_dig_r, 0
gfx_digits_one:
        madd    x0, gfx_dig_r, gfx_step_r, gfx_txt_r
        mov     x1, gfx_gw_r
        mov     x2, gfx_gh_r
        ldr     x3, =gfx_bits
        bl      gfx_glyph
        ldr     x0, =gfx_bits
        mov     x1, gfx_gw_r
        mov     x2, gfx_gh_r
        ldr     x3, =gfx_digit
        mov     x9, GFX_DIGIT_BYTES
        madd    x3, gfx_dig_r, x9, x3
        mov     w4, SLOT_WHITE
        mov     w5, SLOT_TOUT
        bl      gfx_outline
        add     gfx_dig_r, gfx_dig_r, 1
        cmp     gfx_dig_r, 10
        b.lt    gfx_digits_one
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     fp, lr, [sp], gfx_bake_digits_dealloc
        ret

// gfx_setup(w0 = scale): bakes everything a frame needs at this scale
gfx_setup_alloc = -(16 + 32) & -16
gfx_setup_dealloc = 0 - gfx_setup_alloc
        .balign 4
        .global gfx_setup
gfx_setup:
        stp     fp, lr, [sp, gfx_setup_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
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
        cmp     x10, GFX_DIV_SIZE
        b.lt    gfx_setup_div
        ldr     x0, =GFX_DIV_COST
        bl      gfx_breath
        mov     x0, GROUND_Y
        bl      gfx_d
        mov     gfx_gy_r, x0
        ldr     x9, =gfx_groundy
        str     gfx_gy_r, [x9]
        // drawn once at logical size and shrunk, so every scale shows the same scene
        mov     w0, SLOT_SKY1
        mov     x1, 0
        mov     x2, GFX_SKY_SPLIT
        bl      gfx_fill
        mov     w0, SLOT_SKY2
        mov     x1, GFX_SKY_SPLIT
        mov     x2, LOG_H
        bl      gfx_fill
        ldr     x0, =art_cloud
        ldr     x1, =art_l_cloud
        mov     x2, ART_CLOUD_PX
        ldr     x3, =gfx_sprite
        bl      art_decode
        ldr     x0, =gfx_sprite
        mov     x1, ART_CLOUD_W
        mov     x2, ART_CLOUD_H
        mov     x3, GFX_CLOUD_Y
        mov     x4, LOG_W
        bl      gfx_tile
        ldr     x0, =art_city
        ldr     x1, =art_l_city
        mov     x2, ART_CITY_PX
        ldr     x3, =gfx_sprite
        bl      art_decode
        ldr     x0, =gfx_sprite
        mov     x1, ART_CITY_W
        mov     x2, ART_CITY_H
        mov     x3, GFX_CITY_Y
        mov     x4, LOG_W
        bl      gfx_tile
        ldr     x0, =art_bush
        ldr     x1, =art_l_bush
        mov     x2, ART_BUSH_PX
        ldr     x3, =gfx_sprite
        bl      art_decode
        ldr     x0, =gfx_sprite
        mov     x1, ART_BUSH_W
        mov     x2, ART_BUSH_H
        mov     x3, GFX_BUSH_Y
        mov     x4, LOG_W
        bl      gfx_tile
        ldr     x0, =gfx_logic
        mov     x1, LOG_W
        mov     x2, LOG_H
        mov     x3, GFX_LSTRIDE
        ldr     x4, =gfx_bg
        ldr     x5, =gfx_stride
        ldr     x5, [x5]
        bl      gfx_shrink
        // the ground strip starts on the display grid, which may be a row or two above y 200
        mul     gfx_gy0_r, gfx_gy_r, gfx_sc_r
        mov     w0, SLOT_BUSH2
        mov     x1, gfx_gy0_r
        mov     x2, GROUND_Y
        bl      gfx_fill
        mov     w0, SLOT_DIRT
        mov     x1, GFX_DIRT_Y
        mov     x2, LOG_H
        bl      gfx_fill
        ldr     x0, =art_ground
        ldr     x1, =art_l_ground
        mov     x2, ART_GROUND_PX
        ldr     x3, =gfx_sprite
        bl      art_decode
        ldr     x0, =gfx_sprite
        mov     x1, SIM_GROUND_PERIOD
        mov     x2, ART_GROUND_H
        mov     x3, GROUND_Y
        mov     x4, GFX_STRIP_W
        bl      gfx_tile
        mov     x0, GFX_STRIP_W
        bl      gfx_up
        add     x0, x0, 15
        and     gfx_gs_r, x0, -16
        ldr     x9, =gfx_gstride
        str     gfx_gs_r, [x9]
        ldr     x0, =gfx_logic
        mov     x9, GFX_LSTRIDE
        madd    x0, gfx_gy0_r, x9, x0
        mov     x1, GFX_STRIP_W
        mov     x2, LOG_H
        sub     x2, x2, gfx_gy0_r
        mov     x3, GFX_LSTRIDE
        ldr     x4, =gfx_ground
        mov     x5, gfx_gs_r
        bl      gfx_shrink
        // a body row repeats all the way down, so only the cap and one body row are shrunk
        ldr     x0, =art_cap
        ldr     x1, =art_l_pipe
        mov     x2, ART_CAP_PX
        ldr     x3, =gfx_sprite
        bl      art_decode
        mov     x0, SIM_PIPE_CAP_W
        bl      gfx_up
        ldr     x9, =gfx_capw
        str     x0, [x9]
        mov     x0, SIM_PIPE_CAP_H
        bl      gfx_up
        ldr     x9, =gfx_caph
        str     x0, [x9]
        ldr     x0, =gfx_sprite
        mov     x1, SIM_PIPE_CAP_W
        mov     x2, SIM_PIPE_CAP_H
        mov     x3, SIM_PIPE_CAP_W
        ldr     x4, =gfx_cap
        ldr     x5, =gfx_capw
        ldr     x5, [x5]
        bl      gfx_shrink
        ldr     x0, =art_pbody
        ldr     x1, =art_l_pipe
        mov     x2, ART_BODY_W
        ldr     x3, =gfx_sprite
        bl      art_decode
        mov     x0, ART_BODY_W
        bl      gfx_up
        ldr     x9, =gfx_bodyw
        str     x0, [x9]
        ldr     x0, =gfx_sprite
        mov     x1, ART_BODY_W
        mov     x2, 1
        mov     x3, ART_BODY_W
        ldr     x4, =gfx_body
        mov     x5, GFX_BODY_STRIDE
        bl      gfx_shrink
        bl      gfx_bake_bird
        bl      gfx_bake_digits
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     fp, lr, [sp], gfx_setup_dealloc
        ret

// gfx_clip(x0 = x, x1 = w) -> x0 = first column kept, x1 = columns kept, x2 = columns skipped
        .balign 4
gfx_clip:
        stp     fp, lr, [sp, -16]!
        mov     fp, sp
        ldr     x9, =gfx_dw
        ldr     x9, [x9]
        add     x10, x0, x1
        cmp     x10, x9
        csel    x10, x10, x9, le
        mov     x2, 0
        cmp     x0, 0
        b.ge    gfx_clip_left
        neg     x2, x0
        mov     x0, 0
gfx_clip_left:
        subs    x1, x10, x0
        csel    x1, x1, xzr, gt
        ldp     fp, lr, [sp], 16
        ret

// gfx_blit(x0 = back, x1 = sprite, x2 = w, x3 = h, x4 = x, x5 = y): transparent pixels show through
gfx_blit_alloc = -(16 + 80) & -16
gfx_blit_dealloc = 0 - gfx_blit_alloc
        .balign 4
gfx_blit:
        stp     fp, lr, [sp, gfx_blit_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        mov     gfx_buf_r, x0
        mov     gfx_src_r, x1
        mov     gfx_w_r, x2
        mov     gfx_h_r, x3
        mov     gfx_y_r, x5
        mov     x0, x4
        mov     x1, x2
        bl      gfx_clip
        cbz     x1, gfx_blit_done
        mov     gfx_x_r, x0
        mov     gfx_k_r, x1
        add     gfx_src_r, gfx_src_r, x2
        ldr     x9, =gfx_dh
        ldr     gfx_n_r, [x9]
        ldr     x9, =gfx_stride
        ldr     gfx_s_r, [x9]
        mov     gfx_row_r, 0
gfx_blit_row:
        add     x9, gfx_y_r, gfx_row_r
        cmp     x9, gfx_n_r
        b.hs    gfx_blit_next
        madd    x0, x9, gfx_s_r, gfx_buf_r
        add     x0, x0, gfx_x_r
        madd    x1, gfx_row_r, gfx_w_r, gfx_src_r
        mov     x2, gfx_k_r
        bl      gfx_mask
gfx_blit_next:
        add     gfx_row_r, gfx_row_r, 1
        cmp     gfx_row_r, gfx_h_r
        b.lt    gfx_blit_row
gfx_blit_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], gfx_blit_dealloc
        ret

// gfx_pipe_rows(x0 = back, x1 = src row, x2 = src stride, x3 = x, x4 = w, x5 = first row, x6 = end)
// copies one opaque pipe part over display rows [first, end), clipped at the edges
gfx_pipe_rows_alloc = -(16 + 80) & -16
gfx_pipe_rows_dealloc = 0 - gfx_pipe_rows_alloc
        .balign 4
gfx_pipe_rows:
        stp     fp, lr, [sp, gfx_pipe_rows_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        stp     x27, x28, [sp, 80]
        mov     gfx_buf_r, x0
        mov     gfx_src_r, x1
        mov     gfx_n_r, x2
        mov     gfx_y_r, x5
        mov     gfx_h_r, x6
        mov     x0, x3
        mov     x1, x4
        bl      gfx_clip
        cbz     x1, gfx_pipe_done
        mov     gfx_x_r, x0
        mov     gfx_k_r, x1
        add     gfx_src_r, gfx_src_r, x2
        ldr     x9, =gfx_stride
        ldr     gfx_s_r, [x9]
        cmp     gfx_y_r, 0
        csel    gfx_row_r, gfx_y_r, xzr, ge
        // rows above the top edge are skipped, but the source still advances past them
        sub     x9, gfx_row_r, gfx_y_r
        madd    gfx_src_r, x9, gfx_n_r, gfx_src_r
        b       gfx_pipe_test
gfx_pipe_row:
        madd    x0, gfx_row_r, gfx_s_r, gfx_buf_r
        add     x0, x0, gfx_x_r
        mov     x1, gfx_src_r
        mov     x2, gfx_k_r
        bl      gfx_span
        add     gfx_src_r, gfx_src_r, gfx_n_r
        add     gfx_row_r, gfx_row_r, 1
gfx_pipe_test:
        cmp     gfx_row_r, gfx_h_r
        b.lt    gfx_pipe_row
gfx_pipe_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldp     x27, x28, [sp, 80]
        ldp     fp, lr, [sp], gfx_pipe_rows_dealloc
        ret

// gfx_pipe(x0 = back, x1 = pipe x, x2 = gap top): body, cap, gap, cap, body down to the ground
gfx_pipe_alloc = -(16 + 72) & -16
gfx_pipe_dealloc = 0 - gfx_pipe_alloc
        .balign 4
gfx_pipe:
        stp     fp, lr, [sp, gfx_pipe_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        stp     x25, x26, [sp, 64]
        str     gfx_bx_r, [sp, 80]
        mov     gfx_buf_r, x0
        mov     gfx_x_r, x1
        mov     gfx_y_r, x2
        mov     x0, gfx_x_r
        bl      gfx_d
        mov     gfx_cx_r, x0
        add     x0, gfx_x_r, 1
        bl      gfx_d
        mov     gfx_bx_r, x0
        sub     x0, gfx_y_r, SIM_PIPE_CAP_H
        bl      gfx_d
        mov     gfx_r0_r, x0
        mov     x0, gfx_y_r
        bl      gfx_d
        mov     gfx_r1_r, x0
        add     x0, gfx_y_r, SIM_GAP_H
        bl      gfx_d
        mov     gfx_r2_r, x0
        add     x0, gfx_y_r, SIM_GAP_H
        add     x0, x0, SIM_PIPE_CAP_H
        bl      gfx_d
        mov     gfx_r3_r, x0
        // upper body, with a zero source stride so every row repeats the one body row
        mov     x0, gfx_buf_r
        ldr     x1, =gfx_body
        mov     x2, 0
        mov     x3, gfx_bx_r
        ldr     x4, =gfx_bodyw
        ldr     x4, [x4]
        mov     x5, 0
        mov     x6, gfx_r0_r
        bl      gfx_pipe_rows
        mov     x0, gfx_buf_r
        ldr     x1, =gfx_cap
        ldr     x2, =gfx_capw
        ldr     x2, [x2]
        mov     x3, gfx_cx_r
        mov     x4, x2
        mov     x5, gfx_r0_r
        mov     x6, gfx_r1_r
        bl      gfx_pipe_rows
        mov     x0, gfx_buf_r
        ldr     x1, =gfx_cap
        ldr     x2, =gfx_capw
        ldr     x2, [x2]
        mov     x3, gfx_cx_r
        mov     x4, x2
        mov     x5, gfx_r2_r
        mov     x6, gfx_r3_r
        bl      gfx_pipe_rows
        mov     x0, gfx_buf_r
        ldr     x1, =gfx_body
        mov     x2, 0
        mov     x3, gfx_bx_r
        ldr     x4, =gfx_bodyw
        ldr     x4, [x4]
        mov     x5, gfx_r3_r
        ldr     x6, =gfx_groundy
        ldr     x6, [x6]
        bl      gfx_pipe_rows
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldp     x25, x26, [sp, 64]
        ldr     gfx_bx_r, [sp, 80]
        ldp     fp, lr, [sp], gfx_pipe_dealloc
        ret

// gfx_score(x0 = back, x1 = value): outlined digits centred near the top
gfx_score_alloc = -(16 + 48) & -16
gfx_score_dealloc = 0 - gfx_score_alloc
        .balign 4
gfx_score:
        stp     fp, lr, [sp, gfx_score_alloc]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        mov     gfx_buf_r, x0
        ldr     x9, =gfx_nums
        mov     x10, 0
        mov     x11, 10
gfx_score_split:
        udiv    x12, x1, x11
        msub    x13, x12, x11, x1
        strb    w13, [x9, x10]
        add     x10, x10, 1
        mov     x1, x12
        cbnz    x1, gfx_score_split
        mov     gfx_cnt_r, x10
        ldr     x9, =gfx_digadv
        ldr     gfx_dadv_r, [x9]
        ldr     x9, =gfx_digw
        ldr     gfx_dw_r, [x9]
        sub     x9, gfx_cnt_r, 1
        madd    x9, x9, gfx_dadv_r, gfx_dw_r
        ldr     x10, =gfx_dw
        ldr     x10, [x10]
        sub     x10, x10, x9
        asr     gfx_px_r, x10, 1
        mov     x0, GFX_SCORE_Y
        bl      gfx_d
        mov     gfx_py_r, x0
gfx_score_digit:
        sub     gfx_cnt_r, gfx_cnt_r, 1
        ldr     x9, =gfx_nums
        ldrb    w10, [x9, gfx_cnt_r]
        ldr     x1, =gfx_digit
        mov     x9, GFX_DIGIT_BYTES
        madd    x1, x10, x9, x1
        mov     x0, gfx_buf_r
        mov     x2, gfx_dw_r
        ldr     x3, =gfx_digh
        ldr     x3, [x3]
        mov     x4, gfx_px_r
        mov     x5, gfx_py_r
        bl      gfx_blit
        add     gfx_px_r, gfx_px_r, gfx_dadv_r
        cbnz    gfx_cnt_r, gfx_score_digit
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
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
        mov     gfx_fa_r, 0
gfx_frame_pipe:
        ldr     x9, =sim_s
        add     x9, x9, SIM_PIPEX
        add     x9, x9, gfx_fa_r, lsl 4
        ldr     x1, [x9]
        ldr     x2, [x9, 8]
        cmp     x1, LOG_W
        b.ge    gfx_frame_pnext
        cmn     x1, SIM_PIPE_CAP_W
        b.lt    gfx_frame_pnext
        mov     x0, gfx_buf_r
        bl      gfx_pipe
gfx_frame_pnext:
        add     gfx_fa_r, gfx_fa_r, 1
        cmp     gfx_fa_r, SIM_PIPES
        b.lt    gfx_frame_pipe
        ldr     x9, =sim_s
        ldr     x0, [x9, SIM_GROUNDX]
        bl      gfx_d
        ldr     gfx_fb_r, =gfx_ground
        add     gfx_fb_r, gfx_fb_r, x0
        ldr     x9, =gfx_groundy
        ldr     gfx_fc_r, [x9]
        ldr     x9, =gfx_dh
        ldr     gfx_fd_r, [x9]
        ldr     x9, =gfx_stride
        ldr     gfx_fe_r, [x9]
gfx_frame_ground:
        madd    x0, gfx_fc_r, gfx_fe_r, gfx_buf_r
        mov     x1, gfx_fb_r
        mov     x2, gfx_fe_r
        bl      gfx_span
        ldr     x9, =gfx_gstride
        ldr     x9, [x9]
        add     gfx_fb_r, gfx_fb_r, x9
        add     gfx_fc_r, gfx_fc_r, 1
        cmp     gfx_fc_r, gfx_fd_r
        b.lt    gfx_frame_ground
        ldr     x9, =sim_s
        ldr     x10, [x9, SIM_STATE]
        ldr     x11, [x9, SIM_Y]
        mov     gfx_fa_r, SIM_BIRD_X
        mov     x12, 0
        cmp     x10, SIM_READY
        b.gt    gfx_frame_late
        ldr     x13, [x9, SIM_BOB]
        add     x11, x11, x13
        cbnz    x10, gfx_frame_bird
        mov     gfx_fa_r, SIM_TITLE_X
        b       gfx_frame_bird
gfx_frame_late:
        ldr     x12, [x9, SIM_TILT]
        cmp     x10, SIM_FADE
        b.ne    gfx_frame_bird
        // a fade from the title has no pipe on the field yet
        ldr     x13, [x9, SIM_PIPEX]
        cmp     x13, SIM_PIPE_NONE
        b.ne    gfx_frame_bird
        mov     gfx_fa_r, SIM_TITLE_X
        mov     x12, 0
gfx_frame_bird:
        // half a step added first, so the division picks the nearest baked angle
        mov     x13, SIM_TILT_DRAW_MAX
        cmp     x12, x13
        csel    x12, x12, x13, le
        sub     x12, x13, x12
        add     x12, x12, GFX_ANGLE_ROUND
        mov     x13, GFX_STEP_RECIP
        mul     x12, x12, x13
        lsr     x12, x12, 16
        mov     x13, GFX_ANGLE_LAST
        cmp     x12, x13
        csel    gfx_fc_r, x12, x13, le
        ldr     x13, [x9, SIM_WING]
        ldr     x14, =sim_wingframe
        ldrb    gfx_fd32_r, [x14, x13]
        asr     gfx_fb_r, x11, 8
        mov     x0, gfx_fa_r
        bl      gfx_d
        ldr     x9, =gfx_rotox
        ldr     x9, [x9]
        sub     gfx_fa_r, x0, x9
        mov     x0, gfx_fb_r
        bl      gfx_d
        ldr     x9, =gfx_rotoy
        ldr     x9, [x9]
        sub     gfx_fb_r, x0, x9
        ldr     x9, =gfx_box
        ldr     x2, [x9]
        mul     x10, x2, x2
        add     x11, gfx_fc_r, gfx_fc_r, lsl 1
        add     x11, x11, gfx_fd_r
        ldr     x1, =gfx_rot
        madd    x1, x11, x10, x1
        mov     x0, gfx_buf_r
        mov     x3, x2
        mov     x4, gfx_fa_r
        mov     x5, gfx_fb_r
        bl      gfx_blit
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
