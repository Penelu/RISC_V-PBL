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
    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/stage6.hex";
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

        // ---- expected results of sw/stage6.s --------------------------------
        check( 1, 32'h12345678);     // lui + addi (li)
        check( 2, 32'hFFFFF000);     // lui with the top bit set
        check( 3, 32'h0000000C);     // auipc 0: its own pc
        check( 4, 32'h00001010);     // auipc 1: pc + 1000
        check( 5, 32'h00000078);     // lbu byte 0
        check( 6, 32'h00000056);     // lbu byte 1
        check( 7, 32'h00000012);     // lbu byte 3
        check( 9, 32'h000000FF);     // lbu fills with zeros, not with the sign
        check(10, 32'hFFFF78FF);     // lw after sb
        check_mem(0, 32'h12345678);
        check_mem(4, 32'hFFFF78FF);  // sb changed only byte 1
        check_mem(8, 32'hFF000078);  // sb into bytes 0 and 3
        if (dut.pc_cur === 32'h44) begin
            $display("PASS  pc = %h (halt)", dut.pc_cur);
        end
        else begin
            $display("FAIL  pc = %h, expected 00000044 (halt)", dut.pc_cur);
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
