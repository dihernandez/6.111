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
    input logic left_in, right_in, up_in, dn_in,
    //inputs
    input clk, reset_in,
    input logic p1_fwd, p2_fwd,
    input logic p1_bwd, p2_bwd,
    input logic p1_dead, p2_dead,
//    input logic [7:0] p1_hp, p2_hp,
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
    // x_total = 1024 pixels
    // y_total =  768 pixels
    // try to get a 24 pixel border
    
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

    //rising edge for puck movement
    assign rising_sync = vsync_in & !old_clean;     //so individual presses cause visible steps
    
    //FSM for each player instead
    //0 is waiting
    //1 is punching
    //2 is kicking
    //3 is forward
    //4 is backward
    
    always_ff @(posedge clk) begin
        //initialize all the olds
        old_clean <= vsync_in;
        
        //set signals high on rising edge; will change back to 0 after action-in-question is taken or on RESET
        if (rising_sync) begin
            
            if (reset_in) begin
                p1_x <= 320;
                p2_x <= 640;    //1024-320-64
                old_clean <= 0;

            end else begin    
                 if (~p1_dead) begin //when p1 is not dead, they can attack and move
                    //change 4s to hp level later
                    if ((p1_x + 64 + 4 <= p2_x) && (right_in || p1_fwd)) begin  //move forward, but don't run into p2
                        p1_x <= p1_x + 4;
                    end 
                    else if ((p1_x >= 24 + 4) && (left_in || p1_bwd))  begin   // go backwards, but don't run into the wall 
                        p1_x <= p1_x - 4;
                    end
                end//p1
                
                if (~p2_dead) begin //when p2 is not dead, they can attack and move
                    //change 100s to hp level later
                    if ((p1_x + 64 + 4 <= p2_x) && (up_in || p2_fwd)) begin  //move forward, but don't run into p1
                        p2_x <= p2_x - 4;
                    end else if ((p2_x + 64 + 4 <= 1000) && (dn_in || p2_bwd))  begin  //go backwards, but don't run into the wall 
                        p2_x <= p2_x + 4;
                    end
                end//p2
          
            end//not reset
        end//rising_sync
    end //always
    
endmodule
