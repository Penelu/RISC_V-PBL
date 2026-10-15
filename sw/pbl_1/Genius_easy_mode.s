# genius.s - Genius game for the Ripes simulator (PBL02)
#
# First playable version: Siga mode, easy (8 lights), fast speed.
# Difficulty, speed, Mando eu mode and score display come next.
#
# I/O tab: LED Matrix 2x2, D-Pad, Switches (switch 4 = PARTIDA).
# Run on the single-cycle processor.
#
# Game state lives in saved registers, main never returns:
#   s0 = sequence length    s1 = cursor into the sequence
#   s2 = maximum length     s3 = rounds won
#   s4 = colour the player just pressed

.data
colors:       .word 0x0000FF00, 0x00FF0000, 0x00FFFF00, 0x000000FF  # green, red, yellow, blue
dpad_to_lens: .byte 0, 3, 2, 1      # up, down, left, right -> lens index, clockwise
lfsr_state:   .word 0xACE1          # any non-zero seed
seq:          .zero 32             # one colour per byte


.text
main:
game_start:
        li      s0, 0               # empty sequence
        li      s2, 8               # easy: eight lights
        li      s3, 0               # no rounds won yet
        li      a0, -1
        jal     ra, lens_show       # all lenses off
        jal     ra, wait_start      # wait for PARTIDA, LFSR keeps running

next_round:
        jal     ra, lfsr_step       # a0 = new random colour
        la      t0, seq
        add     t0, t0, s0
        sb      a0, 0(t0)           # append it to the sequence
        addi    s0, s0, 1

        li      a0, 2               # short pause before playing it back
        jal     ra, delay

# ---- SHOW_SEQ / SHOW_GAP ------------------------------------------------------
        li      s1, 0
show_loop:
        la      t0, seq
        add     t0, t0, s1
        lbu     a0, 0(t0)
        jal     ra, lens_show       # lamp on
        li      a0, 4               # 1 s, fast speed
        jal     ra, delay
        li      a0, -1
        jal     ra, lens_show       # lamp off
        li      a0, 1               # 250 ms dark gap, keeps equal colours apart
        jal     ra, delay
        addi    s1, s1, 1
        blt     s1, s0, show_loop

# ---- WAIT_INPUT / CHECK -------------------------------------------------------
        li      s1, 0
input_loop:
        li      a0, 25000          # replace with your calibrated 5 s timeout
        jal     ra, wait_button     # a0 = lens pressed, or -1 on timeout
        bltz    a0, lose
        mv      s4, a0

        jal     ra, lens_show       # echo the press on its lens
        li      a0, 1
        jal     ra, delay
        li      a0, -1
        jal     ra, lens_show

        la      t0, seq
        add     t0, t0, s1
        lbu     t1, 0(t0)
        bne     s4, t1, lose        # wrong colour
        addi    s1, s1, 1
        blt     s1, s0, input_loop  # more colours to repeat in this round

        addi    s3, s3, 1           # round complete
        blt     s0, s2, next_round  # sequence not full yet
        j       win

# ---- WIN / LOSE ---------------------------------------------------------------
win:
        li      a0, 0x0000FF00      # every lens green
        j       end_flash
lose:
        li      a0, 0x00FF0000      # every lens red
end_flash:
        jal     ra, fill_all
        li      a0, 8               # 2 s
        jal     ra, delay
        j       game_start


# =============================================================================
# Subroutines
# =============================================================================

# wait_start
# Waits for switch 4 to go from off to on. The LFSR advances on every poll,
# so the moment the player flips the switch becomes the seed.
wait_start:
        addi    sp, sp, -4
        sw      ra, 0(sp)
ws_low:
        jal     ra, lfsr_step
        li      t0, SWITCHES_0_BASE
        lw      t1, 0(t0)
        andi    t1, t1, 16          # bit 4: PARTIDA
        bnez    t1, ws_low          # wait until it is off
ws_high:
        jal     ra, lfsr_step
        li      t0, SWITCHES_0_BASE
        lw      t1, 0(t0)
        andi    t1, t1, 16
        beqz    t1, ws_high         # wait for the off -> on edge
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret


# wait_button
# Waits for a fresh press: first until every arrow is released, then for a press.
# Input:  a0 = polling iterations before giving up
# Output: a0 = lens index 0..3, or -1 on timeout
wait_button:
        addi    sp, sp, -8
        sw      ra, 4(sp)
        sw      s0, 0(sp)
        mv      s0, a0
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


# read_dpad
# Output: a0 = lens index 0..3 of the first arrow found pressed, -1 if none
read_dpad:
        li      t0, D_PAD_0_BASE    # registers in order: up, down, left, right
        li      t2, 0
        li      t4, 4
rd_loop:
        lw      t3, 0(t0)
        bnez    t3, rd_found
        addi    t0, t0, 4
        addi    t2, t2, 1
        blt     t2, t4, rd_loop
        li      a0, -1
        ret
rd_found:
        la      t1, dpad_to_lens
        add     t1, t1, t2
        lbu     a0, 0(t1)
        ret


# lens_show
# Input: a0 = lens index 0..3 to light; any other value turns all lenses off
lens_show:
        li      t0, LED_MATRIX_0_BASE
        la      t1, colors
        li      t2, 0
        li      t4, 4
ls_loop:
        li      t3, 0
        bne     t2, a0, ls_write
        lw      t3, 0(t1)
ls_write:
        sw      t3, 0(t0)
        addi    t0, t0, 4
        addi    t1, t1, 4
        addi    t2, t2, 1
        blt     t2, t4, ls_loop
        ret


# fill_all
# Input: a0 = colour written to all four lenses
fill_all:
        li      t0, LED_MATRIX_0_BASE
        sw      a0, 0(t0)
        sw      a0, 4(t0)
        sw      a0, 8(t0)
        sw      a0, 12(t0)
        ret


# lfsr_step
# Advances the 16-bit Galois LFSR (taps 0xB400) one step.
# Output: a0 = new random colour 0..3
lfsr_step:
        la      t0, lfsr_state
        lw      t1, 0(t0)
        andi    t2, t1, 1
        srli    t1, t1, 1
        beqz    t2, lf_store
        li      t3, 0xB400
        xor     t1, t1, t3
lf_store:
        sw      t1, 0(t0)
        andi    a0, t1, 3
        ret


# delay
# Input: a0 = number of 250 ms steps
delay:
        li      t0, 25000           # replace with your calibrated 250 ms value
d_step:
        mv      t1, t0
d_spin:
        addi    t1, t1, -1
        bnez    t1, d_spin
        addi    a0, a0, -1
        bnez    a0, d_step
        ret