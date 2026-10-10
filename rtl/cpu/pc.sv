//------------------------------------------------------------------------------
// pc - program counter
//------------------------------------------------------------------------------
// Holds the address of the instruction being executed. On every clock edge it
// takes the address of the next one.
//------------------------------------------------------------------------------

module pc (
    input  logic        clk,
    input  logic        reset,      // active-high, asynchronous
    input  logic [31:0] pc_next,
    output logic [31:0] pc
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) pc <= 32'd0;     // the program starts at address 0
        else       pc <= pc_next;
    end

endmodule
