# ex02_counting_bits.s
# Counts the number of set bits (1s) in a 32-bit integer
# Input:  a0 = number
# Output: a0 = count of bits set to 1

.globl main

.text
main:
        li      a0, 13          # 0b1101, test value -> expects 3
        jal     ra, count_bits

        li      a7, 1           # print_int service
        ecall

        li      a7, 10          # exit service
        ecall


count_bits:
        li      t0, 0           # counter = 0

loop:
        beqz    a0, done        # no bits left, we are finished
        andi    t1, a0, 1       # t1 = least significant bit (0 or 1)
        add     t0, t0, t1      # add it to the counter
        srli    a0, a0, 1       # discard the bit we just counted
        j       loop

done:
        mv      a0, t0          # return value goes in a0
        ret