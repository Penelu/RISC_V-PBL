# genius.s - Genius game for the Ripes simulator (PBL02)
#
# Same behaviour as the PBL01 state machine:
#   Siga:     the device adds a random colour every round
#   Mando eu: the player adds the new colour, the device plays the sequence
#             back, then the player repeats it
#   Win:      six short flashes of every lens
#   Lose:     one long flash, on a wrong colour or a 5 s timeout
#   End menu: REPETE plays the last sequence, MAIS LONGO the longest one of
#             the session, PARTIDA starts a new game
#
# I/O tab: LED Matrix 2x2, D-Pad, Switches (8).
#   switches 0-1 = difficulty (0 easy 8, 1 medium 16, 2 hard 32)
#   switch 2     = speed (0 slow 2 s, 1 fast 1 s)
#   switch 3     = mode (0 Siga, 1 Mando eu)
#   switch 4     = PARTIDA     \
#   switch 5     = REPETE       > act on their off -> on edge
#   switch 6     = MAIS LONGO  /
# Restarting the program plays the role of the ON/OFF switch: it clears the
# record kept for MAIS LONGO.
# Run on the single-cycle processor.
#
# Game state lives in saved registers, main never returns:
#   s0 = sequence length    s1 = cursor into the sequence
#   s2 = maximum length     s3 = score
#   s4 = colour pressed     s5 = lamp time in 250 ms steps
#   s6 = mode               s7 = points per round
#   s8 = length of the longest sequence this session

.data
# words first, bytes after: a .word placed after an odd number of bytes would be
# misaligned and lw would fail on it
colors:       .word 0x0000FF00, 0x00FF0000, 0x00FFFF00, 0x000000FF  # green, red, yellow, blue
lfsr_state:   .word 0xACE1          # any non-zero seed

dpad_to_lens: .byte 0, 3, 2, 1      # up, down, left, right -> lens index, clockwise
max_lens:     .byte 8, 16, 32, 32   # difficulty 0..3 -> sequence length
lamp_steps:   .byte 8, 4            # speed 0 slow (2 s), 1 fast (1 s), in 250 ms steps
points:       .byte 1, 2, 3, 3, 2, 4, 6, 6   # (difficulty + 1) x (fast ? 2 : 1)
seq:          .zero 32              # sequence of the running game, one colour per byte
seq_best:     .zero 32              # longest sequence since the program started
msg_score:    .string "Score: "


.text
# ---- OFF / IDLE ---------------------------------------------------------------
main:
        li      s8, 0               # no record yet, the session starts here
        li      a0, 0
        jal     ra, all_lenses      # every lens off
        jal     ra, wait_start      # wait for PARTIDA, LFSR keeps running

new_game:
        li      s0, 0               # empty sequence
        li      s3, 0               # score back to zero

        # capture the configuration at the moment the game starts, so moving
        # a switch mid-game cannot change the rules
        li      t0, SWITCHES_0_BASE
        lw      t1, 0(t0)

        andi    t2, t1, 3           # bits 0-1: difficulty
        la      t3, max_lens
        add     t3, t3, t2
        lbu     s2, 0(t3)           # s2 = maximum sequence length

        srli    t2, t1, 2
        andi    t2, t2, 1           # bit 2: speed
        la      t3, lamp_steps
        add     t3, t3, t2
        lbu     s5, 0(t3)           # s5 = lamp time in 250 ms steps

        srli    t2, t1, 3
        andi    s6, t2, 1           # bit 3: mode, 0 Siga, 1 Mando eu

        andi    t2, t1, 7           # bits 0-2 together: speed x 4 + difficulty
        la      t3, points
        add     t3, t3, t2
        lbu     s7, 0(t3)           # s7 = points earned per round

next_round:
        beqz    s6, add_random      # Siga: the device picks the new colour

# ---- USER_ADD: Mando eu, the player picks the new colour --------------------
        li      a0, 25000           # 5 s timeout, calibrated
        jal     ra, wait_button
        bltz    a0, lose            # too slow to choose
        mv      s4, a0
        jal     ra, echo            # flash the chosen lens
        mv      a0, s4
        j       append

add_random:
        jal     ra, lfsr_step       # a0 = new random colour
append:
        la      t0, seq
        add     t0, t0, s0
        sb      a0, 0(t0)           # append it to the sequence
        addi    s0, s0, 1

        li      a0, 2               # short pause before playing it back
        jal     ra, delay

# ---- SHOW_SEQ / SHOW_GAP ------------------------------------------------------
        la      a0, seq
        mv      a1, s0
        jal     ra, play_seq

# ---- WAIT_INPUT / CHECK -------------------------------------------------------
        li      s1, 0
input_loop:
        li      a0, 25000           # 5 s timeout, calibrated
        jal     ra, wait_button     # a0 = lens pressed, or -1 on timeout
        bltz    a0, lose
        mv      s4, a0
        jal     ra, echo            # flash the pressed lens

        la      t0, seq
        add     t0, t0, s1
        lbu     t1, 0(t0)
        bne     s4, t1, lose        # wrong colour
        addi    s1, s1, 1
        blt     s1, s0, input_loop  # more colours to repeat in this round

        add     s3, s3, s7          # round complete, add its points
        blt     s0, s2, next_round  # sequence not full yet
                                    # otherwise fall through to win

# ---- WIN / LOSE ---------------------------------------------------------------
win:
        li      a0, 6               # six short flashes
        li      a1, 1
        j       end_game
lose:
        li      a0, 1               # one long flash
        li      a1, 4
end_game:
        jal     ra, blink

        # keep the longest sequence of the session for MAIS LONGO
        ble     s0, s8, no_record
        mv      s8, s0
        la      t0, seq
        la      t1, seq_best
        mv      t2, s0
copy_loop:
        lbu     t3, 0(t0)
        sb      t3, 0(t1)
        addi    t0, t0, 1
        addi    t1, t1, 1
        addi    t2, t2, -1
        bnez    t2, copy_loop
no_record:

        la      a0, msg_score       # print "Score: <n>" on the console
        li      a7, 4               # print_string
        ecall
        mv      a0, s3
        li      a7, 1               # print_int
        ecall
        li      a0, 10              # newline
        li      a7, 11              # print_char
        ecall

# ---- END_MENU / REPLAY --------------------------------------------------------
end_menu:
        jal     ra, wait_menu       # a0 = menu switches that just turned on
        andi    t0, a0, 32          # switch 5: REPETE
        bnez    t0, replay_last
        andi    t0, a0, 64          # switch 6: MAIS LONGO
        bnez    t0, replay_best
        j       new_game            # switch 4: PARTIDA

replay_last:
        la      a0, seq
        mv      a1, s0
        jal     ra, play_seq
        j       end_menu

replay_best:
        la      a0, seq_best
        mv      a1, s8
        jal     ra, play_seq
        j       end_menu


# =============================================================================
# Subroutines
# =============================================================================

# play_seq
# Plays a stored sequence on the lenses, at the speed chosen for this game.
# Input: a0 = address of the sequence, a1 = number of colours
play_seq:
        addi    sp, sp, -12
        sw      ra, 8(sp)
        sw      s9, 4(sp)
        sw      s10, 0(sp)
        mv      s9, a0              # walking pointer
        mv      s10, a1             # colours left
        beqz    s10, ps_done        # nothing to play
ps_loop:
        lbu     a0, 0(s9)
        jal     ra, lens_show       # lamp on
        mv      a0, s5              # lamp time from the speed switch
        jal     ra, delay
        li      a0, -1
        jal     ra, lens_show       # lamp off
        li      a0, 1               # 250 ms dark gap, keeps equal colours apart
        jal     ra, delay
        addi    s9, s9, 1
        addi    s10, s10, -1
        bnez    s10, ps_loop
ps_done:
        lw      s10, 0(sp)
        lw      s9, 4(sp)
        lw      ra, 8(sp)
        addi    sp, sp, 12
        ret


# blink
# Flashes all four lenses together, with a 250 ms dark gap after each flash.
# Input: a0 = number of flashes, a1 = on time in 250 ms steps
blink:
        addi    sp, sp, -12
        sw      ra, 8(sp)
        sw      s9, 4(sp)
        sw      s10, 0(sp)
        mv      s9, a0              # flashes left
        mv      s10, a1             # on time
bl_loop:
        li      a0, 1
        jal     ra, all_lenses      # every lens on
        mv      a0, s10
        jal     ra, delay
        li      a0, 0
        jal     ra, all_lenses      # every lens off
        li      a0, 1
        jal     ra, delay
        addi    s9, s9, -1
        bnez    s9, bl_loop
        lw      s10, 0(sp)
        lw      s9, 4(sp)
        lw      ra, 8(sp)
        addi    sp, sp, 12
        ret


# echo
# Flashes one lens for 250 ms, as feedback for a press.
# Input: a0 = lens index 0..3
echo:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        jal     ra, lens_show       # lens on
        li      a0, 1
        jal     ra, delay
        li      a0, -1
        jal     ra, lens_show       # lens off
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret


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


# wait_menu
# Waits until PARTIDA, REPETE or MAIS LONGO goes from off to on.
# The LFSR keeps advancing, so the next game gets a fresh seed.
# Output: a0 = the menu switches that just turned on (bits 4 to 6)
wait_menu:
        addi    sp, sp, -8
        sw      ra, 4(sp)
        sw      s0, 0(sp)
        li      t0, SWITCHES_0_BASE
        lw      s0, 0(t0)           # previous reading
wm_loop:
        jal     ra, lfsr_step
        li      t0, SWITCHES_0_BASE
        lw      t1, 0(t0)
        not     t2, s0              # switches that were off...
        and     t2, t2, t1          # ...and are on now
        andi    a0, t2, 0x70        # keep only the three menu switches
        mv      s0, t1
        beqz    a0, wm_loop
        lw      s0, 0(sp)
        lw      ra, 4(sp)
        addi    sp, sp, 8
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


# all_lenses
# Input: a0 = 0 turns every lens off, anything else lights all four in their colours
all_lenses:
        li      t0, LED_MATRIX_0_BASE
        la      t1, colors
        li      t2, 4
al_loop:
        li      t3, 0
        beqz    a0, al_write
        lw      t3, 0(t1)
al_write:
        sw      t3, 0(t0)
        addi    t0, t0, 4
        addi    t1, t1, 4
        addi    t2, t2, -1
        bnez    t2, al_loop
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
        li      t0, 12500           # iterations per 250 ms step, calibrated
d_step:
        mv      t1, t0
d_spin:
        addi    t1, t1, -1
        bnez    t1, d_spin
        addi    a0, a0, -1
        bnez    a0, d_step
        ret