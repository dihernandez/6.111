`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////

module sprite_test;

   // Inputs
   logic clk;
   logic data_in;

   // Outputs
   logic  [7:0] data_out;

   // Instantiate the Unit Under Test (UUT)
   sample uut (
      .clk(clk), 
      .data_in(data_in), 
      .data_out(data_out)
   );

   always #5 clk = !clk;
   
   initial begin
      // Initialize Inputs
      clk = 0;
      data_in = 0;

      // Wait 100 ns for global reset to finish
      #100;
        
      // Add stimulus here

   end
      
endmodule
