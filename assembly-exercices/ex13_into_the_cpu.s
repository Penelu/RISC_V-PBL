#######################################################
  # Kite: An architecture simulator for five-stage      #
  # pipeline modeling of RISC-V instruction set         #
  # Developed by William J. Song                        #
  # School of Electrical Engineering, Yonsei University #
  # Version: 1.8                                        #
  #######################################################
  # Kite program code
  #   1. The first instruction starts at PC = 4. PC = 0 is reserved as invalid.
  #   2. To terminate the program, let the next PC naturally go out of range.
  #   3. All the instructions and labels are case-insensitive.
  #   4. The program code supports only the following list of instructions
  #      (sorted by alphabetical order in each type).
  #      R-type: add, and, div, divu, mul, or, rem, remu, sll, sra, srl, sub, xor
  #      I-type: addi, andi, jalr, slli, srai, srli, ld, ori, xori
  #      S-type: sd
  #      SB-type: beq, bge, blt, bne
  #      U-type: lui
  #      UJ-type: jal
  #      No-type: nop
  
  ####################
  ####################
  # This program runs matrix calculation of
  # C = C + A * B, where it is supposed that
  # C = [
  #  -6, 5, -8, 5, 9,
  #  1, 0, -6, 4, -2,
  #  -6, -5, -6, 6, -3,
  # ]
  #
  # A = [
  #  6, 5, 1, 8,
  #  2, 5, 9, -6,
  #  -9, 0, 0, 2
  # ]
  #
  # B = [
  #  2, -8, 1, 3, 7,
  #  5, -5, -5, 2, -7,
  #  -1, -3, 7, -2, 5,
  #  4, -7, -4, 6, 5
  # ]
  # Memory and register are set to work for these values accordingly as well.
  ####################
  ####################
  
  MAIN:
      # MAIN stack
      addi  x2,  x2, -64
      sd    x8,   0(x2)
      addi  x8,  x2,  64
      sd    x1,  -8(x8)
      sd   x10, -16(x8)
      sd   x11, -24(x8)
      sd   x12, -32(x8)
      sd   x13, -40(x8)
      sd   x14, -48(x8)
      sd   x15, -56(x8)
  
      # Address of matrix A = 1600 x11
      # Address of matrix B = 2400 x12
      # Address of matrix C = 3200 x10
      addi x10,  x0, 1600
      slli x10, x10,    1 # x10 = 3200
      addi x11,  x0, 1600 # x11 = 1600
      addi x12,  x0, 1200
      slli x12, x12,    1 # x12 = 2400
  
      # Matrix A = M (rows) * N (cols)
      # Matrix B = N (rows) * K (cols)
      # Matrix C = M (rows) * K (cols)
      # M = 3, N = 4, K = 5
      addi x13,  x0,   3
      addi x14,  x0,   4
      addi x15,  x0,   5
  
      # Call subroutine MMA(C, A, B, M, N, K)
      # C += A * B
      jal   x1, MMA
  
      # Clear MAIN stack
      ld    x1,  -8(x8)
      ld   x10, -16(x8)
      ld   x11, -24(x8)
      ld   x12, -32(x8)
      ld   x13, -40(x8)
      ld   x14, -48(x8)
      ld   x15, -56(x8)
      ld    x8,   0(x2)
      addi  x2,  x2,  64
  
      # End of the program (x1 == 0)
      jalr  x0, 0(x1)
  
  
  ################
  # Equivalent python code
  ################
  
  # i = 0
  # j = 0
  # k = 0
  # c_row = 0;
  # MATRIX_A_WIDTH = 4 # x14
  # MATRIX_A_HEIGHT = 3 # x13
  # MATRIX_B_WIDTH = 5 #x15 
  # 
  # while True:
  #   if k == MATRIX_B_WIDTH * MATRIX_A_HEIGHT:
  #     break
  #   C[k] = C[k] + A[i] * B[j]
  #   # i reaches the rightmost index of the row of A matrix
  #   if i != 0 and (i + 1) % (MATRIX_A_WIDTH) == 0:
  #     k += 1
  #     # handle next row of C
  #     if k % MATRIX_B_WIDTH == 0:
  #       # move i to the next row of matrix A
  #       c_row += 1
  #       i = ((c_row) * MATRIX_A_WIDTH)
  #       # locate j at the first column for a fresh multiplication
  #       j = 0
  #     # handle next element in the same row in C
  #     else:
  #       i = c_row * MATRIX_A_WIDTH
  #       j = k % MATRIX_B_WIDTH
  #   # i hasn't reached the rightmost index of the row of A matrix
  #   else:
  #     i += 1
  #     j += MATRIX_B_WIDTH
  
  # addi x13,  x0,   3
  # addi x14,  x0,   4
  # addi x15,  x0,   5
  # 1600 x11 A
  # 2400 x12 B
  # 3200 x10 C
  # X18–x27: saved registers
  # x5-x7, x28-x31: temp registers
  # Write MMA function that calculates C += A * B.
MMA:
    addi x2, x2, -48
    sd x18, 40(x2)
    sd x19, 32(x2)
    sd x20, 24(x2)
    sd x21, 16(x2)
    sd x22,  8(x2)
    sd x23,  0(x2)

    slli x18, x14, 3        # A row stride = N*8, hoisted out of the loop
    slli x19, x15, 3        # B row stride = K*8, hoisted out of the loop
    add  x5,  x0, x11       # x5 = address of the current row of A
    add  x6,  x0, x10       # x6 = address of the current element of C
    add  x7,  x0, x13       # row counter = M

ROW_LOOP:
    beq  x7, x0, MMA_EXIT
    add  x28, x0, x15       # column counter = K
    add  x29, x0, x12       # address of the current column of B

COL_LOOP:
    beq  x28, x0, NEXT_ROW
    add  x30, x0, x5        # walking pointer into the row of A
    add  x31, x0, x29       # walking pointer down the column of B
    add  x20, x0, x0        # accumulator = 0
    add  x21, x0, x14       # inner counter = N

DOT_LOOP:
    beq  x21, x0, DOT_END
    ld   x22, 0(x30)
    ld   x23, 0(x31)
    addi x30, x30, 8        # independent work, hides the load latency
    add  x31, x31, x19
    mul  x22, x22, x23
    addi x21, x21, -1       # independent work, hides the mul latency
    add  x20, x20, x22
    beq  x0, x0, DOT_LOOP

DOT_END:
    ld   x22, 0(x6)
    addi x28, x28, -1       # independent work, hides the load latency
    add  x22, x22, x20
    sd   x22, 0(x6)
    addi x6, x6, 8          # C walks forward one element
    addi x29, x29, 8        # B moves to the next column
    beq  x0, x0, COL_LOOP

NEXT_ROW:
    add  x5, x5, x18        # A moves to the next row
    addi x7, x7, -1
    beq  x0, x0, ROW_LOOP

MMA_EXIT:
    ld x23,  0(x2)
    ld x22,  8(x2)
    ld x21, 16(x2)
    ld x20, 24(x2)
    ld x19, 32(x2)
    ld x18, 40(x2)
    addi x2, x2, 48

    jalr x0, 0(x1)