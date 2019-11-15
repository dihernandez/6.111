`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// camera testing module
//////////////////////////////////////////////////////////////////////////////////

module camera_top_level (   
        // inputs
        input clk_100mhz,
        input [15:0] sw,
        input btnc, btnu, btnl, btnr, btnd,
        input [7:0] ja,
        input [2:0] jb,
        input [2:0] jd,
        // outputs
        output jbclk,
        output jdclk,
        output vga_hs,
        output vga_vs,
        output [3:0] vga_r,
        output [3:0] vga_b,
        output [3:0] vga_g,
        output led16_b, led16_g, led16_r,
        output led17_b, led17_g, led17_r,
        output logic [15:0] led,
        output ca, cb, cc, cd, ce, cf, cg, dp,  // segments a-g, dp
        output [7:0] an    // Display location 0-7
    );
    
    // create 65mhz system clock, happens to match 1024 x 768
    // XVGA timing
    wire clk_65mhz;
    clk_wiz_65mhz clkdivider(.clk_in1(clk_100mhz),
            .clk_out1(clk_65mhz));

    // XVGA display + camera code
    wire [10:0] hcount;    // pixel on current line
    wire [9:0] vcount;     // line number
    wire hsync, vsync, blank;
    wire [11:0] pixel;
    reg [11:0] rgb;    
    xvga xvga1(.vclock_in(clk_65mhz),.hcount_out(hcount),.vcount_out(vcount),
          .hsync_out(hsync),.vsync_out(vsync),.blank_out(blank));

    logic xclk;
    logic[1:0] xclk_count;
    
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic[7:0] pixel_buff, pixel_in;
    
    assign xclk = (xclk_count >2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;
    
    // bram_rgb variable
    logic [11:0] frame_buff_out_rgb;
    logic [12:0] processed_pixels_rgb;
    logic [16:0] rgb_pixel_addr_in;
    logic [16:0] rgb_pixel_addr_out;
    logic valid_rgb_pixel;

    // memory that holds RGB image from camera
    blk_mem_gen_0 bram_rgb(
                // inputs
                .addra(rgb_pixel_addr_in), 
                .clka(pclk_in),
                .dina(processed_pixels_rgb),
                .wea(valid_rgb_pixel),
                .addrb(rgb_pixel_addr_out), 
                .clkb(clk_65mhz),
                // output
                .doutb(frame_buff_out_rgb)
        );

    // bram_hsv variable
    // 0 = no match; 1-3 = match to hsv color 1-3
    logic [1:0] hsv_thresh;
    // displays hsv values if correct sw's on
    logic [1:0] processed_hsv_thresh;
    logic [1:0] frame_buff_out_hsv_thresh;
    logic [16:0] hsv_pixel_addr_in;
    logic [16:0] hsv_pixel_addr_out;
    logic valid_hsv_thresh;

    // memory that holds HSV threshholding of camera image
    blk_mem_gen_1 bram_hsv(
                // inputs
                .addra(hsv_pixel_addr_in), 
                .clka(pclk_in),
                .dina(processed_hsv_thresh),
                .wea(valid_hsv_thresh),
                .addrb(hsv_pixel_addr_out), 
                .clkb(clk_65mhz),
                // output
                .doutb(frame_buff_out_hsv_thresh)
        );

    // camera variables
    logic [11:0] cam;
    logic [15:0] output_pixels_rgb;
    //logic [15:0] old_output_pixels;
    logic rgb_frame_done_out;
    logic hsv_frame_done_out;
    
    camera_read my_camera (
            .p_clock_in(pclk_in),
            .vsync_in(vsync_in),
            .href_in(href_in),
            .p_data_in(pixel_in),
            .pixel_data_out(output_pixels_rgb),
            .hsv_thresh_data_out(hsv_thresh),
            .rgb_pixel_valid_out(valid_rgb_pixel),
            .hsv_thresh_valid_out(valid_hsv_thresh),
            .hsv_frame_done_out(hsv_frame_done_out),
            .rgb_frame_done_out(rgb_frame_done_out)
        );

    // display image larger if sw[2] is on
    assign rgb_pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign hsv_pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;

    // if sw[6], sw[7] or sw[8] on, determine frame_buff_out from frame_buff_out_hsv_thresh
    // else set frame_buff_out to frame_buff_out_rgb
    logic [11:0] frame_buff_out;
    always_comb begin
        if (sw[13] || sw[14] || sw[15]) begin
            if (frame_buff_out_hsv_thresh==1) frame_buff_out = 12'hF00;
            else if (frame_buff_out_hsv_thresh==2) frame_buff_out = 12'h0F0;
            else if (frame_buff_out_hsv_thresh==3) frame_buff_out = 12'h00F;
            else frame_buff_out = 12'hFFF;
        end else begin
            frame_buff_out = frame_buff_out_rgb;
        end
    end

    // get pixel to display from image from camera 
    // display image larger if sw[2] is on
    assign cam = sw[2]&&((hcount<640)&&(vcount<480)) ? frame_buff_out : 
        ~sw[2]&&((hcount<320)&&(vcount<240)) ? frame_buff_out : 12'h000;

    always_ff @(posedge pclk_in)begin
        if (rgb_frame_done_out) begin
            rgb_pixel_addr_in <= 17'b0;  
        end else if (valid_rgb_pixel) begin
            rgb_pixel_addr_in <= rgb_pixel_addr_in + 1;  
        end
        
        if (hsv_frame_done_out) begin
            hsv_pixel_addr_in <= 17'b0;  
        end else if (valid_hsv_thresh) begin
            hsv_pixel_addr_in <= hsv_pixel_addr_in + 1;  
        end
    end
    
    // use switches to determine output
    always_ff @(posedge clk_65mhz) begin
        pclk_buff <= jb[0];
        vsync_buff <= jb[1]; 
        href_buff <= jb[2]; 
        pixel_buff <= ja;
        pclk_in <= pclk_buff;
        vsync_in <= vsync_buff;
        href_in <= href_buff;
        pixel_in <= pixel_buff;
        //old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;

        // RGB threshholding
        if (sw[3]) begin
            if ((output_pixels_rgb[15:12]>4'b1000)&&(output_pixels_rgb[10:7]<4'b1000)&&
                    (output_pixels_rgb[4:1]<4'b1000)) begin
                processed_pixels_rgb <= 12'hF00;
            end else begin
                processed_pixels_rgb <= 12'h000;
            end
        end else if (sw[4]) begin
            if ((output_pixels_rgb[15:12]<4'b1000)&&(output_pixels_rgb[10:7]>4'b1000)&&
                    (output_pixels_rgb[4:1]<4'b1000)) begin
                processed_pixels_rgb <= 12'h0F0;
            end else begin
                processed_pixels_rgb <= 12'h000;
            end
        end else if (sw[5]) begin
            if ((output_pixels_rgb[15:12]<4'b1000)&&(output_pixels_rgb[10:7]<4'b1000)&&
                    (output_pixels_rgb[4:1]>4'b1000)) begin
                processed_pixels_rgb <= 12'h00F;
            end else begin
                processed_pixels_rgb <= 12'h000;
            end
        end else begin
            processed_pixels_rgb <= {output_pixels_rgb[15:12],output_pixels_rgb[10:7],
                output_pixels_rgb[4:1]};
        end

        // HSV threshholding
        if (sw[15] && hsv_thresh==1) processed_hsv_thresh <= 1;
        else if (sw[14] && hsv_thresh==2) processed_hsv_thresh <= 2;
        else if (sw[13] && hsv_thresh==3) processed_hsv_thresh <= 3;
        else processed_hsv_thresh <= 0;
    end

    /*
    ila_0 ila_uut(.clk(clk_65mhz),    
        .probe0(pixel_in), 
        .probe1(pclk_in), 
        .probe2(vsync_in),
        .probe3(href_in),
        .probe4(jbclk)
    );
    */

    wire border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);
    always_ff @(posedge clk_65mhz) begin
      // debugging - make sure screen is working
      if (sw[1:0] == 2'b01) begin
         // 1 pixel outline of visible area (white)
         rgb <= {12{border}};
      end else if (sw[1:0] == 2'b10) begin
         // color bars
         rgb <= {{4{hcount[8]}}, {4{hcount[7]}}, {4{hcount[6]}}} ;
      // default: display image from camera
      end else begin
         rgb <= cam;
      end
    end

    // for debugging
    assign led = sw;

    /*
    // btnc button is user reset
    wire reset;
    debounce db1(.reset_in(reset),.clock_in(clk_65mhz),.noisy_in(btnc),.clean_out(reset));
    */

    // timer module
    // declare inputs / outputs
    logic start_timer, counting, expired, one_hz;
    logic [3:0] value, count_out;
    timer timer_uut ( 
        // inputs
        .clock(clk_65mhz),
        .start_timer(start_timer),
        .value(value),
        // outputs
        .counting(counting),
        .expired_pulse(expired),
        .one_hz(one_hz),
        .count_out(count_out) 
    );

    // seven segment display module
    // declare inputs / outputs
    logic [31:0] data_in;
    wire [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    display_8hex display_uut (
        // inputs
        .clk_in(clk_65mhz),
        .data_in(data_in),
        // outputs
        .seg_out(segments),
        .strobe_out(an)
    );

    // one second timer
    logic one_second_pulse;

    always_ff @(posedge clk_65mhz) begin
        if (one_hz) begin
            one_second_pulse <= !one_second_pulse;
            data_in <= data_in + 1;
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

endmodule // camera_top_level

//////////////////////////////////////////////////////////////////////////////////
// syncrhonize module
//////////////////////////////////////////////////////////////////////////////////

module synchronize #(parameter NSYNC = 3)  // number of sync flops.  must be >= 2
                   (input clk,in,
                    output reg out);

  reg [NSYNC-2:0] sync;

  always_ff @ (posedge clk)
  begin
    {out,sync} <= {sync[NSYNC-2:0],in};
  end
endmodule
