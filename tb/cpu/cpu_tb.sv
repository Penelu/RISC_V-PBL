//------------------------------------------------------------------------------
// cpu_tb - processor testbench
//------------------------------------------------------------------------------
// Loads a program, lets it run, then compares registers with expected values.
// For each new stage only two things change: PROGRAM and the list of checks.
//
// Stimulus changes on the falling edge, away from the rising edge the
// processor samples on (the same lesson as in PBL01).
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module cpu_tb;

    // full path, so the simulator finds the file wherever it runs from
    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/stage2.hex";
    localparam int    CYCLES  = 20;          // enough for the whole program

    logic clk   = 1'b0;
    logic reset = 1'b1;
    int   errors = 0;

    always #5 clk = ~clk;                    // 100 MHz

    cpu #(.MEM_FILE(PROGRAM)) dut (
        .clk   (clk),
        .reset (reset)
    );

    // prints one register and compares it with the expected value
    task automatic check(input int r, input logic [31:0] expected);
        logic [31:0] got;
        got = dut.u_regfile.regs[r];
        if (got === expected) begin
            $display("PASS  x%0d = %h", r, got);
        end
        else begin
            $display("FAIL  x%0d = %h, expected %h", r, got, expected);
            errors++;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 1'b0;

        repeat (CYCLES) @(negedge clk);

        // ---- expected results of sw/stage2.s --------------------------------
        check( 1, 32'd12);           // addi
        check( 2, 32'd10);           // addi
        check( 3, 32'd22);           // add   12 + 10
        check( 4, 32'd8);            // and   1100 & 1010
        check( 5, 32'd6);            // xor   1100 ^ 1010
        check( 6, 32'd4);            // andi  1100 & 0110
        check( 7, 32'd9);            // xori  1100 ^ 0101
        check( 8, 32'd3);            // srli  12 >> 2
        check( 9, 32'hFFFFFFFF);     // xori with -1: negative immediate
        check(10, 32'd21);           // add   22 + (-1)

        $display("=== %0d error(s)", errors);
        $finish;
    end

    // prints every instruction as it executes, useful while debugging
    always @(posedge clk) begin
        if (!reset)
            $display("[%0t] pc=%h instr=%h", $time, dut.pc_cur, dut.instr);
    end

endmodule
