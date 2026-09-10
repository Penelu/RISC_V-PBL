//------------------------------------------------------------------------------
// genius_top - top level of the Genius prototype (PBL01)
//------------------------------------------------------------------------------
// Scope of this module is RTL and simulation. Two things are deliberately left
// for PBL04, when the design meets a real board:
//
//   - button debouncing.
//   - 7-segment decoding.
//
// CLK_HZ must be overridden in the testbench (e.g. 1000) so a full round takes
// a few thousand cycles instead of a few hundred million.
//------------------------------------------------------------------------------

module genius_top #(
    parameter int CLK_HZ  = 100_000_000,
    parameter int SEQ_MAX = 32
)(
    input  logic        clk,
    input  logic        reset,           // active-high, asynchronous

    // ---- slide switches ----------------------------------------------------
    input  logic        sw_power,        // ON/OFF
    input  logic [1:0]  sw_difficulty,   // 0 = 8 lights, 1 = 16, 2 = 32
    input  logic        sw_speed,        // 0 = slow (2 s), 1 = fast (1 s)
    input  logic        sw_mode,         // 0 = Siga, 1 = Mando eu

    // ---- push buttons ------------------------------------------------------
    input  logic        btn_start,       // START (PARTIDA)
    input  logic [3:0]  btn_color,       // the four lenses
    input  logic        btn_repeat,      // REPEAT (REPETE)
    input  logic        btn_longest,     // LONGEST (MAIS LONGO)

    // ---- outputs -----------------------------------------------------------
    output logic [3:0]  led,             // the four coloured lenses
    output logic        led_start,       // START (PARTIDA) feedback, one second
    output logic [11:0] bcd_score        // {hundreds, tens, units} to the display
);

    // -------------------------------------------------------------------------
    // Edge detection: the FSM consumes one-cycle pulses, not levels
    // -------------------------------------------------------------------------
    logic [3:0] color_d,   color_pulse;
    logic       start_d,   start_pulse;
    logic       repeat_d,  repeat_pulse;
    logic       longest_d, longest_pulse;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            color_d   <= '0;
            start_d   <= 1'b0;
            repeat_d  <= 1'b0;
            longest_d <= 1'b0;
        end
        else begin
            color_d   <= btn_color;
            start_d   <= btn_start;
            repeat_d  <= btn_repeat;
            longest_d <= btn_longest;
        end
    end

    assign color_pulse   = btn_color   & ~color_d;
    assign start_pulse   = btn_start   & ~start_d;
    assign repeat_pulse  = btn_repeat  & ~repeat_d;
    assign longest_pulse = btn_longest & ~longest_d;

    // -------------------------------------------------------------------------
    // Timing and colour source
    // -------------------------------------------------------------------------
    logic       show_pulse, gap_pulse, tmo_pulse, tick_clr;
    logic [1:0] rnd_color;

    tick_gen #(.CLK_HZ(CLK_HZ)) u_tick_gen (
        .clk        (clk),
        .reset      (reset),
        .tick_clr   (tick_clr),
        .cfg_speed  (sw_speed),
        .show_pulse (show_pulse),
        .gap_pulse  (gap_pulse),
        .tmo_pulse  (tmo_pulse)
    );

    prng_lfsr u_prng (
        .clk       (clk),
        .reset     (reset),
        .rnd_color (rnd_color)
    );

    // -------------------------------------------------------------------------
    // Game control
    // -------------------------------------------------------------------------
    logic [3:0] led_color;
    logic       anim_win, anim_lose, anim_done;

    game_fsm #(.SEQ_MAX(SEQ_MAX)) u_game_fsm (
        .clk            (clk),
        .reset          (reset),
        .power_on       (sw_power),
        .cfg_difficulty (sw_difficulty),
        .cfg_speed      (sw_speed),
        .cfg_mode       (sw_mode),
        .btn_start      (start_pulse),
        .btn_color      (color_pulse),
        .btn_repeat     (repeat_pulse),
        .btn_longest    (longest_pulse),
        .show_pulse     (show_pulse),
        .gap_pulse      (gap_pulse),
        .tmo_pulse      (tmo_pulse),
        .tick_clr       (tick_clr),
        .rnd_color      (rnd_color),
        .anim_done      (anim_done),
        .anim_win       (anim_win),
        .anim_lose      (anim_lose),
        .led_color      (led_color),
        .score_bcd      (bcd_score)
    );

    // -------------------------------------------------------------------------
    // Lamps, PARTIDA LED and end of game animations
    // -------------------------------------------------------------------------
    led_drivers #(.CLK_HZ(CLK_HZ)) u_led_drivers (
        .clk         (clk),
        .reset       (reset),
        .led_color   (led_color),
        .btn_level   (btn_color),        // lights the lens while it is held
        .start_pulse (start_pulse),
        .anim_win    (anim_win),
        .anim_lose   (anim_lose),
        .led         (led),
        .led_start   (led_start),
        .anim_done   (anim_done)
    );

endmodule
