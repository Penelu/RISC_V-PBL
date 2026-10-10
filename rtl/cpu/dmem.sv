//------------------------------------------------------------------------------
// dmem - data memory
//------------------------------------------------------------------------------
// One 32-bit word per address. Reading is immediate (combinational), so lw
// finishes in the same cycle; writing happens on the clock edge, like the
// register file. Addresses are in bytes, so the two low bits are dropped to
// get the word index. Byte access (lbu, sb) comes in a later stage.
//------------------------------------------------------------------------------

module dmem #(
    parameter DEPTH = 1024           // number of 32-bit words
)(
    input  logic        clk,
    input  logic        we,          // write enable
    input  logic [31:0] addr,        // byte address, from the ALU
    input  logic [31:0] wd,          // write data, from rs2
    output logic [31:0] rd           // read data
);

    logic [31:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we) mem[addr[$clog2(DEPTH)+1:2]] <= wd;
    end

    assign rd = mem[addr[$clog2(DEPTH)+1:2]];

endmodule
