//------------------------------------------------------------------------------
// tick_gen - timing pulse generator for the Genius game
//------------------------------------------------------------------------------
// One free-running counter, restarted by tick_clr on every state change, plus
// three comparators. Each output is a single-cycle pulse.
//
// CLK_HZ must be overridden in simulation (e.g. 1000) or a single round takes
// hundreds of millions of cycles and the testbench becomes unusable.
//------------------------------------------------------------------------------

module tick_gen #(
    parameter int CLK_HZ = 100_000_000
)(
    input  logic clk,
    input  logic reset,          // active-high, asynchronous

    input  logic tick_clr,       // restarts the counter, from game_fsm
    input  logic cfg_speed,      // 0 = slow (2 s), 1 = fast (1 s)

    output logic show_pulse,     // lamp-on interval elapsed
    output logic gap_pulse,      // dark interval elapsed
    output logic tmo_pulse       // player response limit elapsed
);

    localparam int TMO_CYCLES = 5 * CLK_HZ;          // 5 s response limit
    localparam int CNT_W      = $clog2(TMO_CYCLES + 1);

    logic [CNT_W-1:0] cnt;
    logic [CNT_W-1:0] show_lim;
    logic [CNT_W-1:0] gap_lim;

    // the lamp interval comes from the speed switch, the dark interval is a
    // quarter of it so that two equal colours in a row are still distinguishable
    assign show_lim = cfg_speed ? CNT_W'(CLK_HZ) : CNT_W'(2 * CLK_HZ);
    assign gap_lim  = show_lim >> 2;

    always_ff @(posedge clk or posedge reset) begin
        if (reset)             cnt <= '0;
        else if (tick_clr)     cnt <= '0;
        else if (cnt != '1)    cnt <= cnt + 1'b1;    // saturate, never wrap
    end

    // gap_pulse also fires while the lamp is on, but game_fsm only samples it
    // in SHOW_GAP and REPLAY_GAP, so the early pulse is harmless
    assign show_pulse = (cnt == show_lim);
    assign gap_pulse  = (cnt == gap_lim);
    assign tmo_pulse  = (cnt == CNT_W'(TMO_CYCLES));

endmodule
