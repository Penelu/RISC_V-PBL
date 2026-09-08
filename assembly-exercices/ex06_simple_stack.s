# ex06_simple_stack.s
# Minimal stack with push and pop, operating directly on sp
# Input:  a0 = 0 for push, 1 for pop
#         a1 = value to push, when applicable
# Output: a0 = popped value, when applicable

.globl main

.text
main:
        li      a0, 0           # push 42
        li      a1, 42
        jal     ra, stack_op

        li      a0, 0           # push 7
        li      a1, 7
        jal     ra, stack_op

        li      a0, 1           # pop -> expects 7
        jal     ra, stack_op

        li      a7, 1           # print_int service
        ecall

        li      a7, 10          # exit service
        ecall


stack_op:
        bnez    a0, do_pop      # a0 != 0 means pop

do_push:
        addi    sp, sp, -4      # open room for one word
        sw      a1, 0(sp)       # store the value at the top
        ret

do_pop:
        lw      a0, 0(sp)       # read the value at the top
        addi    sp, sp, 4       # release the slot
        ret