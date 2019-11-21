///////////////////////////////////////////////////////////////
// Engineer:   g.p.hom
// Modified by: rdedhia
// 
// Create Date:    18:18:59 04/21/2013 
// Module Name:    display_8hex 
// Description:  Display 8 hex numbers on 7 segment display
//
// @HEX
//
///////////////////////////////////////////////////////////////

module mod_display_8hex (
    input clk_in,                 // system clock
    input [39:0] data_in,         // 8 hex numbers, msb first
                                  // 5 bits per number (+,-,0-f)
    output reg [6:0] seg_out,     // seven segment display output
    output reg [7:0] strobe_out   // digit strobe
    );

    localparam bits = 13;
     
    reg [bits:0] counter = 0;  // clear on power up
     
    // -, +, 0-f
    wire [6:0] segments[17:0]; // 16 7 bit memorys
    assign segments[0]  = 7'b100_0000;  // inverted logic
    assign segments[1]  = 7'b111_1001;  // gfedcba
    assign segments[2]  = 7'b010_0100;
    assign segments[3]  = 7'b011_0000;
    assign segments[4]  = 7'b001_1001;
    assign segments[5]  = 7'b001_0010;
    assign segments[6]  = 7'b000_0010;
    assign segments[7]  = 7'b111_1000;
    assign segments[8]  = 7'b000_0000;
    assign segments[9]  = 7'b001_1000;
    assign segments[10] = 7'b000_1000; // a
    assign segments[11] = 7'b000_0011; // b
    assign segments[12] = 7'b010_0111; // c
    assign segments[13] = 7'b010_0001; // d
    assign segments[14] = 7'b000_0110; // e
    assign segments[15] = 7'b000_1110; // f
    assign segments[16] = 7'b011_1111; // minus (inverse of 0)
    assign segments[17] = 7'b111_1111; // plus (all off) (inverse of 8)
     
    always_ff @(posedge clk_in) begin
      // Here I am using a counter and select 3 bits which provides
      // a reasonable refresh rate starting the left most digit
      // and moving left.
      counter <= counter + 1;
      case (counter[bits:bits-2])
          3'b000: begin  // use the MSB 5 bits
                  seg_out <= segments[data_in[39:35]];
                  strobe_out <= 8'b0111_1111 ;
                 end

          3'b001: begin
                  seg_out <= segments[data_in[34:30]];
                  strobe_out <= 8'b1011_1111 ;
                 end

          3'b010: begin
                   seg_out <= segments[data_in[29:25]];
                   strobe_out <= 8'b1101_1111 ;
                  end
          3'b011: begin
                  seg_out <= segments[data_in[24:20]];
                  strobe_out <= 8'b1110_1111;        
                 end
          3'b100: begin
                  seg_out <= segments[data_in[19:15]];
                  strobe_out <= 8'b1111_0111;
                 end

          3'b101: begin
                  seg_out <= segments[data_in[14:10]];
                  strobe_out <= 8'b1111_1011;
                 end

          3'b110: begin
                   seg_out <= segments[data_in[9:5]];
                   strobe_out <= 8'b1111_1101;
                  end
          3'b111: begin // LSB 5 bits
                  seg_out <= segments[data_in[4:0]];
                  strobe_out <= 8'b1111_1110;
                 end

       endcase
      end

endmodule

