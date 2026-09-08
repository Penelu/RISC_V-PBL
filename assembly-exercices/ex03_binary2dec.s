# ex03_binary2dec.s
# Converts a null-terminated binary string into its decimal value
# Input:  a0 = pointer to the binary string
# Output: a0 = decimal value

.globl main

.data
binstr: .asciz "1011"           # test value -> expects 11

.text
main:
        la      a0, binstr      # load the address of the string
        jal     ra, binary2dec

        li      a7, 1           # print_int service
        ecall

        li      a7, 10          # exit service
        ecall


binary2dec:
        li      t0, 0           # result = 0

loop:
        lbu     t1, 0(a0)       # read one character
        beqz    t1, done        # null byte marks the end of the string
        addi    t1, t1, -48     # ASCII '0' is 48, so this gives 0 or 1
        slli    t0, t0, 1       # shift the result one place left
        add     t0, t0, t1      # append the new bit
        addi    a0, a0, 1       # advance to the next character
        j       loop

done:
        mv      a0, t0          # return value goes in a0
        ret