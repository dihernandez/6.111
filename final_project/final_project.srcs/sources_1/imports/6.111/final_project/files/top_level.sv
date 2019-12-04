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
    logic p1_punch, p1_kick, p2_punch, p2_kick;
    wire hsync, vsync, blank;
    logic [11:0] pixel_out;
    logic [31:0] debugging_display_data;
    camera_top_module ctm (
        .clk_65mhz(clk_65mhz),
        .sw(sw),
        .ja(ja), .jb(jb), .jbclk(jbclk), .jd(jd), .jdclk(jdclk),
        .hsync(hsync), .vsync(vsync), .blank(blank),
        .pixel_out(pixel_out),
        .display_data(debugging_display_data),
        .p1_punch(p1_punch), .p1_kick(p1_kick),
        .p2_punch(p2_punch), .p2_kick(p2_kick)
    );

    logic [11:0] p1_loc, p2_loc;	//locations of players
    logic [6:0] p1_points, p2_points;	//health points of players
    logic p1_dead, p2_dead;		//which players, if any, are dead
    logic p1_hp, p2_hp; // hit points
    logic [31:0] hp_display_data;
    HP	health_points(
        .clk(clk_65mhz),
        .reset_in(btnc),	//I can't remember what the proper clk for the lights is
    	.p1_punch(p1_punch), .p1_kick(p1_kick),  //player 1 made an attack
    	.p2_punch(p2_punch), .p2_kick(p2_kick),  //player 2 made an attack
    	.p1_x(p1_loc), .p2_x(p2_loc),	//location of player 1 and player 2
    	
        //outputs
        .hit_points(hp_display_data),
        /*
    	.cat({cg, cf, ce, cd, cd, cc, cb, ca}),
    	.an(an),	//flicker the lights of the player taking damage?
        */
    	.speaker(jb[0]),
        .p1_dead(p1_dead), .p2_dead(p2_dead),
    	.p1_hp_output(p1_hp), .p2_hp_output(p2_hp)
    );

    // hex display
    logic [31:0] display_data;
    // if left button pressed, display debugging output
    // else display hit points
    assign display_data = btnl ? debugging_display_data : hp_display_data;
    logic [6:0] segments; // 7-segment display
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    assign dp = 1'b1; // turn off the period
    display_8hex display (
        .clk_in(clk_65mhz),
        .data_in(display_data),
        .seg_out(segments),
        .strobe_out(an)
    );

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
