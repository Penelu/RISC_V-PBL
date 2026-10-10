# stage3.s - memory instructions lw and sw
# Assembled by hand into stage3.hex (one 32-bit word per line).
        addi    x1, x0, 42      # 02a00093   x1 = 42
        addi    x2, x0, -7      # ff900113   x2 = -7 = 0xFFFFFFF9
        sw      x1, 0(x0)       # 00102023   mem[0]  = 42
        sw      x2, 4(x0)       # 00202223   mem[4]  = -7
        addi    x3, x0, 16      # 01000193   x3 = 16, base address
        sw      x1, 8(x3)       # 0011a423   mem[24] = 42   base + offset
        sw      x2, -4(x3)      # fe21ae23   mem[12] = -7   negative offset
        lw      x4, 0(x0)       # 00002203   x4 = 42
        lw      x5, 4(x0)       # 00402283   x5 = -7
        lw      x6, 8(x3)       # 0081a303   x6 = 42
        lw      x7, -4(x3)      # ffc1a383   x7 = -7
        add     x8, x4, x7      # 00720433   x8 = 35, loaded values reach the ALU
        sw      x8, 0(x3)       # 0081a023   mem[16] = 35
        lw      x9, 0(x3)       # 0001a483   x9 = 35, load right after a store
