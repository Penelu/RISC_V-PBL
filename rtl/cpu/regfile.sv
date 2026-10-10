//------------------------------------------------------------------------------
// regfile - the 32 general purpose registers
//------------------------------------------------------------------------------
// Two read ports (combinational) and one write port (on the clock edge).
// Register x0 always reads as zero and ignores writes.
//------------------------------------------------------------------------------

module regfile (
    input  logic        clk,
    input  logic        we,          // write enable
    input  logic [4:0]  ra1,         // read address 1 (rs1)
    input  logic [4:0]  ra2,         // read address 2 (rs2)
    input  logic [4:0]  wa,          // write address (rd)
    input  logic [31:0] wd,          // write data
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clk) begin
        if (we && wa != 5'd0) regs[wa] <= wd;
    end

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];

endmodule
