////////////////////////////////////////////////////////////////////////////////
//
// synchronize module 
//
// NSYNC = number of clock cycle delays; makes sure signals are synchronized;
//      will be equal to the largest delay value     
//
////////////////////////////////////////////////////////////////////////////////

module synchronize #(parameter NSYNC = 8)  // number of sync flops. must be >= 2
                   (input clk,in,
                    output reg out);

  reg [NSYNC-2:0] sync;

  always_ff @ (posedge clk) begin
    {out,sync} <= {sync[NSYNC-2:0],in};
  end
endmodule
