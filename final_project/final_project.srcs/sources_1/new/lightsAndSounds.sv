`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2019 05:45:10 PM
// Design Name: 
// Module Name: lightsAndSounds
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:	handles the 7-seg lights response
//					and the sound response
// 
//////////////////////////////////////////////////////////////////////////////////

// controls the hit points logic and player feedback
module HP(
    input clk,  reset_in,	//I can't remember what the proper clk for the lights is
    input logic p1_punch, p1_kick,  //player 1 made an attack
    input logic p2_punch, p2_kick,  //player 2 made an attack
    input logic p1_x, p2_x,	//location of player 1 and player 2
    
    output [7:0] cat,
    output [7:0] an,	//flicker the lights of the player taking damage?
    output logic jb
    );
/*   // commented out in order to synthesize top_level.sv
    parameter arm_len;
    parameter leg_len;
    parameter punch_pts;
    parameter kick_pts;

    logic [7:0] kitty;
    logic [3:0] p1_hp, p2_hp;
	//setup for display of p1_hp | p2_hp
    seven_seg_controller	points( .clk_in(clk), .rst_in(reset_in), 
							.val_in({p1_h, p2_hp}),
							.cat_out(kitty), .an_out(an) );
	//
    always @(posedge clk) begin
	if (p1_hp <= 3'b0) begin
		cat <= 7'b0
    	end else if (p1_punch & (p1_x + arm_len <= p2_x)) begin
		p2_hp <= p2_hp - punch_pts;
		
	end
    end
    */
endmodule
