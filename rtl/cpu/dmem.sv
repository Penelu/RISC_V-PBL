//------------------------------------------------------------------------------
// dmem - data memory
//------------------------------------------------------------------------------
// One 32-bit word per address. Reading is immediate (combinational), so a load
// finishes in the same cycle; writing happens on the clock edge, like the
// register file. Addresses are in bytes, so the two low bits are dropped to
// get the word index.
//
// Byte access (lbu, sb): the two low address bits pick one of the four bytes
// of the word. RISC-V is little endian, so byte 0 is bits [7:0].
//------------------------------------------------------------------------------

module dmem #(
    parameter DEPTH = 1024           // number of 32-bit words
)(
    input  logic        clk,
    input  logic        we,          // write enable
    input  logic        byte_en,     // 1: one byte (lbu, sb), 0: whole word
    input  logic [31:0] addr,        // byte address, from the ALU
    input  logic [31:0] wd,          // write data, from rs2
    output logic [31:0] rd           // read data
);

    logic [31:0] mem [0:DEPTH-1];
    logic [31:0] word;               // the whole word at addr
    logic [4:0]  shift;              // where the byte sits inside the word

    assign word  = mem[addr[$clog2(DEPTH)+1:2]];
    assign shift = {addr[1:0], 3'b000};          // byte 0..3 -> bit 0, 8, 16, 24

    always_ff @(posedge clk) begin
        if (we) begin
            if (byte_en) mem[addr[$clog2(DEPTH)+1:2]][shift +: 8] <= wd[7:0];
            else         mem[addr[$clog2(DEPTH)+1:2]]             <= wd;
        end
    end

    // lbu: the selected byte, the other 24 bits are zero
    assign rd = byte_en ? {24'd0, word[shift +: 8]} : word;

endmodule
