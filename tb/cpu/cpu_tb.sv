//------------------------------------------------------------------------------
// cpu_tb - processor testbench
//------------------------------------------------------------------------------
// Loads a program, lets it run, then compares registers and data memory with
// expected values.
// For each new stage only two things change: PROGRAM and the list of checks.
//
// Stimulus changes on the falling edge, away from the rising edge the
// processor samples on (the same lesson as in PBL01).
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module cpu_tb;

    // full path, so the simulator finds the file wherever it runs from
    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/stage3.hex";
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

    // same idea for the data memory; addr is in bytes, like in the program
    task automatic check_mem(input int addr, input logic [31:0] expected);
        logic [31:0] got;
        got = dut.u_dmem.mem[addr / 4];
        if (got === expected) begin
            $display("PASS  mem[%0d] = %h", addr, got);
        end
        else begin
            $display("FAIL  mem[%0d] = %h, expected %h", addr, got, expected);
            errors++;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        reset = 1'b0;

        repeat (CYCLES) @(negedge clk);

        // ---- expected results of sw/stage3.s --------------------------------
        check( 1, 32'd42);           // addi
        check( 2, 32'hFFFFFFF9);     // addi  -7
        check( 3, 32'd16);           // addi  base address
        check( 4, 32'd42);           // lw    0(x0)
        check( 5, 32'hFFFFFFF9);     // lw    4(x0)
        check( 6, 32'd42);           // lw    8(x3)
        check( 7, 32'hFFFFFFF9);     // lw   -4(x3): negative offset
        check( 8, 32'd35);           // add   42 + (-7)
        check( 9, 32'd35);           // lw right after sw
        check_mem( 0, 32'd42);       // sw    0(x0)
        check_mem( 4, 32'hFFFFFFF9); // sw    4(x0)
        check_mem(12, 32'hFFFFFFF9); // sw   -4(x3): S immediate, negative
        check_mem(16, 32'd35);       // sw    0(x3)
        check_mem(24, 32'd42);       // sw    8(x3)

        $display("=== %0d error(s)", errors);
        $finish;
    end

    // prints every instruction as it executes, useful while debugging
    always @(posedge clk) begin
        if (!reset)
            $display("[%0t] pc=%h instr=%h", $time, dut.pc_cur, dut.instr);
    end

endmodule
