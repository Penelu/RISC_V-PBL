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
    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/stage4.hex";
    localparam int    CYCLES  = 50;          // enough for the whole program

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

        // ---- expected results of sw/stage4.s --------------------------------
        check(10, 32'd0);            // no wrong-path instruction ran
        check(11, 32'd4);            // all 4 right-path instructions ran
        check( 4, 32'd3);            // backward branch looped 3 times
        check( 6, 32'd7);            // fell out of the loop
        if (dut.pc_cur === 32'h70) begin
            $display("PASS  pc = %h (halt)", dut.pc_cur);
        end
        else begin
            $display("FAIL  pc = %h, expected 00000070 (halt)", dut.pc_cur);
            errors++;
        end

        $display("=== %0d error(s)", errors);
        $finish;
    end

    // prints every instruction as it executes, useful while debugging
    always @(posedge clk) begin
        if (!reset)
            $display("[%0t] pc=%h instr=%h", $time, dut.pc_cur, dut.instr);
    end

endmodule
