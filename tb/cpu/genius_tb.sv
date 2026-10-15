//------------------------------------------------------------------------------
// genius_tb - plays the Genius game on the processor
//------------------------------------------------------------------------------
// The testbench is the player: it watches the LEDs while the game shows the
// sequence, writes the colours down, then presses the matching D-pad arrows.
//
//   game 1  easy, fast, Siga: repeat all 8 rounds -> win (6 flashes), score 16
//   game 2  PARTIDA, then a wrong arrow in round 1 -> lose (1 long flash)
//   menu    REPETE plays game 2 again, MAIS LONGO plays game 1 (the record)
//
// Delays in the program are counted in loop turns, as in Ripes: one 250 ms
// step is 12500 turns of 2 instructions, about 25000 clock cycles here.
//
// Stimulus changes on the falling edge, as in cpu_tb.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module genius_tb;

    localparam string PROGRAM = "/home/gubio/CODESPACE/RISC_V-PBL/sw/genius.hex";
    localparam string DATA    = "/home/gubio/CODESPACE/RISC_V-PBL/sw/genius_data.hex";

    localparam int GAP     = 40_000;      // cycles, longer than one 250 ms step
    localparam int TIMEOUT = 20_000_000;  // cycles, the whole test must end before

    // switches: 0-1 difficulty, 2 speed, 3 mode, 4 PARTIDA, 5 REPETE, 6 MAIS LONGO
    localparam int SW_FAST     = 2;
    localparam int SW_PARTIDA  = 4;
    localparam int SW_REPETE   = 5;
    localparam int SW_LONGO    = 6;

    // the arrow that lights each lens (inverse of dpad_to_lens in genius.s):
    // lens 0 up, lens 1 right, lens 2 left, lens 3 down
    localparam logic [3:0] ARROW [0:3] = '{4'b0001, 4'b1000, 4'b0100, 4'b0010};

    logic       clk      = 1'b0;
    logic       reset    = 1'b1;
    logic [3:0] dpad     = 4'b0000;
    logic [6:0] switches = 7'b0000000;
    logic [3:0] leds;
    int         errors   = 0;

    int seq1 [0:7];                       // sequence of game 1
    int seq2 [0:0];                       // sequence of game 2

    always #5 clk = ~clk;                 // 100 MHz

    cpu #(.MEM_FILE(PROGRAM), .DATA_FILE(DATA)) dut (
        .clk      (clk),
        .reset    (reset),
        .dpad     (dpad),
        .switches (switches),
        .leds     (leds)
    );

    // ---- helpers -------------------------------------------------------------

    task automatic wait_cycles(input int n);
        repeat (n) @(negedge clk);
    endtask

    // waits for one lens to light, returns which one, waits for it to go dark
    task automatic watch_lens(output int lens);
        while (!(leds inside {4'b0001, 4'b0010, 4'b0100, 4'b1000})) @(negedge clk);
        case (leds)
            4'b0001: lens = 0;
            4'b0010: lens = 1;
            4'b0100: lens = 2;
            default: lens = 3;
        endcase
        while (leds != 4'b0000) @(negedge clk);
    endtask

    // holds the arrow of a lens until the game echoes it, then lets go.
    // The game only takes a fresh press: it first waits until every arrow is
    // released, so the press must come after the game is back to waiting.
    task automatic press(input int lens);
        wait_cycles(1000);
        dpad = ARROW[lens];
        while (leds == 4'b0000) @(negedge clk);
        dpad = 4'b0000;
        while (leds != 4'b0000) @(negedge clk);
    endtask

    // waits for n flashes of all four lenses together
    task automatic watch_blink(input int n);
        repeat (n) begin
            while (leds != 4'b1111) @(negedge clk);
            while (leds != 4'b0000) @(negedge clk);
        end
    endtask

    // flips a switch from off to on, as the menu waits for that edge
    task automatic flip_on(input int sw);
        switches[sw] = 1'b0;
        wait_cycles(1000);
        switches[sw] = 1'b1;
    endtask

    task automatic check(input string what, input logic [31:0] got,
                         input logic [31:0] expected);
        if (got === expected) begin
            $display("PASS  %s = %0d", what, got);
        end
        else begin
            $display("FAIL  %s = %0d, expected %0d", what, got, expected);
            errors++;
        end
    endtask

    // ---- the player ----------------------------------------------------------

    initial begin
        int lens;

        switches[SW_FAST] = 1'b1;         // easy, fast, Siga
        wait_cycles(2);
        reset = 1'b0;

        // ---- game 1: win ----------------------------------------------------
        flip_on(SW_PARTIDA);
        for (int round = 1; round <= 8; round++) begin
            for (int i = 0; i < round; i++) begin
                watch_lens(lens);
                if (i < round - 1 && lens != seq1[i]) begin
                    $display("FAIL  round %0d replayed colour %0d as %0d", round, i, lens);
                    errors++;
                end
                seq1[i] = lens;
            end
            wait_cycles(GAP);             // the dark gap after the last colour
            for (int i = 0; i < round; i++) press(seq1[i]);
            $display("[%0t] round %0d done", $time, round);
        end
        watch_blink(6);
        $display("[%0t] game 1 won", $time);
        check("game 1 score (s3)", dut.u_regfile.regs[19], 16);
        check("game 1 length (s0)", dut.u_regfile.regs[8], 8);

        // ---- game 2: lose ---------------------------------------------------
        wait_cycles(GAP);                 // let the game reach the menu
        flip_on(SW_PARTIDA);
        watch_lens(seq2[0]);
        wait_cycles(GAP);
        press((seq2[0] + 1) % 4);         // the wrong colour
        watch_blink(1);
        $display("[%0t] game 2 lost", $time);
        check("game 2 score (s3)", dut.u_regfile.regs[19], 0);
        check("record (s8)", dut.u_regfile.regs[24], 8);

        // ---- REPETE: plays game 2 again --------------------------------------
        wait_cycles(GAP);
        flip_on(SW_REPETE);
        watch_lens(lens);
        check("REPETE colour", lens, seq2[0]);

        // ---- MAIS LONGO: plays game 1 again ----------------------------------
        wait_cycles(GAP);
        flip_on(SW_LONGO);
        for (int i = 0; i < 8; i++) begin
            watch_lens(lens);
            check($sformatf("MAIS LONGO colour %0d", i), lens, seq1[i]);
        end

        $display("=== %0d error(s)", errors);
        $finish;
    end

    // stops a stuck game instead of running forever
    initial begin
        wait_cycles(TIMEOUT);
        $display("FAIL  timeout: the game got stuck (pc = %h, leds = %b)",
                 dut.pc_cur, leds);
        $display("=== %0d error(s)", errors + 1);
        $finish;
    end

endmodule
