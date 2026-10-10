# stage5.s - jumps jal and jalr
# Assembled by hand into stage5.hex (one 32-bit word per line).
# jal offsets are in bytes, relative to the jal itself.
        addi    x10, x0, 0      # 00: 00000513   x10 counts wrong-path instructions
        jal     x4, 12          # 04: 00c0026f   forward jump to 10, x4 = 08
        addi    x10, x10, 1     # 08: 00150513   must be skipped
        addi    x10, x10, 1     # 0c: 00150513   must be skipped
        jal     x1, 16          # 10: 010000ef   call func at 20, ra = 14
        addi    x5, x0, 9       # 14: 00900293   back from func: x5 = 9
        jal     x0, 16          # 18: 0100006f   plain jump (j) to 28, x0 stays 0
        addi    x10, x10, 1     # 1c: 00150513   must be skipped
        addi    x6, x0, 6       # 20: 00600313   func: x6 = 6
        jalr    x0, 0(x1)       # 24: 00008067   return (ret) to 14
        addi    x7, x0, 0x2f    # 28: 02f00393   x7 = 2f
        jalr    x3, 6(x7)       # 2c: 006381e7   2f + 6 = 35, bit 0 cleared: jump to 34, x3 = 30
        addi    x10, x10, 1     # 30: 00150513   must be skipped
        jal     x0, 12          # 34: 00c0006f   jump to 40
        addi    x8, x0, 8       # 38: 00800413   x8 = 8, reached by the backward jump
        jal     x0, 8           # 3c: 0080006f   jump to 44
        jal     x0, -8          # 40: ff9ff06f   backward jump to 38
        jal     x0, 0           # 44: 0000006f   halt: jump to itself forever
