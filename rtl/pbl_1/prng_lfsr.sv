//------------------------------------------------------------------------------
// prng_lfsr - pseudo random colour source
//------------------------------------------------------------------------------
// 16-bit Galois LFSR, polynomial x^16 + x^14 + x^13 + x^11 + 1, maximal length
// (65535 states). It runs continuously from reset and is never restarted: the
// entropy comes from the unpredictable moment the player presses PARTIDA, so
// stopping it between games would make every game identical.
//
// The assignment forbids storing sequences in advance; generating them at run
// time from this LFSR satisfies that requirement.
//------------------------------------------------------------------------------

module prng_lfsr (
    input  logic       clk,
    input  logic       reset,        // active-high, asynchronous
    output logic [1:0] rnd_color     // two bits, sampled on demand
);

    localparam logic [15:0] TAPS = 16'hB400;
    localparam logic [15:0] SEED = 16'hACE1;   // any non-zero value works

    logic [15:0] lfsr;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) lfsr <= SEED;
        else       lfsr <= lfsr[0] ? ((lfsr >> 1) ^ TAPS) : (lfsr >> 1);
    end

    assign rnd_color = lfsr[1:0];

endmodule
