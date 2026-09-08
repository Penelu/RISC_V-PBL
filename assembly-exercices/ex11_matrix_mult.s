# ex11_matrix_mult.s
# Multiplies A (m x p) by B (p x n) into C (m x n), row-major order
# Input:  a0 = A, a1 = B, a2 = C, a3 = m, a4 = p, a5 = n
# Output: C holds the product

.globl main

.data
matA:   .word 1, 2, 3, 4                # 2x2
matB:   .word 5, 6, 7, 8                # 2x2
matC:   .space 16                       # 2x2 result -> 19 22 43 50

.text
main:
        la      a0, matA
        la      a1, matB
        la      a2, matC
        li      a3, 2                   # m
        li      a4, 2                   # p
        li      a5, 2                   # n
        jal     ra, matmul

        la      t0, matC                # print the result
        li      t1, 4
print_loop:
        blez    t1, print_done
        lw      a0, 0(t0)
        li      a7, 1
        ecall
        li      a0, 32
        li      a7, 11
        ecall
        addi    t0, t0, 4
        addi    t1, t1, -1
        j       print_loop
print_done:
        li      a7, 10
        ecall


matmul:
        li      t0, 0                   # i = 0

row_loop:
        bge     t0, a3, matmul_done
        li      t1, 0                   # j = 0

col_loop:
        bge     t1, a5, next_row
        li      t2, 0                   # k = 0
        li      t3, 0                   # accumulator

dot_loop:
        bge     t2, a4, store

        mul     t4, t0, a4              # A[i][k] = A + (i*p + k)*4
        add     t4, t4, t2
        slli    t4, t4, 2
        add     t4, t4, a0
        lw      t4, 0(t4)

        mul     t5, t2, a5              # B[k][j] = B + (k*n + j)*4
        add     t5, t5, t1
        slli    t5, t5, 2
        add     t5, t5, a1
        lw      t5, 0(t5)

        mul     t4, t4, t5
        add     t3, t3, t4              # accumulate the dot product

        addi    t2, t2, 1
        j       dot_loop

store:
        mul     t4, t0, a5              # C[i][j] = C + (i*n + j)*4
        add     t4, t4, t1
        slli    t4, t4, 2
        add     t4, t4, a2
        sw      t3, 0(t4)

        addi    t1, t1, 1
        j       col_loop

next_row:
        addi    t0, t0, 1
        j       row_loop

matmul_done:
        ret