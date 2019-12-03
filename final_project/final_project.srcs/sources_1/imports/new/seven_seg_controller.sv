`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/21/2019 10:29:42 PM
// Design Name: 
// Module Name: seven_seg_controller
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module seven_seg_controller(input               clk_in,
                            input               rst_in,
                            input [31:0]        val_in,
                            output logic[7:0]   cat_out,
                            output logic[7:0]   an_out
    );
  
    logic[7:0]      segment_state;      //indicates which segment is on
    logic[31:0]     segment_counter;    //counter for switching segments
    logic [3:0]     routed_vals;        //
    logic [6:0]     led_out;
    
    binary_to_seven_seg my_converter ( .bin_in(routed_vals), .seg_out(led_out));
    assign cat_out = ~led_out;
    assign an_out = ~segment_state;

    //controlls which segment is being lit
    //we want to flit through each of these every ms in order for the segs to work (this is done later)
    always_comb begin
        case(segment_state)
            8'b0000_0001:   	routed_vals = val_in[3:0];		//0th seg
            8'b0000_0010:   	routed_vals = val_in[7:4];		//1st seg
            8'b0000_0100:   	routed_vals = val_in[11:8];		//2nd seg
            8'b0000_1000:   	routed_vals = val_in[15:12];	//3rd seg
            8'b0001_0000:   	routed_vals = val_in[19:16];	//4th seg
            8'b0010_0000:   	routed_vals = val_in[23:20];	//5th seg
            8'b0100_0000:   	routed_vals = val_in[27:24];	//6th seg
            8'b1000_0000:   	routed_vals = val_in[31:28];	//7th seg
            default:        	routed_vals = val_in[3:0];       
        endcase
    end
    
	//here is where we control the flitting
    always_ff @(posedge clk_in)begin
        if (rst_in)begin
            segment_state <= 8'b0000_0001; //changed from 8'b0000_0001 => 8'b1111_1111
            segment_counter <= 32'b0;
        end else begin
            if (segment_counter == 32'd100_000)begin        //if 1 ms has passed
                segment_counter <= 32'd0;                   //reset the segment counter
                segment_state <= {segment_state[6:0],segment_state[7]}; //move to the next segment
            end else begin
                segment_counter <= segment_counter + 1;     //otherwise, keep counting
            end
        end
    end
        
endmodule //seven_seg_controller


//feel free to either include binary_to_seven_seg module here or in its own file!
module binary_to_seven_seg( 
    input [3:0]         bin_in,
    output logic [6:0]  seg_out
);

    //takes an 4 bit binary input and assigns the corresponding LED output for the cathodes
    //this is the output for any 7 segment
    always_comb begin
        case (bin_in)
            4'b0000 : seg_out = 7'b0111111;     //"0"
            4'b0001 : seg_out = 7'b0000110;     //"1"
            4'b0010 : seg_out = 7'b1011011;     //"2"
            4'b0011 : seg_out = 7'b1001111;     //"3"
            4'b0100 : seg_out = 7'b1100110;     //"4"
            4'b0101 : seg_out = 7'b1101101;     //"5"
            4'b0110 : seg_out = 7'b1111101;     //"6"
            4'b0111 : seg_out = 7'b0000111;     //"7"
            4'b1000 : seg_out = 7'b1111111;     //"8"
            4'b1001 : seg_out = 7'b1101111;     //"9"
            4'b1010 : seg_out = 7'b1110111;     //"A"
            4'b1011 : seg_out = 7'b1111100;     //"b"
            4'b1100 : seg_out = 7'b0111001;     //"C"
            4'b1101 : seg_out = 7'b1011110;     //"d"
            4'b1110 : seg_out = 7'b1111001;     //"E"
            4'b1111 : seg_out = 7'b1110001;     //"F"    
            default: assign seg_out = 7'b1000000;   // "-"
            
        endcase
    end

endmodule //binary_to_seven_seg
