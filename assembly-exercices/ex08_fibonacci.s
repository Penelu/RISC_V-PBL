# ex08_fibonacci.s
# Prints the Fibonacci sequence up to the N-th term using a loop
# Input:  a0 = N, the number of terms
# Output: a0 = last term printed, the sequence goes to stdout

.globl main

.text
main:
        li      a0, 10           # test value = 6 -> expects 0 1 1 2 3 5
        jal     ra, fibonacci

        li      a7, 10          # exit service
        ecall


fibonacci:
        addi    sp, sp, -4      # print_int needs ra intact, so save it
        sw      ra, 0(sp)

        mv      t0, a0          # t0 = how many terms are left
        li      t1, 0           # t1 = current term
        li      t2, 1           # t2 = next term

loop:
        blez    t0, done        # stop once every term is printed

        mv      a0, t1          # print the current term
        li      a7, 1
        ecall
        li      a0, 32          # ASCII space
        li      a7, 11
        ecall

        add     t3, t1, t2      # t3 = the term after next
        mv      t1, t2          # slide the window forward
        mv      t2, t3

        addi    t0, t0, -1
        j       loop

done:
        mv      a0, t1          # a0 = the term that follows the last printed
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret