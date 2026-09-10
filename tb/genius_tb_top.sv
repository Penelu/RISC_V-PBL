//------------------------------------------------------------------------------
// genius_tb_top - testbench for the Genius prototype
//------------------------------------------------------------------------------
// Runs the four scenarios required to validate the FSM, one after the other,
// with a reset in between:
//
//   1. full game won on easy / fast / Siga
//   2. wrong colour on the first element of the sequence
//   3. wrong colour on the last element of the sequence
//   4. no button pressed at all, losing by timeout
//
// CLK_HZ is set to 1000 so one second of game time is a thousand cycles.
//
// All stimulus is applied on the falling edge. The RTL samples on the rising
// edge, so driving an input at that same instant would race with it and the
// edge detector would swallow the pulse.
//
// The testbench peeks at the sequence stored inside the FSM to reply
// correctly. That is legitimate here: the goal is to exercise the state
// machine, not to model a player.
//------------------------------------------------------------------------------

`timescale 1ns/1ps

module genius_tb_top;

    localparam int CLK_HZ = 1000;

    logic        clk = 1'b0;
    logic        reset = 1'b1;
    logic        sw_power = 1'b1;
    logic [1:0]  sw_difficulty = 2'd0;      // easy, 8 lights
    logic        sw_speed = 1'b1;           // fast
    logic        sw_mode = 1'b0;            // Siga
    logic        btn_start = 1'b0;
    logic [3:0]  btn_color = 4'b0000;
    logic        btn_repeat = 1'b0;
    logic        btn_longest = 1'b0;

    logic [3:0]  led;
    logic        led_start;
    logic [11:0] bcd_score;

    int passed = 0;
    int failed = 0;

    always #5 clk = ~clk;                   // 100 MHz

    genius_top #(.CLK_HZ(CLK_HZ)) dut (.*);

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    task automatic do_reset();
        btn_color   = 4'b0000;
        btn_start   = 1'b0;
        btn_repeat  = 1'b0;
        btn_longest = 1'b0;
        reset       = 1'b1;
        repeat (10) @(negedge clk);
        reset = 1'b0;
        repeat (10) @(negedge clk);
    endtask

    task automatic press(input logic [3:0] color);
        @(negedge clk);
        btn_color = color;
        repeat (5) @(negedge clk);
        btn_color = 4'b0000;
        repeat (5) @(negedge clk);
    endtask

    task automatic press_start();
        @(negedge clk);
        btn_start = 1'b1;
        repeat (5) @(negedge clk);
        btn_start = 1'b0;
        repeat (5) @(negedge clk);
    endtask

    // polls on every clock edge instead of using wait(), which would depend on
    // the simulator tracking sensitivity through a hierarchical reference
    task automatic wait_for_state(input string target);
        forever begin
            @(posedge clk);
            if (dut.u_game_fsm.state.name() == target) break;
        end
    endtask

    // the colour stored at position i, as a one-hot button press
    function automatic logic [3:0] right_color(input int i);
        return 4'b0001 << dut.u_game_fsm.seq_cur[i];
    endfunction

    // any colour other than the stored one
    function automatic logic [3:0] wrong_color(input int i);
        return 4'b0001 << ((dut.u_game_fsm.seq_cur[i] + 2'd1) % 4);
    endfunction

    // replies with the whole stored sequence, one colour at a time
    task automatic play_round();
        int n;
        n = dut.u_game_fsm.len;
        for (int i = 0; i < n; i++) press(right_color(i));
    endtask

    task automatic check(input string name, input bit ok);
        if (ok) begin
            passed++;
            $display("[%0t] PASS - %s", $time, name);
        end
        else begin
            failed++;
            $display("[%0t] FAIL - %s", $time, name);
        end
    endtask

    // -------------------------------------------------------------------------
    // Scenario 1: play the whole easy sequence and win
    // -------------------------------------------------------------------------
    task automatic scenario_win();
        $display("--- scenario 1: full game on easy / fast / Siga");
        do_reset();
        sw_difficulty = 2'd0;
        sw_speed      = 1'b1;
        sw_mode       = 1'b0;
        press_start();

        for (int r = 1; r <= 8; r++) begin
            wait_for_state("WAIT_INPUT");
            play_round();
            $display("[%0t]   round %0d done, score = %h", $time, r, bcd_score);
        end

        wait_for_state("WIN");
        check("won after eight rounds", bcd_score == 12'h016);
    endtask

    // -------------------------------------------------------------------------
    // Scenario 2: wrong colour on the very first element
    // -------------------------------------------------------------------------
    task automatic scenario_wrong_first();
        $display("--- scenario 2: wrong colour on the first element");
        do_reset();
        press_start();

        wait_for_state("WAIT_INPUT");
        press(wrong_color(0));

        wait_for_state("LOSE");
        check("lost on the first element, score stayed zero", bcd_score == 12'h000);
    endtask

    // -------------------------------------------------------------------------
    // Scenario 3: first round right, then wrong on the last element
    // -------------------------------------------------------------------------
    task automatic scenario_wrong_last();
        $display("--- scenario 3: wrong colour on the last element");
        do_reset();
        press_start();

        // round 1 played correctly, so the sequence grows to two colours
        wait_for_state("WAIT_INPUT");
        play_round();

        // round 2: first colour right, second one wrong
        wait_for_state("WAIT_INPUT");
        press(right_color(0));
        press(wrong_color(1));

        wait_for_state("LOSE");
        check("lost on the last element, one round scored", bcd_score == 12'h002);
    endtask

    // -------------------------------------------------------------------------
    // Scenario 4: never press anything, lose by timeout
    // -------------------------------------------------------------------------
    task automatic scenario_timeout();
        $display("--- scenario 4: no input at all, losing by timeout");
        do_reset();
        press_start();

        wait_for_state("WAIT_INPUT");
        wait_for_state("LOSE");          // reached without any press
        check("lost by timeout", bcd_score == 12'h000);
    endtask

    // -------------------------------------------------------------------------
    // Run them all
    // -------------------------------------------------------------------------
    initial begin
        scenario_win();
        scenario_wrong_first();
        scenario_wrong_last();
        scenario_timeout();

        $display("=== %0d passed, %0d failed", passed, failed);
        $finish;
    end

    // safety net so a broken run does not hang the simulator
    initial begin
        #200_000_000;
        $display("TIMEOUT - a scenario never reached its expected state");
        $finish;
    end

endmodule