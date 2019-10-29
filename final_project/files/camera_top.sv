`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// camera testing module
//////////////////////////////////////////////////////////////////////////////////

module camera_top_level (   
        input clk_100mhz,
        input [15:0] sw,
        output logic led16_b,
        output logic [15:0] led
    );

    // create 65mhz system clock, happens to match 1024 x 768
    // XVGA timing
    wire clk_65mhz;
    clk_wiz_65mhz clkdivider(.clk_in1(clk_100mhz),
            .clk_out1(clk_65mhz));

    // for debugging
    assign led = sw;

    // timer module
    // declare inputs / outputs
    logic start_timer, counting, expired, one_hz;
    logic [3:0] value, count_out;
    timer timer_uut( 
        // inputs
        .clock(clk_65mhz),
        .start_timer(start_timer),
        .value(value),
        // outputs
        .counting(counting),
        .expired_pulse(expired),
        .one_hz(one_hz),
        .count_out(count_out) 
    );

    // test timer
    logic one_second_pulse;
    assign led16_b = one_second_pulse;

    always_ff @(posedge clk_65mhz) begin
        if (one_hz) one_second_pulse <= !one_second_pulse;
    end

endmodule // top_level

