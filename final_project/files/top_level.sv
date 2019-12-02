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

    // whether or not players 1 and 2 made the below actions
    logic p1_punch, p1_kick, p2_punch, p2_kick;
    camera_top_module ctm (
        .clk_65mhz(clk_65mhz),
        .sw(sw),
        .btnc(btnc), .btnu(btnu), .btnl(btnl), .btnr(btnr), .btnd(btnd),
        .ja(ja), .jb(jb), .jbclk(jbclk), .jd(jd), .jdclk(jdclk),
        .vga_r(vga_r), .vga_g(vga_g), .vga_hs(vga_hs), .vga_vs(vga_vs),
        .led16_b(led16_b), .led16_g(led16_g), .led16_r(led16_r),
        .led17_b(led17_b), .led17_g(led17_g), .led17_r(led17_r),
        .led(led),
        // segments a-g, dp
        .ca(ca), .cb(cb), .cc(cc), .cd(cd), .ce(ce), .cf(cf), .cg(cg), .dp(dp),  
        .an(an),    // Display location 0-7
        .p1_punch(p1_punch), .p1_kick(p1_kick),
        .p2_punch(p2_punch), .p2_kick(p2_kick)
    );

endmodule
