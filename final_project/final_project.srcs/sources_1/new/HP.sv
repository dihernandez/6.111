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
    //debugger inputs
    input logic up_in, dn_in,
    	
    //inputs
    input clk,  reset_in,	//I can't remember what the proper clk for the lights is
    input logic p1_punch, p1_kick,  //player 1 made an attack   //this is a level, not a pulse
    input logic p2_punch, p2_kick,  //player 2 made an attack   //this is a level, not a pulse
    input logic [10:0] p1_x, p2_x,	//location of player 1 and player 2
    input logic [10:0] hcount,
    input logic [9:0] vcount,
    //outputs
    output [31:0] hit_points, // data for hex display
    output logic [7:0] p1_hp, p2_hp,                    //max hp of 256, 8 bits
    output logic p1_dead, p2_dead, // are they dead
    output logic [11:0] p1_hp_pix, p2_hp_pix,
    
    output logic speaker        //potential sounds
    );

    parameter arm_len = 11'd20;	    //arms be long
    parameter leg_len = 11'd25;	    //legs be longer
    parameter punch_pts = 8'd14;	//punches are weak
    parameter kick_pts = 8'd28;	//kicks are strong-ish
    parameter start_hp = 8'd100;

    //setup for display of p1_hp | p2_hp
    assign hit_points = {8'b0, p1_hp, 8'b0, p2_hp};   //9+7+9+7 = 32

    //HP BARS   
    logic [11:0] p1_hp_colour, p2_hp_colour;
    logic [3:0] p1_r, p1_g, p1_b, p2_r, p2_g, p2_b;
    logic [9:0] p1_hp_width, p2_hp_width;
    assign p1_hp_colour = {p1_r, p1_g, p1_b};
    assign p2_hp_colour = {p2_r, p2_g, p2_b};
    
    //rectangles that change size and colour!
    assign p1_hp_width = {p1_hp, 2'b11};
    changable_blob p1_hp_bar(
                    .WIDTH(p1_hp_width),   // default width: 64 pixels
                    .HEIGHT(32),  // default height: 64 pixels
                    .COLOR(p1_hp_colour),
                    .x_in(24), .y_in(666), //p1 starts on right side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p1_hp_pix)
                    );
    
    assign p2_hp_width = {p2_hp, 2'b11};          
    changable_blob p2_hp_bar(
                    .WIDTH(p2_hp_width),   // default width: 64 pixels
                    .HEIGHT(32),  // default height: 64 pixels
                    .COLOR(p2_hp_colour),
                    //1024-24
                    .x_in(1010 - p2_hp_width), .y_in(666), //p1 starts on right side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p2_hp_pix)
                    );
    
    
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
            p1_dead <= 0;
            p2_dead <= 0;
            p1_hp <= start_hp;    //start hp of 1000
            p2_hp <= start_hp;	//start hp of 1000 
            {p1_r, p1_g, p1_b} <= 12'h0F0;
            {p2_r, p2_g, p2_b} <= 12'h0F0;
            
            old_p1_punch <= 0;
            old_p2_punch <= 0;
            old_p1_kick <= 0;
            old_p2_kick <= 0;
        end else begin  //in game logic
            //Player 1 hp logic
            if (~p1_dead) begin 	//player 1 is not dead    
                //LOGIC
                if (p1_punch_on) begin
                    p1_punch_on <= 0;
                    if (p1_x + 64 + arm_len >= p2_x) begin	//p1 punches p2
                        if (p2_hp - punch_pts > 0 && p2_hp - punch_pts <= start_hp) begin    //if hit will not cause hp mishaps
                            p2_hp <= p2_hp - punch_pts;	//drop p2's hp
//                            p2_hp_colour <= p2_hp_colour + 12'h180;// - 12'h020;
                            p2_r <= p2_r + 4'h2;
                            p2_g <= p2_g - 4'h2;
                        end else begin
                            p2_hp <= 0;
                            p2_dead <= 1'b1;
                            {p2_r, p2_g, p2_b} <= 12'hF00;
                        end
                    end//p1 punch
                end else if (p1_kick_on) begin
                    p1_kick_on <= 0;
                    if (p1_x + 64 + leg_len >= p2_x) begin	//p1 kicks p2
                        if (p2_hp - kick_pts > 0 && p2_hp - kick_pts <= start_hp) begin
                            p2_hp <= p2_hp - kick_pts;	//drop p2's hp
//                            p2_hp_colour <= p2_hp_colour + 12'h300;// - 12'h040;
                            p2_r <= p2_r + 4'h4;
                            p2_g <= p2_g - 4'h4;
                        end else begin
                            p2_hp <= 0;
                            p2_dead <= 1'b1;
                            {p2_r, p2_g, p2_b} <= 12'hF00;
                        end
                    end
                //p2 punch
                end
            end//p1 hit logic
            
            //Player 2 hp logic
            if (~p2_dead) begin 	//player 2 is not dead
                //LOGIC    
                if (p2_punch_on) begin
                    p2_punch_on <= 0;
                    if (p1_x + 64 + arm_len >= p2_x) begin	//p2 punches p1
                        if (p1_hp - punch_pts > 0 && p1_hp - punch_pts < start_hp) begin    //if hit will not cause hp mishaps
                            p1_hp <= p1_hp - punch_pts;	//drop p2's hp
//                            p1_hp_colour <= p1_hp_colour + 12'h180;// - 12'h20;
                            p1_r <= p1_r + 4'h2;
                            p1_g <= p1_g - 4'h2;
                        end else begin
                            p1_hp <= 0;
                            p1_dead <= 1'b1;
                            {p1_r, p1_g, p1_b} <= 12'hF00;
                        end
                    end//p2 punching p1
                //p2 punch
                end else if (p2_kick_on) begin
                    p2_kick_on <= 0;
                    if (p1_x + 64 + leg_len >= p2_x) begin	//p2 kicks p1
                        if (p1_hp - kick_pts > 0 && p1_hp - kick_pts < start_hp) begin    //if hit will not cause hp mishaps
                            p1_hp <= p1_hp - kick_pts;	//drop p2's hp
//                            p1_hp_colour <= p1_hp_colour + 12'h300;// - 12'h040;
                            p1_r <= p1_r + 4'h4;
                            p1_g <= p1_g - 4'h4; 
                        end else begin
                            p1_hp <= 0;
                            p1_dead <= 1'b1;
                            {p1_r, p1_g, p1_b} <= 12'hF00;
                        end
                    end
                end//p2 kick
            end//p2 hit logic
        
        end//game logic
    end//always

endmodule


