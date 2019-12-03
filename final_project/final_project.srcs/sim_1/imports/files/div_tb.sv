`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module div_tb;

    // Inputs
    logic clk;
    //logic [23:0] x_num;
    logic [15:0] x_num;
    logic x_num_valid;
    logic [15:0] x_denom;
    logic x_denom_valid;

    // Outputs
    // output of divider is formatted so that first 24 bits
    // are the integer solution and the next 16 bits are the remainder
    //logic [39:0] x_div_and_remainder_out;
    logic [31:0] x_div_and_remainder_out;
    //logic [23:0] x_div_out;
    logic [15:0] x_div_out;
    // extract solution (w/o remainder) from output of ip divider
    //assign x_div_out = x_div_and_remainder_out[39:16];
    assign x_div_out = x_div_and_remainder_out[31:16];
    logic x_div_out_valid;

    // Instantiate the Unit Under Test (UUT)
    //div_gen_x x_div_uut (
    hue_div_2 hue_div_2_uut (
        .aclk(clk),
        .s_axis_divisor_tdata(x_denom),
        .s_axis_divisor_tvalid(x_denom_valid),
        .s_axis_dividend_tdata(x_num),
        .s_axis_dividend_tvalid(x_num_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out),
        .m_axis_dout_tvalid(x_div_out_valid)
    );

    always #5 clk = !clk;
    
    initial begin
        // Initialize Inputs
        clk = 0;
        
        // Test 1
        x_num = 24;
        x_num_valid = 1;
        x_denom = 4;
        x_denom_valid = 1;

        // after one clock cycle, reset tvalid parameters
        #10;
        x_num_valid = 0;
        x_denom_valid = 0;
         
        // wait 25 more clk cycles because the
        // latency of div_gen_x is 26 clk cycles
        //#250;
        #170;
          
        assert (x_div_out == 6) $display("OK. 24/4 = 6"); 
            else $error("Expected 6, got ", x_div_out);
            
        assert (x_div_out_valid == 1) $display("OK. divider output valid.");
            else $error("Expected valid, got ", x_div_out_valid);
            
        // Test 2
        x_num = 200;
        x_num_valid = 1;
        x_denom = 8;
        x_denom_valid = 1;

        // after one clock cycle, reset tvalid parameters
        #10;
        x_num_valid = 0;
        x_denom_valid = 0;
         
        // wait 25 more clk cycles because the
        // latency of div_gen_x is 26 clk cycles
        //#250;
        #170;
          
        assert (x_div_out == 25) $display("OK. 200/8 = 25"); 
            else $error("Expected 25, got ", x_div_out);
            
        assert (x_div_out_valid == 1) $display("OK. divider output valid.");
            else $error("Expected valid, got ", x_div_out_valid);
    end
endmodule

