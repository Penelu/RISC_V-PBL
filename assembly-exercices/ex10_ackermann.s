# ex10_ackermann.s
# Computes the Ackermann function A(m, n) recursively
# Input:  a0 = m, a1 = n
# Output: a0 = A(m, n)

.globl main

.data
msg_m:  .asciz "m = "
msg_n:  .asciz ", n = "
newline: .asciz "\n"

.text
main:
        li      a0, 2           # test values -> prints "m = 2, n = 3", returns 9
        li      a1, 3
        jal     ra, print_inputs

        li      a0, 2
        li      a1, 3
        jal     ra, ackermann

        li      a7, 1           # print the result
        ecall

        li      a7, 10
        ecall


print_inputs:                   # a0 = m, a1 = n
        mv      t0, a0
        mv      t1, a1

        la      a0, msg_m
        li      a7, 4
        ecall
        mv      a0, t0
        li      a7, 1
        ecall

        la      a0, msg_n
        li      a7, 4
        ecall
        mv      a0, t1
        li      a7, 1
        ecall

        la      a0, newline
        li      a7, 4
        ecall
        ret


ackermann:
        addi    sp, sp, -8      # prologue: this function calls itself
        sw      ra, 4(sp)
        sw      s0, 0(sp)

        bnez    a0, m_positive
        addi    a0, a1, 1       # m == 0 -> return n + 1
        j       ack_done

m_positive:
        bnez    a1, both_positive
        addi    a0, a0, -1      # n == 0 -> return A(m - 1, 1)
        li      a1, 1
        jal     ra, ackermann
        j       ack_done

both_positive:
        mv      s0, a0          # keep m across the inner call
        addi    a1, a1, -1
        jal     ra, ackermann   # inner: A(m, n - 1)
        mv      a1, a0          # its result becomes the new n
        addi    a0, s0, -1      # outer: A(m - 1, ...)
        jal     ra, ackermann

ack_done:
        lw      s0, 0(sp)
        lw      ra, 4(sp)
        addi    sp, sp, 8
        ret