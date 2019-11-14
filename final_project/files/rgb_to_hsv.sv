`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// reference: https://stackoverflow.com/questions/3018313/algorithm-to-convert-rgb-to-hsv-and-hsv-to-rgb-in-range-0-255-for-both
// module to convert 12 bit RGB to 12 bit HSV
//////////////////////////////////////////////////////////////////////////////////

// need to make a state machine b/c need to wait 12 clock cycles for result
// of divider (it has a latency of 12 clock cycles)

// TODO: make sure the latency of the dividor is constant

module rgb_to_hsv (
        input clk_in,
        input [11:0] rgb,
        output logic valid,
        output logic [11:0] hsv
    );

    // saturation divider variables
    logic sat_num_valid, sat_denom_valid, sat_out_valid;
    logic [3:0] sat_denom;
    logic [9:0] sat_num;
    logic [9:0] sat_out;
    // create division circuit for calculating saturation
    div_gen_0 div_uut_sat(
            .aclk(clk_in),
            .s_axis_divisor_tdata(sat_denom),
            .s_axis_divisor_tvalid(sat_denom_valid),
            .s_axis_dividend_tdata(sat_num),
            .s_axis_divident_tvalid(sat_num_valid),
            .m_axis_dout_tdata(sat_out),
            .m_axis_dout_tvalid(sat_out_valid)
        );

    // hue divider variables
    logic hue_num_valid, hue_denom_valid, hue_out_valid;
    logic [3:0] hue_denom;
    logic [9:0] hue_num;
    logic [9:0] hue_out;
    // create division circuit for calculating hue
    div_gen_0 div_uut_hue(
            .aclk(clk_in),
            .s_axis_divisor_tdata(hue_denom),
            .s_axis_divisor_tvalid(hue_denom_valid),
            .s_axis_dividend_tdata(hue_num),
            .s_axis_divident_tvalid(hue_num_valid),
            .m_axis_dout_tdata(hue_out),
            .m_axis_dout_tvalid(hue_out_valid)
        );

    // get red, green, blue values from rgb
    logic [3:0] red, green, blue;
    assign red = rgb[11:8];
    assign green = rgb[7:4];
    assign blue = rgb[3:0];

    // calculate rgb_min and rgb_max
    logic [3:0] rgb_min, rgb_max;
    assign rgb_min = red < green ? (red < blue ? red : blue) : (green < blue ? green : blue);
    assign rgb_max = red > green ? (red > blue ? red : blue) : (green > blue ? green : blue);

    // 48-bit buffer to hold previous 12 values of value, each 4 bits long
    logic [47:0] val_buffer; // left-shift 4 bits
    assign val_buffer = {val_buffer[43:0], rgb_max};

    always_comb begin
        // calculate saturation
        if (rgb_max == 0) begin
            sat_num = 0;
            sat_denom = 1;
        end else begin
            sat_num = 255 * (rgb_max - rgb_min);
            sat_denom = rgb_max;
        end

        // calculate hue
        if (rgb_max == 0 || rgb_max == rgb_min) begin
            hue_num = 0;
            hue_denom = 1;
        end else begin
            hue_denom = (rgb_max - rgb_min);
            if (rgb_max == red) begin
                hue_num = 0 + 43 * (green - blue);
            end else if (rgb_max == green) begin
                hue_num = 85 + 43 * (blue - red);
            end else begin
                hue_num = 171 + 43 * (red - green);
            end
        end
    end

    assign hsv = {hue_out, sat_out, val_buffer[11]}; 

endmodule
