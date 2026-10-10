# stage4.s - branches beq, bne, blt, bge
# Assembled by hand into stage4.hex (one 32-bit word per line).
# Branch offsets are in bytes, relative to the branch itself.
        addi    x1, x0, 5       # 00: 00500093   x1 = 5
        addi    x2, x0, -3      # 04: ffd00113   x2 = -3 (huge if read as unsigned)
        addi    x3, x0, 5       # 08: 00500193   x3 = 5
        addi    x10, x0, 0      # 0c: 00000513   x10 counts wrong-path instructions
        addi    x11, x0, 0      # 10: 00000593   x11 counts right-path instructions
        beq     x1, x3, 8       # 14: 00308463   taken:     5 == 5
        addi    x10, x10, 1     # 18: 00150513   must be skipped
        bne     x1, x3, 8       # 1c: 00309463   not taken: 5 == 5
        addi    x11, x11, 1     # 20: 00158593   must run
        blt     x2, x1, 8       # 24: 00114463   taken:     -3 < 5
        addi    x10, x10, 1     # 28: 00150513   must be skipped
        blt     x1, x2, 8       # 2c: 0020c463   not taken: 5 < -3 is false (signed!)
        addi    x11, x11, 1     # 30: 00158593   must run
        bge     x1, x2, 8       # 34: 0020d463   taken:     5 >= -3
        addi    x10, x10, 1     # 38: 00150513   must be skipped
        bge     x1, x3, 8       # 3c: 0030d463   taken:     5 >= 5
        addi    x10, x10, 1     # 40: 00150513   must be skipped
        bge     x2, x1, 8       # 44: 00115463   not taken: -3 >= 5
        addi    x11, x11, 1     # 48: 00158593   must run
        bne     x1, x2, 8       # 4c: 00209463   taken:     5 != -3
        addi    x10, x10, 1     # 50: 00150513   must be skipped
        beq     x1, x2, 8       # 54: 00208463   not taken: 5 != -3
        addi    x11, x11, 1     # 58: 00158593   must run
        addi    x4, x0, 0       # 5c: 00000213   x4 = loop counter
        addi    x5, x0, 3       # 60: 00300293   x5 = loop limit
        addi    x4, x4, 1       # 64: 00120213   loop: x4++
        bne     x4, x5, -4      # 68: fe521ee3   back to loop while x4 != 3
        addi    x6, x0, 7       # 6c: 00700313   x6 = 7, after the loop
        beq     x0, x0, 0       # 70: 00000063   halt: branch to itself forever
