# ex12_jumptables.s
# Translates a car struct into a readable string using two lookup tables
# Input:  a0 = color, a1 = type, a2 = idString (unused)
# Output: prints "A [color] [type]!"

.globl main

.data
buffer:  .space 64
prefix:  .asciz "A "
sep:     .asciz " "
excl:    .asciz "!"

black:   .asciz "black"
blue:    .asciz "blue"
green:   .asciz "green"
red:     .asciz "red"
white:   .asciz "white"

conv:    .asciz "convertible"
super:   .asciz "supercar"
suv:     .asciz "SUV"
mini:    .asciz "minivan"

color_table: .word black, blue, green, red, white
type_table:  .word conv, super, suv, mini

.text
main:
        li      a0, 0          # black
        li      a1, 2          # SUV -> "A black SUV!"
        li      a2, 0
        jal     ra, num_to_string

        li      a7, 10
        ecall


num_to_string:
        addi    sp, sp, -12
        sw      ra, 8(sp)
        sw      s0, 4(sp)
        sw      s1, 0(sp)

        mv      s0, a0          # color index
        mv      s1, a1          # type index

        la      a0, buffer      # a0 tracks the end of the string
        la      a1, prefix
        jal     ra, append

        la      t0, color_table # entry = table + index * 4
        slli    t1, s0, 2
        add     t0, t0, t1
        lw      a1, 0(t0)
        jal     ra, append

        la      a1, sep
        jal     ra, append

        la      t0, type_table
        slli    t1, s1, 2
        add     t0, t0, t1
        lw      a1, 0(t0)
        jal     ra, append

        la      a1, excl
        jal     ra, append

        la      a0, buffer      # print the assembled string
        li      a7, 4
        ecall

        lw      s1, 0(sp)
        lw      s0, 4(sp)
        lw      ra, 8(sp)
        addi    sp, sp, 12
        ret


append:                         # a0 = destination end, a1 = source
        lbu     t2, 0(a1)       # returns the new end in a0
        beqz    t2, append_done
        sb      t2, 0(a0)
        addi    a0, a0, 1
        addi    a1, a1, 1
        j       append
append_done:
        sb      zero, 0(a0)     # keep the buffer null-terminated
        ret