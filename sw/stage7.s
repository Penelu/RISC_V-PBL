# stage7.s - memory-mapped I/O at the Ripes addresses
# Assembled by hand into stage7.hex (one 32-bit word per line).
# The testbench holds D-pad up + left and switches = 1010011.
        addi    x0, x0, 0       # 00: 00000013   nop: inputs take 2 cycles to cross the synchroniser
        addi    x0, x0, 0       # 04: 00000013   nop
        lui     x1, 0xf0000     # 08: f00000b7   x1 = f0000000, first I/O address (D-pad up)
        lw      x2, 0(x1)       # 0c: 0000a103   x2 = D-pad up
        lw      x3, 4(x1)       # 10: 0040a183   x3 = D-pad down
        lw      x4, 8(x1)       # 14: 0080a203   x4 = D-pad left
        lw      x5, 12(x1)      # 18: 00c0a283   x5 = D-pad right
        lw      x6, 32(x1)      # 1c: 0200a303   x6 = switches (f0000020)
        lui     x7, 0x00ff0     # 20: 00ff03b7   x7 = 00ff0000, red
        addi    x8, x0, 0xff    # 24: 0ff00413   x8 = 000000ff, blue
        sw      x7, 16(x1)      # 28: 0070a823   LED 0 = red  (f0000010)
        sw      x8, 28(x1)      # 2c: 0080ae23   LED 3 = blue (f000001c)
        lw      x9, 16(x1)      # 30: 0100a483   x9 = 00ff0000, LED 0 read back
        sw      x7, 0(x0)       # 34: 00702023   mem[0] = 00ff0000
        sw      x8, 0(x1)       # 38: 0080a023   write to the D-pad: ignored, must not reach mem[0]
        lw      x10, 0(x0)      # 3c: 00002503   x10 = 00ff0000, mem[0] untouched
        jal     x0, 0           # 40: 0000006f   halt: jump to itself forever
