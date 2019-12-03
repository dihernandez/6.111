`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module rgb2hsv_tb;

    // parameters
    // convert 12-bit RGB to 24-bit RGB
    // then convert 24-bit RGB to 24-bit HSV
    parameter RGB_BITWIDTH = 4;
    parameter HSV_BITWIDTH = 4;
    parameter LATENCY = 15;

    // Inputs
    logic clk;
    logic inputs_valid;
    logic [RGB_BITWIDTH-1:0] r, g, b;

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
    parameter LEN = 20; // number of test cases
    logic [RGB_BITWIDTH-1:0] test_rs [LEN-1:0];
    logic [RGB_BITWIDTH-1:0] test_gs [LEN-1:0];
    logic [RGB_BITWIDTH-1:0] test_bs [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_hs [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_ss [LEN-1:0];
    logic [HSV_BITWIDTH-1:0] exp_vs [LEN-1:0];

    initial begin
        // Initialize Inputs
        clk = 0;

        test_rs = {10, 7, 9, 4, 11, 8, 10, 2, 9, 2, 1, 14, 14, 10, 6, 13, 10, 11, 2, 2};
        test_gs = {12, 13, 2, 10, 0, 7, 12, 7, 8, 6, 14, 8, 6, 0, 8, 13, 11, 15, 5, 4};
        test_bs = {8, 13, 10, 10, 14, 6, 12, 4, 4, 13, 0, 14, 9, 8, 4, 4, 7, 3, 0, 8};
        exp_hs = {4, 7, 12, 7, 12, 2, 7, 6, 2, 9, 5, 12, 14, 13, 4, 3, 3, 3, 4, 9};
        exp_ss = {4, 7, 12, 8, 15, 4, 2, 11, 9, 12, 15, 7, 9, 15, 6, 10, 5, 12, 14, 11};
        exp_vs = {12, 13, 10, 10, 14, 8, 12, 7, 9, 13, 14, 14, 14, 10, 8, 13, 11, 15, 5, 8};

        for (i=0; i<LEN; i=i+1) begin
            $display("Test Case ", i);

            // "convert" 12-bit RGB to 24-bit RGB by bit-shifting 4 times
            r = test_rs[i];
            g = test_gs[i];
            b = test_bs[i];
            inputs_valid = 1;
            
            //after one clock cycle, reset valid parameter
            #10;
            inputs_valid = 0;
            
            #(LATENCY*10-10);
            print_error(exp_hs[i], exp_ss[i], exp_vs[i]);
        end
    end
endmodule

/*
# python code to generate N test cases:

def gen(N):     
    test_rs_dec = "test_rs = {" 
    test_gs_dec = "test_gs = {" 
    test_bs_dec = "test_bs = {" 
    exp_hs_dec = "exp_hs = {" 
    exp_ss_dec = "exp_ss = {" 
    exp_vs_dec = "exp_vs = {" 
     
    for i in range(N): 
        r, b, g = np.random.randint(255, size=3) 
        bit4_r = int(np.round((r/255)*15)) 
        bit4_g = int(np.round((g/255)*15)) 
        bit4_b = int(np.round((b/255)*15)) 
        h, s, v = colorsys.rgb_to_hsv(r, g, b) 
        bit4_h = int(np.round(h*15)) 
        bit4_s = int(np.round(s*15)) 
        bit4_v = int(np.round((v/255)*15)) 
         
        test_rs_dec = test_rs_dec + str(bit4_r)
        test_gs_dec = test_gs_dec + str(bit4_g)
        test_bs_dec = test_bs_dec + str(bit4_b)
        exp_hs_dec = exp_hs_dec + str(bit4_h)
        exp_ss_dec = exp_ss_dec + str(bit4_s)
        exp_vs_dec = exp_vs_dec + str(bit4_v)

        if (i<N-1):
            test_rs_dec = test_rs_dec + ", "
            test_gs_dec = test_gs_dec + ", "
            test_bs_dec = test_bs_dec + ", "
            exp_hs_dec = exp_hs_dec + ", "
            exp_ss_dec = exp_ss_dec + ", "
            exp_vs_dec = exp_vs_dec + ", "
     
    test_rs_dec = test_rs_dec + "};" 
    test_gs_dec = test_gs_dec + "};" 
    test_bs_dec = test_bs_dec + "};" 
    exp_hs_dec = exp_hs_dec + "};" 
    exp_ss_dec = exp_ss_dec + "};" 
    exp_vs_dec = exp_vs_dec + "};" 
     
    print(test_rs_dec) 
    print(test_gs_dec) 
    print(test_bs_dec) 
    print(exp_hs_dec) 
    print(exp_ss_dec) 
    print(exp_vs_dec) 
*/
