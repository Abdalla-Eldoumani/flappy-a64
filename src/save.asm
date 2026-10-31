// save_: the binary PPM frame dump, written with openat and write.

define(save_fd_r, w19)
define(save_buf_r, x20)
define(save_stride_r, x21)
define(save_pal_r, x22)
define(save_y_r, x23)
define(save_dw_r, x24)
define(save_dh_r, x25)

SAVE_FLAGS = O_WRONLY + O_CREAT + O_TRUNC
SAVE_MODE = 420

        .bss
        .balign 16
save_row:   .skip   512
save_hdr:   .skip   64

        .text

// save_ppm(x0 = path, x1 = buf, x2 = stride, x3 = palette) -> w0 = 0 written, -1 failed
        .balign 4
        .global save_ppm
save_ppm:
        stp     fp, lr, [sp, -80]!
        mov     fp, sp
        stp     x19, x20, [sp, 16]
        stp     x21, x22, [sp, 32]
        stp     x23, x24, [sp, 48]
        str     x25, [sp, 64]
        mov     save_buf_r, x1
        mov     save_stride_r, x2
        mov     save_pal_r, x3
        mov     x1, x0
        mov     x0, AT_FDCWD
        mov     x2, SAVE_FLAGS
        mov     x3, SAVE_MODE
        mov     x8, SYS_OPENAT
        svc     0
        tbnz    x0, 63, save_ppm_fail
        mov     save_fd_r, w0
        ldr     x9, =gfx_dw
        ldr     save_dw_r, [x9]
        ldr     x9, =gfx_dh
        ldr     save_dh_r, [x9]
        ldr     x1, =save_hdr
        mov     w10, 80
        strb    w10, [x1], 1
        mov     w10, 54
        strb    w10, [x1], 1
        mov     w10, 10
        strb    w10, [x1], 1
        mov     x0, save_dw_r
        bl      main_fmt_dec
        mov     w10, 32
        strb    w10, [x0], 1
        mov     x1, x0
        mov     x0, save_dh_r
        bl      main_fmt_dec
        mov     w10, 10
        strb    w10, [x0], 1
        mov     x1, x0
        mov     x0, 255
        bl      main_fmt_dec
        mov     w10, 10
        strb    w10, [x0], 1
        ldr     x1, =save_hdr
        sub     x2, x0, x1
        mov     w0, save_fd_r
        bl      tty_write_all
        mov     save_y_r, 0
save_ppm_row:
        ldr     x10, =save_row
        mov     x11, 0
save_ppm_px:
        ldrb    w12, [save_buf_r, x11]
        add     x13, save_pal_r, x12, lsl 2
        ldrb    w14, [x13]
        strb    w14, [x10], 1
        ldrb    w14, [x13, 1]
        strb    w14, [x10], 1
        ldrb    w14, [x13, 2]
        strb    w14, [x10], 1
        add     x11, x11, 1
        cmp     x11, save_dw_r
        b.lt    save_ppm_px
        mov     w0, save_fd_r
        ldr     x1, =save_row
        sub     x2, x10, x1
        bl      tty_write_all
        add     save_buf_r, save_buf_r, save_stride_r
        add     save_y_r, save_y_r, 1
        cmp     save_y_r, save_dh_r
        b.lt    save_ppm_row
        mov     w0, save_fd_r
        mov     x8, SYS_CLOSE
        svc     0
        mov     w0, 0
        b       save_ppm_done
save_ppm_fail:
        mov     w0, -1
save_ppm_done:
        ldp     x19, x20, [sp, 16]
        ldp     x21, x22, [sp, 32]
        ldp     x23, x24, [sp, 48]
        ldr     x25, [sp, 64]
        ldp     fp, lr, [sp], 80
        ret
