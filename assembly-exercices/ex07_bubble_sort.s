# ex07_bubble_sort.s
# Sorts an array of signed bytes in place using bubble sort
# Input:  a0 = pointer to the array
#         a1 = length of the array
# Output: the array is sorted at the same memory location

.globl main

.data
arr:    .byte 5, -3, 12, 7, -20, 4      # test values
.eqv len, 6

.text
main:
        la      a0, arr
        li      a1, len
        jal     ra, bubble_sort

        la      a0, arr         # print the sorted array
        li      a1, len
        jal     ra, print_array

        li      a7, 10          # exit service
        ecall


bubble_sort:
        addi    t0, a1, -1      # outer counter = n - 1 passes

outer:
        blez    t0, sorted      # nothing left to do
        mv      t1, a0          # t1 = walking pointer, back to the start
        mv      t2, t0          # t2 = comparisons left in this pass

inner:
        blez    t2, next_pass   # this pass is over
        lb      t3, 0(t1)       # left element
        lb      t4, 1(t1)       # right element
        ble     t3, t4, no_swap # already in order
        sb      t4, 0(t1)       # otherwise swap them
        sb      t3, 1(t1)
no_swap:
        addi    t1, t1, 1       # move one byte forward
        addi    t2, t2, -1
        j       inner

next_pass:
        addi    t0, t0, -1      # one less comparison next time around
        j       outer

sorted:
        ret


print_array:
        mv      t0, a0          # pointer
        mv      t1, a1          # counter
        mv      s0, ra          # print_int destroys ra, so save it
print_loop:
        blez    t1, print_done
        lb      a0, 0(t0)
        li      a7, 1           # print_int service
        ecall
        li      a0, 32          # ASCII space
        li      a7, 11          # print_char service
        ecall
        addi    t0, t0, 1
        addi    t1, t1, -1
        j       print_loop
print_done:
        mv      ra, s0
        ret