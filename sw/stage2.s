# stage2.s - arithmetic and logic instructions
# Assembled by hand into stage2.hex (one 32-bit word per line).
        addi    x1, x0, 12      # 00c00093   x1 = 1100
        addi    x2, x0, 10      # 00a00113   x2 = 1010
        add     x3, x1, x2      # 002081b3   x3 = 22
        and     x4, x1, x2      # 0020f233   x4 = 1000 = 8
        xor     x5, x1, x2      # 0020c2b3   x5 = 0110 = 6
        andi    x6, x1, 6       # 0060f313   x6 = 0100 = 4
        xori    x7, x1, 5       # 0050c393   x7 = 1001 = 9
        srli    x8, x1, 2       # 0020d413   x8 = 3
        xori    x9, x0, -1      # fff04493   x9 = 0xFFFFFFFF
        add     x10, x3, x9     # 00918533   x10 = 21
