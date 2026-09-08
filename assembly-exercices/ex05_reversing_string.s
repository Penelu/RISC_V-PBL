# ex05_reversing_string.s
# Reverses a null-terminated string in place
# Input:  a0 = pointer to the beginning of the string
# Output: the string is reversed at the same memory location

.globl main

.data
str:    .asciz "assembly"        # test value -> expects "ylbmessa"

.text
main:
        la      a0, str         # load the address of the string
        jal     ra, reverse

        la      a0, str         # print the result
        li      a7, 4           # print_string service
        ecall

        li      a7, 10          # exit service
        ecall


reverse:
        mv      t0, a0          # t0 = left pointer, starts at the beginning

        mv      t1, a0          # t1 = right pointer, walks to the end
find_end:
        lbu     t2, 0(t1)       # read the current character
        beqz    t2, back_off    # stop at the null byte
        addi    t1, t1, 1       # keep going
        j       find_end
back_off:
        addi    t1, t1, -1      # step back onto the last real character

swap_loop:
        bge     t0, t1, done    # stop once the pointers meet or cross
        lbu     t2, 0(t0)       # t2 = left character
        lbu     t3, 0(t1)       # t3 = right character
        sb      t3, 0(t0)       # write them back swapped
        sb      t2, 0(t1)
        addi    t0, t0, 1       # left moves right
        addi    t1, t1, -1      # right moves left
        j       swap_loop

done:
        ret