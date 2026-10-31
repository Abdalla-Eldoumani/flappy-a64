// art_: palettes and, later, the sprites. For now one placeholder palette of flat colours.

        .section .rodata
        .balign 4
// slot -> R, G, B, pad
        .global art_palette
art_palette:
        .byte   18, 22, 30, 0
        .byte   78, 192, 202, 0
        .byte   112, 206, 214, 0
        .byte   222, 214, 150, 0
        .byte   196, 186, 118, 0
        .byte   96, 186, 58, 0
        .byte   112, 190, 48, 0
        .byte   250, 200, 44, 0
        .byte   255, 255, 255, 0
        .byte   36, 36, 40, 0
        .byte   84, 150, 30, 0
        .skip   212
