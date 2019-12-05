`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// top_level module
//
//////////////////////////////////////////////////////////////////////////////////

module top_level (
        input clk_100mhz,
        input[15:0] sw,
        input btnc, btnu, btnl, btnr, btnd,
        input [7:0] ja,
        input [2:0] jb,
        output   jbclk,
        input [2:0] jd,
        output   jdclk,
        output[3:0] vga_r,
        output[3:0] vga_b,
        output[3:0] vga_g,
        output vga_hs,
        output vga_vs,
        output led16_b, led16_g, led16_r,
        output led17_b, led17_g, led17_r,
        output[15:0] led,
        output ca, cb, cc, cd, ce, cf, cg, dp,  // segments a-g, dp
        output[7:0] an    // Display location 0-7
    );

    // create 65mhz system clock, happens to match 1024 x 768 XVGA timing
    logic clk_65mhz;
    clk_wiz_65mhz clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz));

    // ACTIONS
    logic p1_punch, p1_kick, p2_punch, p2_kick; //hit action being taken 
    logic p1_fwd, p2_fwd;   //is the player moving forward?
    logic p1_bwd, p2_bwd;   //is the player moving backward?

    wire hsync, vsync, blank;
    logic [11:0] user_output;   //pixels from camera and motions
    logic [31:0] debugging_display_data;

    camera_top_module ctm (
        .clk_65mhz(clk_65mhz),
        .sw(sw),
        .ja(ja), .jb(jb), .jbclk(jbclk), .jd(jd), .jdclk(jdclk),
        .hsync(hsync), .vsync(vsync), .blank(blank),
        .pixel_out(user_output),  //////////////////////////////////////////changed
        .display_data(debugging_display_data),
        .p1_punch(p1_punch), .p1_kick(p1_kick),
        .p2_punch(p2_punch), .p2_kick(p2_kick),
        .p1_move_forwards(p1_fwd),
        .p2_move_forwards(p2_fwd),
        .p1_move_backwards(p1_bwd),
        .p2_move_backwards(p2_bwd)
    );


    // hex display
    logic [31:0] display_data;
    logic [31:0] hp_display_data;
    
    // if left button pressed, display debugging output
    // else display hit points
    assign display_data = btnl ? debugging_display_data : hp_display_data;
    logic [6:0] segments; // 7-segment display
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    logic [6:0] segs_temp;  //dummy var to prevent conflicts
    logic [6:0] an_temp;    //dummy var to prevent conflicts
    assign dp = 1'b1; // turn off the period
    
    display_8hex display (
        .clk_in(clk_65mhz),
        .data_in(display_data), //uses either debugging stuff or hp
        .seg_out(segments),    //dummy var to prevent conflicts: segs_temp
        .strobe_out(an)    //dummy var to prevent conflicts: an_temp
    );
    
    //TODO: finish logic for to control this
    logic [11:0] p1_loc, p2_loc;	//locations of players
    logic [6:0] p1_points, p2_points;	//health points of players
    logic p1_dead, p2_dead;		//which players, if any, are dead
    logic [11:0] game_output;   //pixels from game logic
    movement    player_motion(
        .p1_dead(p1_dead), .p2_dead(p2_dead),
        .p1_mvfwd(p1_fwd), .p2_mvfwd(p2_fwd),
        .p1_mvbwd(p1_bwd), .p2_mvbwd(p2_bwd),
        .p1_hp(p1_points), .p2_hp(p2_points),
        //outputs
        .p1_x(p1_loc), .p2_x(p2_loc),
        .pixel_out(game_output) /////////////////////////////////new
    );
    
    HP	health_points(
        //INPUTS
        .clk(clk_65mhz),
        .reset_in(btnc),	//I can't remember what the proper clk for the lights is
    	.p1_punch(p1_punch), .p1_kick(p1_kick),  //player 1 made an attack
    	.p2_punch(p2_punch), .p2_kick(p2_kick),  //player 2 made an attack
    	.p1_x(p1_loc), .p2_x(p2_loc),	//location of player 1 and player 2
    	
        //OUTPUTS
        .hit_points(hp_display_data),   //hp vals
    	.p1_hp(p1_points), .p2_hp(p2_points),
    	.p1_dead(p1_dead), .p2_dead(p2_dead),
    	.speaker(jb[0])
        
    );
   
    //screen output
    logic [11:0] pixel_out;
    assign pixel_out = game_output;//(user_output > 0)? user_output:game_output;
    
       
    // the following lines are required for the Nexys4 VGA circuit - do not change
    reg b,hs,vs;
    assign hs = hsync;
    assign vs = vsync;
    assign b = blank;

    assign vga_r = ~b ? pixel_out[11:8]: 0;
    assign vga_g = ~b ? pixel_out[7:4] : 0;
    assign vga_b = ~b ? pixel_out[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;
endmodule
