# D-Pad test: the lens matching the arrow stays lit while the arrow is held.
# I/O tab: LED Matrix 2x2, D-Pad, Switches (5). Run on the single-cycle processor.

.data
colors:       .word 0x0000FF00, 0x00FF0000, 0x00FFFF00, 0x000000FF  # green, red, yellow, blue
dpad_to_lens: .byte 0, 3, 2, 1      # up, down, left, right -> lens index, clockwise

.text
main:
        li      a0, 300000          # timeout, tune until it is about 5 s
        jal     ra, wait_button
        jal     ra, lens_show       # pressed lens, or all off on timeout
        li      a0, 2               # keep it lit for half a second
        jal     ra, delay
        li      a0, -1
        jal     ra, lens_show
        j       main

# read_dpad
# Output: a0 = lens index 0..3 of the first arrow found pressed, -1 if none
read_dpad:
        li      t0, D_PAD_0_BASE    # registers in order: up, down, left, right
        li      t2, 0               # register index
        li      t4, 4
rd_loop:
        lw      t3, 0(t0)
        bnez    t3, rd_found
        addi    t0, t0, 4           # next arrow register
        addi    t2, t2, 1
        blt     t2, t4, rd_loop
        li      a0, -1              # no arrow pressed
        ret
rd_found:
        la      t1, dpad_to_lens
        add     t1, t1, t2
        lbu     a0, 0(t1)           # translate arrow to lens
        ret


# lens_show
# Input: a0 = lens index 0..3 to light; any other value turns all lenses off
lens_show:
        li      t0, LED_MATRIX_0_BASE
        la      t1, colors
        li      t2, 0               # lens being written
        li      t4, 4
ls_loop:
        li      t3, 0               # default: off
        bne     t2, a0, ls_write
        lw      t3, 0(t1)           # this is the lit lens, use its colour
ls_write:
        sw      t3, 0(t0)
        addi    t0, t0, 4
        addi    t1, t1, 4
        addi    t2, t2, 1
        blt     t2, t4, ls_loop
        ret

.data
lfsr_state:   .word 0xACE1          # any non-zero seed


.text
# lfsr_step
# Advances the 16-bit Galois LFSR (taps 0xB400) one step.
# Output: a0 = new random colour 0..3
lfsr_step:
        la      t0, lfsr_state
        lw      t1, 0(t0)
        andi    t2, t1, 1           # bit that falls off
        srli    t1, t1, 1
        beqz    t2, lf_store        # no XOR when that bit was zero
        li      t3, 0xB400
        xor     t1, t1, t3
lf_store:
        sw      t1, 0(t0)
        andi    a0, t1, 3           # two low bits are the colour
        ret


# wait_button
# Waits for a fresh press: first until every arrow is released, then for a press.
# The LFSR advances on every poll, so the player's timing becomes entropy.
# Input:  a0 = polling iterations before giving up (0 = practically forever)
# Output: a0 = lens index 0..3, or -1 on timeout
wait_button:
        addi    sp, sp, -8
        sw      ra, 4(sp)
        sw      s0, 0(sp)
        mv      s0, a0              # iterations left

wb_release:
        jal     ra, lfsr_step
        jal     ra, read_dpad
        bgez    a0, wb_release      # an arrow is still held

wb_press:
        jal     ra, lfsr_step
        jal     ra, read_dpad
        bgez    a0, wb_done         # fresh press found
        addi    s0, s0, -1
        bnez    s0, wb_press
        li      a0, -1              # timed out

wb_done:
        lw      s0, 0(sp)
        lw      ra, 4(sp)
        addi    sp, sp, 8
        ret


# delay
# Input: a0 = number of 250 ms steps
delay:
        li      t0, 25000           # iterations per 250 ms, tune this
d_step:
        mv      t1, t0
d_spin:
        addi    t1, t1, -1
        bnez    t1, d_spin
        addi    a0, a0, -1
        bnez    a0, d_step
        ret

