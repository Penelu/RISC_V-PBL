//------------------------------------------------------------------------------
// imem - instruction memory (read only)
//------------------------------------------------------------------------------
// One 32-bit word per instruction, loaded from a .hex file with one word per
// line. Addresses are in bytes, so the two low bits are dropped to get the
// word index.
//------------------------------------------------------------------------------

module imem #(
    parameter MEM_FILE = "",         // full path to the .hex program
    parameter DEPTH    = 1024        // number of 32-bit words
)(
    input  logic [31:0] addr,        // byte address, from the PC
    output logic [31:0] instr
);

    logic [31:0] mem [0:DEPTH-1];

    initial begin
        if (MEM_FILE != "") $readmemh(MEM_FILE, mem);
    end

    assign instr = mem[addr[$clog2(DEPTH)+1:2]];

endmodule
