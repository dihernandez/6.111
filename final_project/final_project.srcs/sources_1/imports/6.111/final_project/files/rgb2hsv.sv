`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Kevin Zheng Class of 2012 
//           Dept of Electrical Engineering &  Computer Science
// Modified By: Ray Dedhia
// 
// Create Date:    18:45:01 11/10/2010 
// Design Name: 
// Module Name:    rgb2hsv 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

// TODO: FIX SO THAT TAKES IN 4 BIT R, G, B and OUTPUTS 4 bit R, G, B

module rgb2hsv 
    // parameters
    #(parameter RGB_BITWIDTH = 4,
    parameter DIV_BITWIDTH = 8,
    parameter MAX_RGB = 4'b1111,
    parameter DIV_LATENCY = 10,
    parameter G_ADD = 5,
    parameter B_ADD = 10)
    (input logic clock, 
    input logic rgb_inputs_valid,
    input logic [RGB_BITWIDTH-1:0] r, g, b, 
    output logic [RGB_BITWIDTH-1:0] h, s, v,
    output logic hsv_valid);

    // variables
    logic [RGB_BITWIDTH-1:0] my_r_delay1, my_g_delay1, my_b_delay1;
    logic [RGB_BITWIDTH-1:0] my_r_delay2, my_g_delay2, my_b_delay2;
    logic [RGB_BITWIDTH-1:0] my_r, my_g, my_b;
    logic [RGB_BITWIDTH-1:0] min, max, delta;
    logic [DIV_BITWIDTH-1:0] s_top;
    logic [DIV_BITWIDTH-1:0] s_bottom;
    logic [DIV_BITWIDTH-1:0] h_top;
    logic [DIV_BITWIDTH-1:0] h_bottom;
    logic [DIV_BITWIDTH-1:0] s_quotient;
    logic [DIV_BITWIDTH-1:0] s_remainder;
    logic [DIV_BITWIDTH-1:0] h_quotient;
    logic [DIV_BITWIDTH-1:0] h_remainder;
    logic [RGB_BITWIDTH-1:0] v_delay [DIV_LATENCY+1:0];
    logic [DIV_BITWIDTH+2:0] h_negative;
    logic [DIV_BITWIDTH-1:0] h_add [DIV_LATENCY:0];
    logic [4:0] i;
    logic div_inputs_valid;

    // shifts left every clock cycle; append 1 on valid input;
    // left-most bit will be 1 when output is valid
    logic [DIV_LATENCY+4:0] output_valid_shift_register;
    assign div_inputs_valid = output_valid_shift_register[3];
    assign hsv_valid = output_valid_shift_register[DIV_LATENCY+4];

    // Clocks 1-4: calculate numerators and denominators
    // Clocks 4-DIV_LATENCY+4: perform all the divisions (dividers have latency 10)
    // Clock DIV_LATENCY+4: compute final hue value
    // Clock DIV_LATENCY+5: hsv output valid

    logic [DIV_BITWIDTH*2-1:0] s_quotient_and_remainder;
    logic sat_div_out_valid;
    assign s_quotient = s_quotient_and_remainder[DIV_BITWIDTH*2-1:DIV_BITWIDTH];
    sat_div sat_div_unit (
            .aclk(clock),
            .s_axis_divisor_tdata(s_bottom),
            .s_axis_divisor_tvalid(div_inputs_valid),
            .s_axis_dividend_tdata(s_top),
            .s_axis_dividend_tvalid(div_inputs_valid),
            .m_axis_dout_tdata(s_quotient_and_remainder),
            .m_axis_dout_tvalid(sat_div_out_valid)
        );

    logic [DIV_BITWIDTH*2-1:0] h_quotient_and_remainder;
    logic hue_div_out_valid;
    assign h_quotient = h_quotient_and_remainder[DIV_BITWIDTH*2-1:DIV_BITWIDTH];
    hue_div hue_div_unit (
            .aclk(clock),
            .s_axis_divisor_tdata(h_bottom),
            .s_axis_divisor_tvalid(div_inputs_valid),
            .s_axis_dividend_tdata(h_top),
            .s_axis_dividend_tvalid(div_inputs_valid),
            .m_axis_dout_tdata(h_quotient_and_remainder),
            .m_axis_dout_tvalid(hue_div_out_valid)
        );

    always_ff @(posedge clock) begin
        output_valid_shift_register <= {output_valid_shift_register[DIV_LATENCY+3:0], rgb_inputs_valid};
    
        // Clock 1: latch the inputs (always positive)
        {my_r, my_g, my_b} <= {r, g, b};
        
        // Clock 2: compute min, max
        {my_r_delay1, my_g_delay1, my_b_delay1} <= {my_r, my_g, my_b};
        
        if((my_r >= my_g) && (my_r >= my_b)) //(B,S,S)
            max <= my_r;
        else if((my_g >= my_r) && (my_g >= my_b)) //(S,B,S)
            max <= my_g;
        else    max <= my_b;
        
        if((my_r <= my_g) && (my_r <= my_b)) //(S,B,B)
            min <= my_r;
        else if((my_g <= my_r) && (my_g <= my_b)) //(B,S,B)
            min <= my_g;
        else
            min <= my_b;
            
        // Clock 3: compute the delta
        {my_r_delay2, my_g_delay2, my_b_delay2} <= {my_r_delay1, my_g_delay1, my_b_delay1};
        v_delay[0] <= max;
        delta <= max - min;
        
        // Clock 4: compute the top and bottom of whatever divisions we need to do
        s_top <= MAX_RGB * delta;
        s_bottom <= (v_delay[0]>0)?{4'd0, v_delay[0]}: 'd1;
        
        if(my_r_delay2 == v_delay[0]) begin
            h_top <= (my_g_delay2 >= my_b_delay2)?(my_g_delay2 - my_b_delay2) * MAX_RGB : (my_b_delay2 - my_g_delay2) * MAX_RGB;
            h_negative[0] <= (my_g_delay2 >= my_b_delay2)?0:1;
            h_add[0] <= 'd0;
        end 
        else if(my_g_delay2 == v_delay[0]) begin
            h_top <= (my_b_delay2 >= my_r_delay2)?(my_b_delay2 - my_r_delay2) * MAX_RGB : (my_r_delay2 - my_b_delay2) * MAX_RGB;
            h_negative[0] <= (my_b_delay2 >= my_r_delay2)?0:1;
            h_add[0] <= G_ADD;
        end 
        else if(my_b_delay2 == v_delay[0]) begin
            h_top <= (my_r_delay2 >= my_g_delay2)?(my_r_delay2 - my_g_delay2) * MAX_RGB :(my_g_delay2 - my_r_delay2) * MAX_RGB;
            h_negative[0] <= (my_r_delay2 >= my_g_delay2)?0:1;
            h_add[0] <= B_ADD;
        end
        
        h_bottom <= (delta > 0) ? delta * 'd6 : 'd6;
    
        // delay the v and h_negative signals DIV_LATENCY times
        for(i=1; i<DIV_LATENCY+1; i=i+1) begin
            v_delay[i] <= v_delay[i-1];
            h_negative[i] <= h_negative[i-1];
            h_add[i] <= h_add[i-1];
        end
    
        v_delay[DIV_LATENCY+1] <= v_delay[DIV_LATENCY];
        // Clock DIV_LATENCY+4: compute the final value of h
        // depending on the value of h_negative[DIV_LATENCY], we need to subtract MAX_RGB from it to make it come back around the circle
        if(h_negative[DIV_LATENCY] && (h_quotient > h_add[DIV_LATENCY])) begin
            h <= MAX_RGB - h_quotient[RGB_BITWIDTH-1:0] + h_add[DIV_LATENCY];
        end 
        else if(h_negative[DIV_LATENCY]) begin
            h <= h_add[DIV_LATENCY] - h_quotient[RGB_BITWIDTH-1:0];
        end 
        else begin
            h <= h_quotient[RGB_BITWIDTH-1:0] + h_add[DIV_LATENCY];
        end
        
        // pass out s and v straight
        s <= s_quotient;
        v <= v_delay[DIV_LATENCY+1];
    end
endmodule
