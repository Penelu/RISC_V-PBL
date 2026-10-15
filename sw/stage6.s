# stage6.s - lui, auipc, lbu, sb
# Assembled by hand into stage6.hex (one 32-bit word per line).
        lui     x1, 0x12345     # 00: 123450b7   x1 = 12345000
        addi    x1, x1, 0x678   # 04: 67808093   x1 = 12345678 (this pair is li x1, 0x12345678)
        lui     x2, 0xfffff     # 08: fffff137   x2 = fffff000
        auipc   x3, 0           # 0c: 00000197   x3 = pc = 0c
        auipc   x4, 1           # 10: 00001217   x4 = pc + 1000 = 1010
        sw      x1, 0(x0)       # 14: 00102023   mem[0] = 12345678
        lbu     x5, 0(x0)       # 18: 00004283   x5 = 78, byte 0 is the low byte
        lbu     x6, 1(x0)       # 1c: 00104303   x6 = 56
        lbu     x7, 3(x0)       # 20: 00304383   x7 = 12
        addi    x8, x0, -1      # 24: fff00413   x8 = ffffffff
        sw      x8, 4(x0)       # 28: 00802223   mem[4] = ffffffff
        sb      x1, 5(x0)       # 2c: 001002a3   mem[4] = ffff78ff, only byte 1 changes
        lbu     x9, 6(x0)       # 30: 00604483   x9 = 000000ff, zero extended
        lw      x10, 4(x0)      # 34: 00402503   x10 = ffff78ff
        sw      x0, 8(x0)       # 38: 00002423   mem[8] = 00000000
        sb      x1, 8(x0)       # 3c: 00100423   mem[8] = 00000078, byte 0
        sb      x8, 11(x0)      # 40: 008005a3   mem[8] = ff000078, byte 3
        jal     x0, 0           # 44: 0000006f   halt: jump to itself forever
