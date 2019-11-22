`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module rgb2hsv_tb;

    // parameters
    // convert 12-bit RGB to 24-bit RGB
    // then convert 24-bit RGB to 24-bit HSV
    parameter RGB_BITWIDTH = 4;
    parameter DIV_RGB_BITWIDTH = 4;
    parameter HSV_BITWIDTH = 4;
    parameter LATENCY = 15;

    // Inputs
    logic clk;
    logic inputs_valid;
    logic [DIV_RGB_BITWIDTH-1:0] r, g, b;

    // Outputs
    logic hsv_valid;
    logic [HSV_BITWIDTH-1:0] h, s, v;

    // Instantiate the Unit Under Test (UUT)
    rgb2hsv rgb2hsv_uut (
            .clock(clk),
            .rgb_inputs_valid(inputs_valid),
            .r(r), .g(g), .b(b),
            .h(h), .s(s), .v(v),
            .hsv_valid(hsv_valid)
        );

    task print_error (input logic [HSV_BITWIDTH-1:0] exp_h, exp_s, exp_v);
        assert (h==exp_h) $display("OK. h = ", h); 
            else $display("ERROR: Expected h = ", exp_h, ", got h = ", h);
            
        assert (s==exp_s) $display("OK. s = ", s);
            else $display("ERROR: Expected s = ", exp_s, ", got s = ", s);

        assert (v==exp_v) $display("OK. v = ", v);
            else $display("ERROR: Expected v = ", exp_v, ", got v = ", v);

        assert (hsv_valid==1) $display("OK. hsv_valid is 1");
            else $display("ERROR: Expected hsv_valid = ", 1, ", got hsv_valid = ", hsv_valid);
    endtask

    always #5 clk = !clk;
    
    // declare variables
    integer i = 0;
    parameter LEN = 2;
    logic [RGB_BITWIDTH-1:0] test_rs [LEN-1:0];
    logic [RGB_BITWIDTH-1:0] test_gs [LEN-1:0];
    logic [RGB_BITWIDTH-1:0] test_bs [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_hs [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_ss [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_vs [LEN-1:0];

    initial begin
        // Initialize Inputs
        clk = 0;
        test_rs = {15, 0};
        test_gs = {15, 0};
        test_bs = {15, 0};
        exp_hs = {0, 0};
        exp_ss = {0, 0};
        exp_vs = {15, 0};
                
        for (i=0; i<LEN; i=i+1) begin
            // "convert" 12-bit RGB to 24-bit RGB by bit-shifting 4 times
            r = {test_rs[i], 4'd0};
            g = {test_gs[i], 4'd0};
            b = {test_bs[i], 4'd0};
            inputs_valid = 1;
            
            //after one clock cycle, reset valid parameter
            #10;
            inputs_valid = 0;
            
            #(LATENCY*10-10);
            print_error(exp_hs[i], exp_ss[i], exp_vs[i]);
        end
    end
endmodule