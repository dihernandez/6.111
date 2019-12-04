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
module HP (
    input clk,  reset_in,	//I can't remember what the proper clk for the lights is
    input logic p1_punch, p1_kick,  //player 1 made an attack
    input logic p2_punch, p2_kick,  //player 2 made an attack
    input logic [11:0] p1_x, p2_x,	//location of player 1 and player 2
    
    output logic [9:0] p1_hp, p2_hp,
    output [31:0] hit_points, // data for hex display
    output logic p1_dead, p2_dead, // are they dead
    output logic speaker        //potential sounds
    );

    parameter arm_len = 3'd5;	//arms be long
    parameter leg_len = 3'd6;	//legs be longer
    parameter punch_pts = 3'd5;	//punches are weak
    parameter kick_pts = 4'd10;	//kicks are strong-ish

    /*excessive variables?
    assign p1_hp_output = p1_hp;
    assign p2_hp_output = p2_hp;
    initial begin
        p1_hp = 7'b110_0100;
        p2_hp = 7'b110_0100;	//start hp of 100
    end*/
    
    //setup for display of p1_hp | p2_hp
    assign hit_points = {6'b0, p1_hp, 6'b0, p2_hp};
    /*seven_seg_controller	points( .clk_in(clk), .rst_in(reset_in), 
                                    .val_in(hit_points),
    						        .cat_out(cat_out), .an_out(an_out) );*/

    //points logic
    always_ff @(posedge clk) begin
        if (reset_in) begin     //RESTART
            p1_hp <= 10'd1000;  //start hp of 1000
            p2_hp <= 10'd1000;	//start hp of 1000
        end else begin  //in game logic
        
            //Player 1 hp logic
            if (p1_hp <= 7'b0) begin	//player 1 has died
                p1_hp <= 7'b0;		//hp shows up as "0000"
                p1_dead <= 1'b1;	//DEAD
            end else if (~p1_dead) begin 	//player 1 is not dead
                if (p1_punch & (p1_x + arm_len <= p2_x)) begin	//p1 punches p2
                    p2_hp <= p2_hp - punch_pts;	//drop p2's hp
                    //p2 may get shoved back at some point, but not now
                end else if (p1_kick & (p1_x + leg_len <= p2_x)) begin	//p1 kicks p2
                    p2_hp <= p2_hp - kick_pts;	//drop p2's hp
                end
            end
            
            //Player 2 hp logic
            if (p2_hp <= 7'b0) begin	//player 2 has died
                p2_hp <= 7'b0;		//hp shows up as "0000"
                p2_dead <= 1'b1;	//DEAD
            end else if (~p2_dead) begin 	//player 2 is not dead
		
                if (p2_punch & (p2_x + arm_len <= p1_x)) begin	//p2 punches p1
                    p1_hp <= p1_hp - punch_pts;	//drop p1's hp
                    //p1 may get shoved back at some point, but not now
                end else if (p2_kick & (p2_x + leg_len <= p1_x)) begin	//p2 kicks p1
                    p1_hp <= p1_hp - kick_pts;	//drop p1's hp
                end
            
            end
            
        end
    end

endmodule

/////////////////////////////////////////////////////////////////
//	converts hex to dec
/////////////////////////////////////////////////////////////////
/*module HP(
	input [6:0] 	hex_hp,
	output [11:0]	dec_hp
);

	always_comb begin
		case (hex_hp)
			4'b1010:	dec_hp = 
			4'b1011:	dec_hp = 		
			4'b1100:
			4'b1101:
			4'b1110:
			4'b1111:
			default;
endmodule
*/