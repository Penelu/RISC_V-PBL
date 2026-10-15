//------------------------------------------------------------------------------
// game_fsm - Genius game control FSM hardcoded
//------------------------------------------------------------------------------
// Hardcoded state machine covering both game modes:
//   - "Siga"     : the device generates the sequence (cfg_mode = 0)
//   - "Mando eu" : the player generates the sequence (cfg_mode = 1)
//
// The score is kept directly in BCD, so the display driver needs no binary to
// decimal conversion at all.
//------------------------------------------------------------------------------

module game_fsm #(
    parameter int SEQ_MAX = 32
)(
    input  logic        clk,
    input  logic        reset,           // active-high, asynchronous

    // ---- configuration switches -------------------------------------------
    input  logic        power_on,
    input  logic [1:0]  cfg_difficulty,  // 0 = 8 lights, 1 = 16, 2 = 32
    input  logic        cfg_speed,       // 0 = slow, 1 = fast
    input  logic        cfg_mode,        // 0 = Siga, 1 = Mando eu

    // ---- conditioned inputs, one-cycle pulses ------------------------------
    input  logic        btn_start,
    input  logic [3:0]  btn_color,
    input  logic        btn_repeat,
    input  logic        btn_longest,

    // ---- timing, from tick_gen --------------------------------------------
    input  logic        show_pulse,
    input  logic        gap_pulse,
    input  logic        tmo_pulse,
    output logic        tick_clr,

    // ---- colour source and animation handshake -----------------------------
    input  logic [1:0]  rnd_color,
    input  logic        anim_done,
    output logic        anim_win,
    output logic        anim_lose,

    // ---- outputs -----------------------------------------------------------
    output logic [3:0]  led_color,       // one-hot lamp during playback
    output logic [11:0] score_bcd        // {hundreds, tens, units}
);

    // -------------------------------------------------------------------------
    // States
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        OFF, IDLE, SHOW_SEQ, SHOW_GAP, WAIT_INPUT, CHECK,
        USER_ADD, WIN, LOSE, END_MENU, REPLAY, REPLAY_GAP
    } state_t;

    state_t state, next_state;

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    logic [1:0] seq_cur  [SEQ_MAX];     // sequence of the running game
    logic [1:0] seq_best [SEQ_MAX];     // longest sequence since power-on
    logic [5:0] len, best_len, idx;
    logic [1:0] pressed;
    logic       replay_best;            // 0 = REPETE, 1 = MAIS LONGO

    logic [3:0] sc_u, sc_t, sc_h;       // score digits

    logic [1:0] r_diff;                 // configuration captured at start
    logic       r_speed, r_mode;

    assign score_bcd = {sc_h, sc_t, sc_u};

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    logic [5:0] max_len, replay_len;
    logic [3:0] score_inc;
    logic [1:0] btn_enc, replay_color;
    logic       btn_any, wrong, last_of_seq;

    always_comb begin
        case (r_diff)
            2'd0:    max_len = 6'd8;
            2'd1:    max_len = 6'd16;
            default: max_len = 6'd32;
        endcase
    end

    // harder and faster is worth more, as the assignment requires, so it changes the speed of the game
    assign score_inc = (r_diff + 4'd1) * (r_speed ? 4'd2 : 4'd1);

    assign btn_any = |btn_color;

    always_comb begin
        case (btn_color)
            4'b0001: btn_enc = 2'd0;
            4'b0010: btn_enc = 2'd1;
            4'b0100: btn_enc = 2'd2;
            default: btn_enc = 2'd3;
        endcase
    end

    assign wrong        = (pressed != seq_cur[idx]);
    assign last_of_seq  = (idx == len - 1);
    assign replay_len   = replay_best ? best_len      : len;
    assign replay_color = replay_best ? seq_best[idx] : seq_cur[idx];

    // -------------------------------------------------------------------------
    // BCD score increment, one carry per digit
    // -------------------------------------------------------------------------
    logic [4:0] sum_u, sum_t;
    logic [3:0] nxt_u, nxt_t, nxt_h;

    always_comb begin
        sum_u = sc_u + score_inc;
        nxt_u = (sum_u > 5'd9) ? (sum_u - 5'd10) : sum_u[3:0];

        sum_t = sc_t + ((sum_u > 5'd9) ? 5'd1 : 5'd0);
        nxt_t = (sum_t > 5'd9) ? (sum_t - 5'd10) : sum_t[3:0];

        nxt_h = (sum_t > 5'd9) ? ((sc_h == 4'd9) ? 4'd9 : sc_h + 4'd1) : sc_h;
    end

    // -------------------------------------------------------------------------
    // 1. State register
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) state <= OFF;
        else       state <= next_state;
    end

    // -------------------------------------------------------------------------
    // 2. Next state logic
    // -------------------------------------------------------------------------
    always_comb begin
        next_state = state;             // default prevents latches

        case (state)
            OFF:        if (power_on)   next_state = IDLE;

            IDLE:       if (btn_start)  next_state = cfg_mode ? USER_ADD : SHOW_SEQ;

            SHOW_SEQ:   if (show_pulse) next_state = SHOW_GAP;

            SHOW_GAP:   if (gap_pulse)  next_state = last_of_seq ? WAIT_INPUT : SHOW_SEQ;

            WAIT_INPUT: if      (tmo_pulse) next_state = LOSE;
                        else if (btn_any)   next_state = CHECK;

            CHECK:      if      (wrong)          next_state = LOSE;
                        else if (!last_of_seq)   next_state = WAIT_INPUT;
                        else if (len == max_len) next_state = WIN;
                        else                     next_state = r_mode ? USER_ADD : SHOW_SEQ;

            USER_ADD:   if (btn_any)    next_state = SHOW_SEQ;

            WIN, LOSE:  if (anim_done)  next_state = END_MENU;

            END_MENU:   if      (btn_repeat || btn_longest) next_state = REPLAY;
                        else if (btn_start)                 next_state = IDLE;

            REPLAY:     if (show_pulse) next_state = REPLAY_GAP;

            REPLAY_GAP: if (gap_pulse)
                            next_state = (idx == replay_len - 1) ? END_MENU : REPLAY;

            default:    next_state = OFF;
        endcase

        // the power switch overrides every other transition
        if (!power_on) next_state = OFF;
    end

    // -------------------------------------------------------------------------
    // 3. Datapath
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset || !power_on) begin
            len         <= '0;
            best_len    <= '0;
            idx         <= '0;
            pressed     <= '0;
            replay_best <= 1'b0;
            sc_u        <= '0;
            sc_t        <= '0;
            sc_h        <= '0;
        end
        else begin
            case (state)
                IDLE:
                    if (btn_start) begin
                        r_diff  <= cfg_difficulty;
                        r_speed <= cfg_speed;
                        r_mode  <= cfg_mode;
                        idx     <= '0;
                        sc_u    <= '0;
                        sc_t    <= '0;
                        sc_h    <= '0;
                        // select mode
                        if (cfg_mode) begin
                            len <= '0;                  // the player will append
                        end
                        else begin
                            seq_cur[0] <= rnd_color;    // random color is assigned
                            len        <= 6'd1;
                        end
                    end

                SHOW_GAP:
                    if (gap_pulse) idx <= last_of_seq ? 6'd0 : idx + 1'b1;

                WAIT_INPUT:
                    if (btn_any) pressed <= btn_enc;

                CHECK:
                    if (!wrong) begin
                        if (!last_of_seq) begin
                            idx <= idx + 1'b1;
                        end
                        else begin
                            sc_u <= nxt_u;
                            sc_t <= nxt_t;
                            sc_h <= nxt_h;
                            idx  <= '0;
                            if (len != max_len && !r_mode) begin
                                seq_cur[len] <= rnd_color;
                                len          <= len + 1'b1;
                            end
                        end
                    end

                USER_ADD:
                    if (btn_any) begin
                        seq_cur[len] <= btn_enc;
                        len          <= len + 1'b1;
                        idx          <= '0;
                    end

                WIN, LOSE:
                    if (anim_done && len > best_len) begin
                        best_len <= len;
                        seq_best <= seq_cur;
                    end

                END_MENU: begin
                    if (btn_repeat)  begin replay_best <= 1'b0; idx <= '0; end
                    if (btn_longest) begin replay_best <= 1'b1; idx <= '0; end
                end

                REPLAY_GAP:
                    if (gap_pulse)
                        idx <= (idx == replay_len - 1) ? 6'd0 : idx + 1'b1;

                default: ;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 4. Outputs
    // -------------------------------------------------------------------------
    always_comb begin
        case (state)
            SHOW_SEQ: led_color = 4'b0001 << seq_cur[idx];
            REPLAY:   led_color = 4'b0001 << replay_color;
            default:  led_color = 4'b0000;
        endcase
    end

    assign anim_win  = (state == WIN);
    assign anim_lose = (state == LOSE);

    // any state change restarts every counter in tick_gen
    assign tick_clr  = (state != next_state);

endmodule
