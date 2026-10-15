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
    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/stage7.hex";
    localparam int    CYCLES  = 50;          // enough for the whole program

    logic       clk      = 1'b0;
    logic       reset    = 1'b1;
    logic [3:0] dpad     = 4'b0101;      // up and left held
    logic [6:0] switches = 7'b1010011;
    logic [3:0] leds;
    int         errors   = 0;

    always #5 clk = ~clk;                    // 100 MHz

    cpu #(.MEM_FILE(PROGRAM)) dut (
        .clk      (clk),
        .reset    (reset),
        .dpad     (dpad),
        .switches (switches),
        .leds     (leds)
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

        // ---- expected results of sw/stage7.s --------------------------------
        check( 2, 32'd1);            // D-pad up    held
        check( 3, 32'd0);            // D-pad down  released
        check( 4, 32'd1);            // D-pad left  held
        check( 5, 32'd0);            // D-pad right released
        check( 6, 32'h53);           // switches 1010011
        check( 9, 32'h00FF0000);     // LED 0 colour read back
        check(10, 32'h00FF0000);     // the D-pad write did not reach mem[0]
        check_mem(0, 32'h00FF0000);
        if (leds === 4'b1001) begin
            $display("PASS  leds = %b", leds);
        end
        else begin
            $display("FAIL  leds = %b, expected 1001", leds);
            errors++;
        end
        if (dut.pc_cur === 32'h40) begin
            $display("PASS  pc = %h (halt)", dut.pc_cur);
        end
        else begin
            $display("FAIL  pc = %h, expected 00000040 (halt)", dut.pc_cur);
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
