`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// top_level module
//
//////////////////////////////////////////////////////////////////////////////////

module top_level (
        //inputs
        input clk_100mhz,
        input[15:0] sw,
        input btnc, btnu, btnl, btnr, btnd, //need debouncing!!!!!!!!!!!!!!!!11
        input [7:0] ja,
        input [2:0] jb,
        input [2:0] jd,
        //outputs
        output   jbclk,
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
    clk_wiz_final clkdivider(.clk_in1(clk_100mhz), .clk_out1(clk_65mhz));
    
    //DEBOUNCING
    logic centre, upper, lower, lefty, righty;
    debounce dbc( .reset_in(0), .clock_in(clk_65mhz), .noisy_in(btnc), .clean_out(centre));
    debounce dbu( .reset_in(0), .clock_in(clk_65mhz), .noisy_in(btnu), .clean_out(upper));
    debounce dbd( .reset_in(0), .clock_in(clk_65mhz), .noisy_in(btnd), .clean_out(lower));
    debounce dbl( .reset_in(0), .clock_in(clk_65mhz), .noisy_in(btnl), .clean_out(lefty));
    debounce dbr( .reset_in(0), .clock_in(clk_65mhz), .noisy_in(btnr), .clean_out(righty));    

    // ACTIONS
    logic p1_punch, p1_kick, p2_punch, p2_kick; //hit action being taken 
    logic p1_fwd, p2_fwd;   //is the player moving forward?
    logic p1_bwd, p2_bwd;   //is the player moving backward?

    wire hsync, vsync, blank;
    logic [11:0] user_output;   //pixels from camera and motions
    logic [31:0] debugging_display_data;
    logic [10:0] h_count;
    logic [9:0] v_count;

//    camera_top_module ctm (
//        .clk_65mhz(clk_65mhz),
//        .sw(sw),
//        .ja(ja), .jb(jb), .jbclk(jbclk), .jd(jd), .jdclk(jdclk),
//        .hsync(hsync), .vsync(vsync), .blank(blank),
//        .pixel_out(user_output),
//        .display_data(debugging_display_data),
//        .p1_punch(p1_punch), .p1_kick(p1_kick),
//        .p2_punch(p2_punch), .p2_kick(p2_kick),
//        .p1_move_forwards(p1_fwd),
//        .p2_move_forwards(p2_fwd),
//        .p1_move_backwards(p1_bwd),
//        .p2_move_backwards(p2_bwd),
//        .hcount(h_count),
//        .vcount(v_count)
//    );


    // hex display
    logic [31:0] display_data;
    logic [31:0] hp_display_data;
    
    logic [31:0] x_pos;
    assign x_pos = {5'b0, p1_loc, 5'b0, p2_loc};    //player locs    
    
    // if sw[0] switched, display debugging output
    // elif sw[1] display hit points
    //else display x_coordinates of players
    assign display_data = sw[1] ? debugging_display_data : sw[0]? hp_display_data: x_pos;
    
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
    logic [10:0] p1_loc, p2_loc;        //locations of players
    logic [9:0] p1_points, p2_points;	//health points of players
    logic p1_dead, p2_dead;             //which players, if any, are dead
    logic [11:0] p1_hppix, p2_hppix;    //
    logic [11:0] game_output;           //pixels from game logic
    movement    player_motion(
        .left_in(lefty), .right_in(righty),    //debugger inputs
        .clk(clk_100mhz), .reset_in(centre),
        .p1_dead(p1_dead), .p2_dead(p2_dead),
        .p1_hp(p1_points), .p2_hp(p2_points),
        .p1_hp_pix(p1_hppix), .p2_hp_pix(p2_hppix),
        .p1_fwd(p1_fwd), .p2_fwd(p2_fwd),
        .p1_bwd(p1_bwd), .p2_bwd(p2_bwd),
        .hcount(h_count), .vcount(v_count),
        .vsync_in(vsync),
        //outputs
        .p1_x(p1_loc), .p2_x(p2_loc),
        .pixel_out(game_output)
    );
    
    HP	health_points(
        //debugger inputs
        .up_in(upper), .dn_in(lower),
        //INPUTS
        .clk(clk_100mhz),   //I can't remember what the proper clock for the lights is
        .reset_in(centre), 
    	.p1_punch(p1_punch), .p1_kick(p1_kick),  //player 1 made an attack
    	.p2_punch(p2_punch), .p2_kick(p2_kick),  //player 2 made an attack
    	.p1_x(p1_loc), .p2_x(p2_loc),	//location of player 1 and player 2
    	.hcount(h_count),
        .vcount(v_count),
    	
        //OUTPUTS
        .hit_points(hp_display_data),   //hp vals
    	.p1_hp(p1_points), .p2_hp(p2_points),
    	.p1_dead(p1_dead), .p2_dead(p2_dead),
    	.p1_hp_pix(p1_hppix), .p2_hp_pix(p2_hppix),
    	.speaker(jb[0])
        
    );
   
    //screen output
    logic [11:0] pixel_out;
    assign pixel_out = game_output? game_output: user_output;  //hopefully allows all things to show up
    
       
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

