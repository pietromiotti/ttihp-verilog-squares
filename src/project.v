/*
 * black-and-white squares
 * ui_in[0] = speed     (0=slow, 1=fast)
 * ui_in[1] = direction (0=outward, 1=inward)
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_pmiotti_squares_hypnosis (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // VGA signals
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos),
        .vpos(vpos)
    );

    // Controls
    wire speed     = ui_in[0];
    wire direction = ui_in[1];

    wire signed [10:0] cx = $signed({1'b0, hpos}) - 11'sd320;
    wire signed [10:0] cy = $signed({1'b0, vpos}) - 11'sd240;

    wire [9:0] abs_x = cx[10] ? (~cx[9:0] + 10'd1) : cx[9:0];
    wire [9:0] abs_y = cy[10] ? (~cy[9:0] + 10'd1) : cy[9:0];

    // Square radius = Chebyshev distance
    wire [9:0] square_r = (abs_x > abs_y) ? abs_x : abs_y;

    // Phase accumulator:
    // wraps every 64 steps, which matches the black/white ring period exactly
    reg [5:0] phase;
    wire [5:0] phase_step = speed ? 6'd2 : 6'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 6'd0;
        end else begin
            if (hpos == 10'd0 && vpos == 10'd0) begin
                if (!direction)
                    phase <= phase + phase_step;
                else
                    phase <= phase - phase_step;
            end
        end
    end

    // Animated square bands
    // Each band is 32 pixels wide; bit[5] toggles black/white.
    wire [9:0] anim_r = square_r + {4'b0000, phase};

    // Black/white output only
    wire bw = display_on ? anim_r[5] : 1'b0;

    wire [1:0] r_out = {2{bw}};
    wire [1:0] g_out = {2{bw}};
    wire [1:0] b_out = {2{bw}};

    // VGA output mapping (RGB222 on Tiny VGA PMOD)
    assign uo_out[0] = r_out[1];  // R1
    assign uo_out[4] = r_out[0];  // R0
    assign uo_out[1] = g_out[1];  // G1
    assign uo_out[5] = g_out[0];  // G0
    assign uo_out[2] = b_out[1];  // B1
    assign uo_out[6] = b_out[0];  // B0
    assign uo_out[3] = vsync;     // VSYNC
    assign uo_out[7] = hsync;     // HSYNC

    // Bidirectional pins unused
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Unused inputs
    wire _unused = &{ena, uio_in, ui_in[7:2], square_r[9:6], 1'b0};

endmodule