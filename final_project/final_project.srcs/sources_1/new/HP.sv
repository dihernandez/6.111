`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2019 04:13:44 PM
// Design Name: 
// Module Name: HP
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: handles the 7-seg lights response
//					and the sound response
// 
//////////////////////////////////////////////////////////////////////////////////

// controls the hit points logic and player feedback
module HP (
    //inputs
    input clk,  reset_in,	//I can't remember what the proper clk for the lights is
    input logic p1_punch, p1_kick,  //player 1 made an attack
    input logic p2_punch, p2_kick,  //player 2 made an attack
    input logic [10:0] p1_x, p2_x,	//location of player 1 and player 2
    //outputs
    output [31:0] hit_points, // data for hex display
    output logic [9:0] p1_hp, p2_hp,
    output logic p1_dead, p2_dead, // are they dead
    output logic speaker        //potential sounds
    );

    parameter arm_len = 5;	//arms be long
    parameter leg_len = 6;	//legs be longer
    parameter punch_pts = 10;	//punches are weak
    parameter kick_pts = 20;	//kicks are strong-ish


    //setup for display of p1_hp | p2_hp
    assign hit_points = {6'b0, p1_hp, 6'b0, p2_hp};   //9+7+9+7 = 32

//moved to movement
//    //HP BARS
//    logic[11:0] p1_hp_pix, p2_hp_pix;     //rectangles that (hopefully) change size!
//    changable_blob p1_hp_bar(
//                    .WIDTH({3'b0, p1_hp}),   // default width: 64 pixels
//                    .HEIGHT(32),  // default height: 64 pixels
//                    .COLOR(12'hF00),
//                    .x_in(32), .y_in(666), //p1 starts on right side
//                    .hcount_in(hcount), .vcount_in(vcount), 
//                    .pixel_out(p1_hp_pix)
//                    );

    
    //rising edge vars
    
    logic old_p1_punch, old_p2_punch, old_p1_kick, old_p2_kick;             //tracks previous val
    logic rising_p1_punch, rising_p2_punch, rising_p1_kick, rising_p2_kick; //makes is pos on an edge
    logic p1_punch_on, p2_punch_on, p1_kick_on, p2_kick_on;                 //pos until action is taken 

    //rising edge for puck movement
    assign rising_p1_punch = p1_punch & !old_p1_punch;  //so individual presses cause visible steps 
    assign rising_p2_punch = p2_punch & !old_p2_punch;  //  '   '   '   '   '   '   '   '   '   '
    assign rising_p1_kick = p1_kick & !old_p1_kick;     //  '   '   '   '   '   '   '   '   '   '   
    assign rising_p2_kick = p2_kick & !old_p2_kick;     //  '   '   '   '   '   '   '   '   '   '   

    //points logic
    always_ff @(posedge clk) begin
        old_p1_punch <= p1_punch;
        old_p2_punch <= p2_punch;
        old_p1_kick <= p1_kick;
        old_p2_kick <= p2_kick;
        
        if (rising_p1_punch) begin
            p1_punch_on <= 1;
        end else if (rising_p2_punch) begin
            p2_punch_on <= 1;
        end else if (rising_p1_kick) begin
            p1_kick_on <= 1;
        end else if (rising_p2_kick) begin
            p2_kick_on <= 1;
        end
        
        if (reset_in) begin     //RESTART
            p1_hp <= 10'd100;    //start hp of 1000
            p2_hp <= 10'd100;	//start hp of 1000
            p1_dead <= 0;
            p2_dead <= 0;
            old_p1_punch <= 0;
            old_p2_punch <= 0;
            old_p1_kick <= 0;
            old_p2_kick <= 0;
        end else begin  //in game logic
        
            //Player 1 hp logic
            if (p1_hp > 10'd100 || p1_hp < 10'b0) begin	//player 1 has died
                p1_hp <= 10'b0;		//hp shows up as "0000"
                p1_dead <= 1'b1;	//DEAD
            end else if (~p1_dead) begin 	//player 1 is not dead
                if (p1_punch_on) begin
                    p1_punch_on <= 0;
                    if (p1_x + arm_len <= p2_x) begin	//p1 punches p2
                        p2_hp <= p2_hp - punch_pts;	//drop p2's hp
                        //p2 may get shoved back at some point, but not now
                    end//p1 punch
                end else if (p1_kick_on) begin
                    p1_kick_on <= 0;
                    if (p1_x + leg_len <= p2_x) begin	//p1 kicks p2
                        p2_hp <= p2_hp - kick_pts;	//drop p2's hp
                    end
                //p2 punch
                end
            end//p1 hit logic
            
            //Player 2 hp logic
            if (p2_hp <= 10'b0) begin	//player 2 has died
                p2_hp <= 10'b0;		//hp shows up as "0000"
                p2_dead <= 1'b1;	//DEAD
            end else if (~p2_dead) begin 	//player 2 is not dead
                if (p2_punch_on) begin
                    p2_punch_on <= 0;
                    if (p2_x <= p1_x + arm_len) begin	//p2 punches p1
                        p1_hp <= p1_hp - punch_pts;	//drop p1's hp
                        //p1 may get shoved back at some point, but not now
                    end
                //p2 punch
                end else if (p2_kick_on) begin
                    p2_kick_on <= 0;
                    if (p2_x <= p1_x + leg_len) begin	//p2 kicks p1
                        p1_hp <= p1_hp - kick_pts;	//drop p1's hp
                    end
                end//p2 kick
            end//p2 hit logic
            
        end//game logic
    end//always

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
