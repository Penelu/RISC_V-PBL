//------------------------------------------------------------------------------
// led_drivers - lamps, PARTIDA LED and win/lose animations
//------------------------------------------------------------------------------
// The FSM holds anim_win or anim_lose for the whole animation, so no edge
// detection or busy flag is needed here: the counters simply run while the
// request is high and reset themselves when it drops.
//------------------------------------------------------------------------------

module led_drivers #(
    parameter int CLK_HZ = 100_000_000
)(
    input  logic       clk,
    input  logic       reset,          // active-high, asynchronous

    input  logic [3:0] led_color,      // one-hot lamp, from game_fsm
    input  logic [3:0] btn_level,      // debounced level, lights the pressed lens
    input  logic       start_pulse,
    input  logic       anim_win,
    input  logic       anim_lose,

    output logic [3:0] led,
    output logic       led_start,
    output logic       anim_done
);

    // -------------------------------------------------------------------------
    // PARTIDA LED, one second one-shot
    // -------------------------------------------------------------------------
    localparam int SEC_W = $clog2(CLK_HZ + 1);

    logic [SEC_W-1:0] start_cnt;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)                start_cnt <= '0;
        else if (start_pulse)     start_cnt <= SEC_W'(CLK_HZ);
        else if (start_cnt != '0) start_cnt <= start_cnt - 1'b1;
    end

    assign led_start = (start_cnt != '0);

    // -------------------------------------------------------------------------
    // Animations: a win is six short blinks, a lose is one long blink
    // -------------------------------------------------------------------------
    localparam int STEP       = CLK_HZ / 8;         // an eighth of a second
    localparam int STEP_W     = $clog2(STEP);
    localparam int WIN_STEPS  = 12;
    localparam int LOSE_STEPS = 8;

    logic              anim_req;
    logic [STEP_W-1:0] div;
    logic [4:0]        step, target;

    assign anim_req = anim_win | anim_lose;
    assign target   = anim_win ? 5'(WIN_STEPS) : 5'(LOSE_STEPS);

    always_ff @(posedge clk or posedge reset) begin
        if (reset || !anim_req) begin
            div  <= '0;
            step <= '0;
        end
        else if (div == STEP_W'(STEP - 1)) begin
            div  <= '0;
            step <= step + 1'b1;
        end
        else begin
            div <= div + 1'b1;
        end
    end

    // held until the FSM reacts and drops anim_req, which resets the counters
    assign anim_done = anim_req && (step == target);

    // -------------------------------------------------------------------------
    // Lamps
    // -------------------------------------------------------------------------
    // btn_level is already a steady debounced level, so holding a lens keeps it
    // lit without any pulse stretching
    always_comb begin
        if (anim_req) led = anim_win ? {4{~step[0]}} : 4'b1111;
        else          led = led_color | btn_level;
    end

endmodule
