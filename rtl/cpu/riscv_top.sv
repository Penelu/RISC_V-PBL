//------------------------------------------------------------------------------
// riscv_top - top level for synthesis: the processor with Genius loaded
//------------------------------------------------------------------------------
// The testbenches pass the program to cpu themselves; synthesis has no
// testbench, so this wrapper gives cpu the Genius program and data. Vivado
// reads $readmemh files during synthesis too.
//
// After changing sw/genius.s, assemble it again before synthesis:
//     python3 sw/rvasm.py sw/genius.s
//------------------------------------------------------------------------------

module riscv_top (
    input  logic       clk,
    input  logic       reset,        // active-high, asynchronous
    input  logic [3:0] dpad,         // bit 0 up, 1 down, 2 left, 3 right
    input  logic [6:0] switches,
    output logic [3:0] leds          // 1: LED lit
);

    cpu #(
        .MEM_FILE  ("/home/gubio/CODESPACE/RISC_V-PBL/sw/genius.hex"),
        .DATA_FILE ("/home/gubio/CODESPACE/RISC_V-PBL/sw/genius_data.hex")
    ) u_cpu (
        .clk      (clk),
        .reset    (reset),
        .dpad     (dpad),
        .switches (switches),
        .leds     (leds)
    );

endmodule
