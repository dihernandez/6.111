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
    logic [31:0] data; // 7-segment display; display (8) 4-bit hex
    logic [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    display_8hex display(.clk_in(clk_65mhz),.data_in(data), .seg_out(segments), .strobe_out(an));
    assign dp = 1'b1;  // turn off the period
    
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
    logic one_second_pulse;
    assign led16_b = one_second_pulse;
        
    always_ff @(posedge clk_65mhz) begin
        if (one_hz) begin
            one_second_pulse <= ~one_second_pulse;
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
    
    // camera variables
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [7:0] pixel_buff, pixel_in;
    logic [15:0] output_pixels;
    //logic [15:0] old_output_pixels;
    logic [12:0] processed_pixels;
    assign processed_pixels = {output_pixels[15:12],
            output_pixels[10:7], output_pixels[4:1]};
    logic valid_pixel;
    logic frame_done_out;
    // frame_done_out delayed by one clock cycle
    logic buffer_frame_done_out;
    logic after_frame_before_first_pixel;
    
    // track IR LEDs
    // num. lighted up pixels
    logic [15:0] count_num_pixels_in_spot; // counts up
    logic [15:0] final_num_pixels_in_spot; // final (valid) value
    assign data = final_num_pixels_in_spot;
    // sum of x and y coordinates of lighted up pixels
    logic [23:0] x_coord_sum, y_coord_sum;

    // divide sum of x and y coordinates by total # of coordinates
    // inputs
    logic x_num_valid, x_denom_valid, y_num_valid, y_denom_valid;

    // outputs
    // output of divider is formatted so that first 24 bits
    // are the integer solution and the next 16 bits are the remainder
    logic [39:0] x_div_and_remainder_out, y_div_and_remainder_out;
    logic [23:0] x_div_out, y_div_out;
    logic x_div_out_valid, y_div_out_valid;
    // extract solutions (w/o remainder) from output of ip divider
    assign x_div_out = x_div_and_remainder_out[39:16];
    assign y_div_out = y_div_and_remainder_out[39:16];

    // TODO make y div module

    // Instantiate the Unit Under Test (UUT)
    div_gen_x x_div_uut (
        .aclk(clk),
        .s_axis_divisor_tdata(x_denom),
        .s_axis_divisor_tvalid(x_denom_valid),
        .s_axis_dividend_tdata(x_num),
        .s_axis_dividend_tvalid(x_num_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out),
        .m_axis_dout_tvalid(x_div_out_valid)
    );

    always_ff @(posedge clk_65mhz) begin
        // update buffer_frame_done_out
        buffer_frame_done_out <= frame_done_out;

        // on falling edge of frame_done_out, update final_num_pixels_in_spot
        // and reset count_num_pixels_in_spot to 0
        if (buffer_frame_done_out && !frame_done_out) begin
            final_num_pixels_in_spot <= count_num_pixels_in_spot;
            count_num_pixels_in_spot <= 0;
        end

        // if valid pixel and (R,G,B) >= some threshhold,
        // increment count_num_pixels_in_spot, add hcount to x_coord_sum,
        // and add vcount to y_coord_sum
        if (valid_pixel && processed_pixels[11:8]>10 && 
                processed_pixels[7:4]>10 && processed_pixels[3:0]>10) begin
            count_num_pixels_in_spot <= count_num_pixels_in_spot + 1;
            x_coord_sum <= x_coord_sum + hcount;
            y_coord_sum <= y_coord_sum + vcount;
        end
    end

    // screen display variables
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    logic xclk;
    logic[1:0] xclk_count;
    assign xclk = (xclk_count >2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;

    // plus sign (draw blue pixel if at x and/or y coordinate
    // of LED IR spot
    logic [11:0] plus_target;
    assign plus_target = 12'hF00 ? (hcount==50 || vcount==50) : 12'h000;
    
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
        //old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;
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
            // if plus is there, display plus
            if (plus_target != 0) begin
                rgb <= plus_target;
            // else display camera output
            end else begin
                rgb <= cam;
            end
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

