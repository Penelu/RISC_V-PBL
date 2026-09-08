# ex04_max_of_array.s
# Finds the largest element in an array of 32-bit signed integers
# Input:  a0 = pointer to the array
#         a1 = length of the array
# Output: a0 = largest element

.globl main

.data
arr:    .word 5, -3, 12, 7, -20, 4     # test values -> expects 12

.text
main:
        la      a0, arr         # load the address of the array
        li      a1, 6           # number of elements
        jal     ra, max_of_arr

        li      a7, 1           # print_int service
        ecall

        li      a7, 10          # exit service
        ecall


max_of_arr:
        lw      t0, 0(a0)       # max = first element
        li      t1, 1           # i = 1, the first one is already taken

loop:
        bge     t1, a1, done    # leave once i reaches the length
        addi    a0, a0, 4       # advance to the next word
        lw      t2, 0(a0)       # load the current element
        ble     t2, t0, skip    # keep the old max if it is still bigger
        mv      t0, t2          # otherwise the current one is the new max
skip:
        addi    t1, t1, 1       # i++
        j       loop

done:
        mv      a0, t0          # return value goes in a0
        ret