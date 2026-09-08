# ex09_printlen.s
# Prints a null-terminated string followed by a line break
# Input:  a0 = pointer to the beginning of the string
# Output: a0 = length, excluding the null byte and the line break

.globl main

.data
msg:    .asciz "hello 0 riscv0"    # test value -> prints the string, returns 11

.text
main:
        la      a0, msg
        jal     ra, printlen

        li      a7, 1           # print the returned length
        ecall

        li      a7, 10
        ecall


printlen:
        mv      t0, a0          # walking pointer
        li      t1, 0           # length counter

loop:
        lbu     t2, 0(t0)       # read one character
        beqz    t2, done        # the null byte ends the string

        mv      a0, t2          # print it
        li      a7, 11          # print_char service
        ecall

        addi    t0, t0, 1
        addi    t1, t1, 1
        j       loop

done:
        li      a0, 10          # ASCII line feed
        li      a7, 11
        ecall

        mv      a0, t1          # return the length
        ret