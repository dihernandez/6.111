`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// main camera module
//
//////////////////////////////////////////////////////////////////////////////////

module camera_top_level(
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

    // hex display
    logic [31:0] data = 0; //  instantiate 7-segment display; display (8) 4-bit hex
    logic [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    display_8hex display(.clk_in(clk_65mhz),.data_in(data), .seg_out(segments), .strobe_out(an));
    assign  dp = 1'b1;  // turn off the period
    
    // timer
    logic start;
    logic [3:0] value;
    logic counting, expired_pulse, one_hz;
    logic [3:0] count_out;
    timer timer_uut (
            .clock(clk_65mhz),
            .start_timer(start),
            .value(value),
            .counting(counting),
            .expired_pulse(expired_pulse),
            .one_hz(one_hz),
            .count_out(count_out)
        );
        
    // display time in seconds
    always_ff @(posedge clk_65mhz) begin
        if (one_hz) begin
            data <= data + 1;
        end
    end

    // screen display variables
    wire [10:0] hcount;    // pixel on current line
    wire [9:0] vcount;     // line number
    wire hsync, vsync, blank; // synchronized
    // un-synchronized; outputs of screen module
    wire hsync_prev, vsync_prev, blank_prev;
    wire [11:0] pixel;
    reg [11:0] rgb;    

    // synchronize hsync, vsync, blank (outputs of xvga)
    // synchronized outputs used for everything else
    synchronize sync_hsync(
            .clk(clk_65mhz),
            .in(hsync_prev),
            .out(hsync)
        );

    synchronize sync_vsync(
            .clk(clk_65mhz),
            .in(vsync_prev),
            .out(vsync)
        );

    synchronize sync_blank(
            .clk(clk_65mhz),
            .in(blank_prev),
            .out(blank)
        );

    // screen module
    xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync_prev),.vsync_out(vsync_prev),.blank_out(blank_prev));

    // timing screen display variables
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    
    // camera variables
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [7:0] pixel_buff, pixel_in;
    logic [15:0] output_pixels;
    logic [15:0] old_output_pixels;
    logic [12:0] processed_pixels;
    logic valid_pixel;
    logic frame_done_out;
    
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    
    logic xclk;
    logic[1:0] xclk_count;
    assign xclk = (xclk_count >2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;
    
    // memory holding the image from the camera
    blk_mem_gen_0 jojos_bram(.addra(pixel_addr_in), 
                             .clka(pclk_in),
                             .dina(processed_pixels),
                             .wea(valid_pixel),
                             .addrb(pixel_addr_out),
                             .clkb(clk_65mhz),
                             .doutb(frame_buff_out));
    
    // update pixel address as displaying pixels across the screen
    always_ff @(posedge pclk_in)begin
        if (frame_done_out)begin
            pixel_addr_in <= 17'b0;  
        end else if (valid_pixel)begin
            pixel_addr_in <= pixel_addr_in +1;  
        end
    end
    
    // update screen variables
    always_ff @(posedge clk_65mhz) begin
        pclk_buff <= jb[0];
        vsync_buff <= jb[1];
        href_buff <= jb[2];
        pixel_buff <= ja;
        pclk_in <= pclk_buff;
        vsync_in <= vsync_buff;
        href_in <= href_buff;
        pixel_in <= pixel_buff;
        old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;

        processed_pixels = {output_pixels[15:12],output_pixels[10:7],output_pixels[4:1]};
    end

    // if sw[2] on, make display larger
    assign pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign cam = sw[2]&&((hcount<640)&&(vcount<480)) ? frame_buff_out :
        ~sw[2]&&((hcount<320)&&(vcount<240)) ? frame_buff_out : 12'h000;
                                        
   camera_read  my_camera(.p_clock_in(pclk_in),
                          .vsync_in(vsync_in),
                          .href_in(href_in),
                          .p_data_in(pixel_in),
                          .pixel_data_out(output_pixels),
                          .pixel_valid_out(valid_pixel),
                          .frame_done_out(frame_done_out));
   
    // create border around screen
    wire border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);

    always_ff @(posedge clk_65mhz) begin
      // debugging: make sure screen is working
      if (sw[1:0] == 2'b01) begin
         // 1 pixel outline of visible area (white)
         rgb <= {12{border}};
      end else if (sw[1:0] == 2'b10) begin
         // color bars
         rgb <= {{4{hcount[8]}}, {4{hcount[7]}}, {4{hcount[6]}}} ;
      end else begin
         rgb <= cam;
      end
    end

    // the following lines are required for the Nexys4 VGA circuit - do not change
    reg b,hs,vs;
    assign hs = hsync;
    assign vs = vsync;
    assign b = blank;

    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;

endmodule

