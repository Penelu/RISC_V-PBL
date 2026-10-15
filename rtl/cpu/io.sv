//------------------------------------------------------------------------------
// io - memory-mapped peripherals: D-pad, LED matrix 2x2, switches
//------------------------------------------------------------------------------
// The program talks to them with lw and sw, like Ripes does:
//
//   DPAD_BASE     + 0, 4, 8, 12   read:  1 while up, down, left, right is held
//   LED_BASE      + 0, 4, 8, 12   write: colour of LED 0..3 (0 = off)
//   SWITCHES_BASE + 0             read:  bit n = switch n
//
// Buttons and switches change at any moment, not in step with the clock, so
// each one goes through two flip-flops (a synchroniser) before it is used.
// Only whole words are supported: the Genius program uses lw and sw here.
//------------------------------------------------------------------------------

module io
    import cpu_pkg::*;
(
    input  logic        clk,
    input  logic        reset,       // active-high, asynchronous
    input  logic        we,          // write enable
    input  logic [31:0] addr,        // byte address, from the ALU
    input  logic [31:0] wd,          // write data, from rs2
    output logic [31:0] rd,          // read data

    input  logic [3:0]  dpad,        // bit 0 up, 1 down, 2 left, 3 right
    input  logic [6:0]  switches,
    output logic [3:0]  leds         // 1: LED lit (its colour is not 0)
);

    logic [31:0] led_color [0:3];
    logic [3:0]  dpad_meta, dpad_sync;
    logic [6:0]  sw_meta,   sw_sync;

    // which peripheral the address points to (compare everything but the
    // bits that pick the register inside it)
    logic is_dpad, is_led, is_sw;

    assign is_dpad = (addr[31:4] == DPAD_BASE[31:4]);
    assign is_led  = (addr[31:4] == LED_BASE[31:4]);
    assign is_sw   = (addr[31:2] == SWITCHES_BASE[31:2]);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) led_color[i] <= 32'd0;
            dpad_meta <= '0;
            dpad_sync <= '0;
            sw_meta   <= '0;
            sw_sync   <= '0;
        end
        else begin
            dpad_meta <= dpad;
            dpad_sync <= dpad_meta;
            sw_meta   <= switches;
            sw_sync   <= sw_meta;
            if (we && is_led) led_color[addr[3:2]] <= wd;
        end
    end

    always_comb begin
        rd = 32'd0;
        if (is_dpad) rd = {31'd0, dpad_sync[addr[3:2]]};
        if (is_led)  rd = led_color[addr[3:2]];
        if (is_sw)   rd = {25'd0, sw_sync};
    end

    always_comb begin
        for (int i = 0; i < 4; i++) leds[i] = (led_color[i] != 32'd0);
    end

endmodule
