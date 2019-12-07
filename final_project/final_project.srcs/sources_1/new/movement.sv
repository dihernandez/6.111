`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/03/2019 11:20:22 PM
// Design Name: 
// Module Name: movement
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


module movement(
    //debugger inputs
    input logic left_in, right_in, 
    //inputs
    input clk, reset_in,
    input logic p1_mvfwd, p2_mvfwd,
    input logic p1_mvbwd, p2_mvbwd,
    input logic p1_dead, p2_dead,
    input logic [9:0] p1_hp, p2_hp,
    input logic [11:0] p1_hp_pix, p2_hp_pix,    //
    input logic [10:0] hcount,
    input logic [9:0] vcount,
    input vsync_in,
    //outputs
    output logic [10:0] p1_x,
    output logic [10:0] p2_x,
    output logic [11:0] pixel_out
    );
    
    //screen size
    // x_total = 1024 pixels             512-64= 448     1024-256= 768
    // y_total =  768 pixels             384-64= 320     768-240= 528
    // try to get a 24
    
    //player starter sprites
    logic[11:0] p1_pix, p1_dead_pix, p2_pix, p2_dead_pix;     //squares for now 
    blob #(.WIDTH(64), .HEIGHT(64), .COLOR(12'HF00)) //mine is approximately "dark orchid"
        player1(.x_in(p1_x), .y_in(420), //p1 starts on right side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p1_pix)
                    );
    blob #(.WIDTH(64), .HEIGHT(16), .COLOR(12'HF00)) //mine is approximately "dark orchid"
        player1_dead(.x_in(p1_x), .y_in(468), //p1 starts on right side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p1_dead_pix)
                    );
        
    blob #(.WIDTH(64), .HEIGHT(64), .COLOR(12'H00F)) //mine is approximately "dark orchid"
        player2(.x_in(p2_x), .y_in(420), //p2 starts on left side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p2_pix)
                    );
    blob #(.WIDTH(64), .HEIGHT(16), .COLOR(12'H00F)) //mine is approximately "dark orchid"
        player2_dead(.x_in(p2_x), .y_in(468), //p2 starts on left side
                    .hcount_in(hcount), .vcount_in(vcount), 
                    .pixel_out(p2_dead_pix)
                    );
                    
    
    //if player is dead, display a flat rectangle in it's place    
    assign pixel_out =  (p1_dead)?  (p1_dead_pix + p2_pix + p1_hp_pix + p2_hp_pix): 
                        (p2_dead)?  (p1_pix + p2_dead_pix + p1_hp_pix + p2_hp_pix): 
                        (p1_pix + p2_pix + p1_hp_pix + p2_hp_pix);
    
    
    //rising edge vars
    logic old_clean;
    logic rising_sync;

    logic old_right, old_left, old_p1_fwd, old_p1_bwd, old_p2_fwd, old_p2_bwd;
    logic rising_right, rising_left, p1_rising_fwd, p1_rising_bwd, p2_rising_fwd, p2_rising_bwd;
    logic right_on, left_on, p1_fwd_on, p1_bwd_on, p2_fwd_on, p2_bwd_on;

    //rising edge for puck movement
    assign rising_sync = vsync_in & !old_clean;    //so individual presses cause visible steps
    assign rising_right = right_in & !old_right;    //  '   '   '   '   '   '   '   '   '   ' 
    assign rising_left = left_in & !old_left;       //  '   '   '   '   '   '   '   '   '   '
    assign p1_rising_fwd = p1_mvfwd & !old_p1_fwd;       //  '   '   '   '   '   '   '   '   '   '
    assign p1_rising_bwd = p1_mvbwd & !old_p1_bwd;       //  '   '   '   '   '   '   '   '   '   '
    assign p2_rising_fwd = p2_mvfwd & !old_p2_fwd;       //  '   '   '   '   '   '   '   '   '   '
    assign p2_rising_bwd = p2_mvbwd & !old_p2_bwd;       //  '   '   '   '   '   '   '   '   '   '
    
    always_ff @(posedge clk) begin
        old_clean <= vsync_in;
        old_right <= right_in;
        old_left <= left_in;
        
        
        if (rising_right) begin
            right_on <= 1;
        end else if (rising_left) begin
            left_on <= 1;
        end else if (p1_rising_fwd) begin
            p1_fwd_on <= 1;
        end else if (p1_rising_bwd) begin
            p1_bwd_on <= 1;
        end else if (p2_rising_fwd) begin
            p2_fwd_on <= 1;
        end else if (p2_rising_bwd) begin
            p2_bwd_on <= 1;
        end
        
        else if (rising_sync) begin
            if (reset_in) begin
                p1_x <= 320;
                p2_x <= 640;    //1024-320-64
                old_clean <= 0;
                old_right <= 0;
                old_left <= 0;
                old_p1_fwd <= 0;
                old_p1_bwd <= 0;
                old_p2_fwd <= 0;
                old_p2_bwd <= 0;
            end else begin    
                 if (~p1_dead) begin //when p1 is not dead, they can attack and move
                    //change 100s to hp level later
                    if ((p1_x + 64 + 25 <= p2_x) && (right_on || p1_fwd_on)) begin  //move forward, but don't run into p2
                        right_on <= 0;
                        p1_fwd_on <= 0;
                        p1_x <= p1_x + 25;
                    end else if ((p1_x - 25 >= 24) && (left_on || p1_bwd_on))  begin   // go backwards, but don't run into the wall 
                        left_on <= 0;
                        p1_bwd_on <= 0;
                        p1_x <= p1_x - 25;
                    end
                end//p1
                
                if (~p2_dead) begin //when p2 is not dead, they can attack and move
                    //change 100s to hp level later
                    if ((p1_x + 64 + 25 <= p2_x) && (right_on || p2_fwd_on)) begin  //move forward, but don't run into p1
                        right_on <= 0;
                        p2_fwd_on <= 0;
                        p2_x <= p2_x - 25;
                    end else if ((p2_x + 64 + 25 <= 1000) && (left_on || p2_bwd_on))  begin  //go backwards, but don't run into the wall 
                        left_on <= 0;
                        p2_bwd_on <= 0;
                        p2_x <= p2_x + 25;
                    end
                end//p2
//                if (~p2_dead) begin
//                    if (p2_mvfwd && (p2_x - 25 - 64 >= p1_x) ) begin  //don't run into p2
//                        p2_x <= p2_x - 25;
//                    end else if (p2_mvbwd && (p1_x + 25 + 64 <= 900))  begin   //as is, p1 cant run into p2 going backwards,
//                                                                           //but can run into the wall... 
//                        p2_x <= p2_x + 25;
//                    end 
//                end//p2
                
            end//not reset
        end//rising_sync
    end //always
    
endmodule
