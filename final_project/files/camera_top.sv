`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// camera_top_level module
//
//////////////////////////////////////////////////////////////////////////////////

module camera_top_module (
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

    // VARIABLES

    // state variables STATE VARIABLES
    logic [3:0] frame_tally; // counts to 16 frames then resets
    logic end_of_motion; // true at end of every 16 frames
    assign end_of_motion = (frame_tally == 15);
    // displacement of p1 and p2 over 16 frames; signed variables
    // 14 bits b/c log_2(num_frames=15) + log_2(max_coordinate=320) = 14
    logic [13:0] p1_dx, p1_dy, p2_dx, p2_dy; // sometimes invalid
    // always valid; magnitudes (unsigned values)
    logic [13:0] final_unsigned_p1_dx, final_unsigned_p1_dy; 
    logic [13:0] final_unsigned_p2_dx, final_unsigned_p2_dy;
    // always valid; 1=negative; 0=positive
    logic final_p1_dx_sign, final_p1_dy_sign;
    logic final_p2_dx_sign, final_p2_dy_sign;
    // true when p1_dx, etc., are valid
    logic delta_values_valid;

    // camera variables
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [7:0] pixel_buff, pixel_in;
    logic [15:0] output_pixels;
    logic [11:0] rgb_pixel;
    logic rgb_pixel_valid;
    logic frame_done_out;
    logic buffer_frame_done_out; // delayed frame_done_out
    logic after_frame_before_first_pixel;
    //logic [11:0] hsv_pixel;
    //logic hsv_pixel_valid;

    // screen display variables
    // x value of pixel being displayed (pixel on current line)
    wire [10:0] hcount, hcount_mirror;
    assign hcount_mirror = 319-hcount; // make camera display mirror image
    // y value of pixel being displayed (line number)
    wire [9:0] vcount;
    // keep track of whether (hcount,vcount) is on or off the screen
    wire hsync, vsync, blank; // synchronized values
    // un-synchronized; outputs of screen module
    wire hsync_prev, vsync_prev, blank_prev;
    reg [11:0] pixel_out;    
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    logic xclk;
    logic[1:0] xclk_count;

    // track player 1 LED 
    logic [15:0] count_num_pixels_for_p1; // sometimes invalid
    logic [15:0] final_num_pixels_for_p1; // final (valid) value
    logic [23:0] x_coord_sum_for_p1, y_coord_sum_for_p1;
    // track player 2 LED
    logic [15:0] count_num_pixels_for_p2; // sometimes invalid
    logic [15:0] final_num_pixels_for_p2; // final (valid) value
    logic [23:0] x_coord_sum_for_p2, y_coord_sum_for_p2;

    // player 1 + player 2 variables
    logic div_inputs_valid;
    // player 1 variables
    logic [39:0] x_div_and_remainder_out_p1, y_div_and_remainder_out_p1;
    logic [23:0] x_div_out_p1, y_div_out_p1;
    logic x_div_out_valid_p1, y_div_out_valid_p1;
    // player 2 variables
    logic [39:0] x_div_and_remainder_out_p2, y_div_and_remainder_out_p2;
    logic [23:0] x_div_out_p2, y_div_out_p2;
    logic x_div_out_valid_p2, y_div_out_valid_p2;
    // current + previous locations of p1 and p2
    // target that tracks p1
    logic [11:0] target_p1;
    logic [8:0] x_coord_of_p1, prev_x_coord_of_p1;
    logic [7:0] y_coord_of_p1, prev_y_coord_of_p1;
    // target that tracks p2
    logic [11:0] target_p2;
    logic [8:0] x_coord_of_p2, prev_x_coord_of_p2;
    logic [7:0] y_coord_of_p2, prev_y_coord_of_p2;
    // target that tracks sw
    //logic [11:0] target_sw;
    // hold pixel value under sw coord.
    //logic [11:0] sw_pixel_value;

    // timer variables
    logic start;
    logic [3:0] value;
    logic counting, expired_pulse, one_hz;
    logic [3:0] count_out;

    logic [31:0] display_data; // 8 hex display
    logic [6:0] segments; // 7-segment display
    logic [15:0] hold_led_vals;

    // LOGIC

    // display change in (x,y) of p2 + p1 on left + right hex sides of hex display
    assign display_data = {final_unsigned_p2_dx[7:0], final_unsigned_p2_dy[7:0],
            final_unsigned_p1_dx[7:0], final_unsigned_p1_dy[7:0]};
    // display change in num pixels of p2 + p1 on left + right hex sides of hex display
    //assign display_data = {final_num_pixels_for_p2, final_num_pixels_for_p1};

    // light up if positive
    assign led[13:12] = ~final_p2_dx_sign ? 2'b11 : 2'b00;
    assign led[11:9] = ~final_p2_dy_sign ? 3'b111 : 3'b000;
    assign led[8:7] = ~final_p1_dx_sign ? 2'b11 : 2'b00;
    assign led[6:4] = ~final_p2_dy_sign ? 3'b111 : 3'b000;

    // set final delta values when p1_dx, etc. are valid
    // negative numbers converted to positive numbers for display
    // if val positive, leds under hex value lit up; otherwise dark
    always @(posedge clk_65mhz) begin
        if (delta_values_valid) begin
            if (p2_dx[13]) begin // if p2 moved left 
                final_unsigned_p2_dx <= ~(p2_dx - 1);
                final_p2_dx_sign <= 1;
            end else begin // if p2 moved right
                final_unsigned_p2_dx <= p2_dx;
                final_p2_dx_sign <= 0;
            end
            if (p2_dy[13]) begin // if p2 moved up (y decr.)
                final_unsigned_p2_dy <= ~(p2_dy - 1);
                final_p2_dy_sign <= 1;
            end else begin // if p2 moved down (y incr.)
                final_unsigned_p2_dy <= p2_dy;
                final_p2_dy_sign <= 0;
            end
            if (p1_dx[13]) begin // if p1 moved left
                final_unsigned_p1_dx <= ~(p1_dx - 1);
                final_p1_dx_sign <= 1;
            end else begin // if p1 moved right
                final_unsigned_p1_dx <= p1_dx;
                final_p1_dx_sign <= 0;
            end
            if (p1_dy[13]) begin // if p1 moved up (y decr.)
                final_unsigned_p1_dy <= ~(p1_dy - 1);
                final_p1_dy_sign <= 1;
            end else begin // if p1 moved down (y incr.)
                final_unsigned_p1_dy <= p1_dy;
                final_p1_dy_sign <= 0;
            end
        end
    end
    
    // hex display 
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    assign dp = 1'b1;  // turn off the period
    display_8hex display(
            .clk_in(clk_65mhz),
            .data_in(display_data), 
            .seg_out(segments), 
            .strobe_out(an)
    );
    
    // timer
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
    
    // CAMERA
    assign rgb_pixel = {output_pixels[15:12],
            output_pixels[10:7], output_pixels[4:1]};
    
    // TRACK LEDS

    // p1 extract solutions (w/o remainder) from output of ip divider
    assign x_div_out_p1 = x_div_and_remainder_out_p1[39:16];
    assign y_div_out_p1 = y_div_and_remainder_out_p1[39:16];
    // p2 extract solutions (w/o remainder) from output of ip divider
    assign x_div_out_p2 = x_div_and_remainder_out_p2[39:16];
    assign y_div_out_p2 = y_div_and_remainder_out_p2[39:16];

    // update coords of p1 + p2 & prev coords of p1 + p2
    // when output of div ip is valid
    always_ff @(posedge clk_65mhz) begin
        if (x_div_out_valid_p1) begin
            x_coord_of_p1 <= x_div_out_p1;
            prev_x_coord_of_p1 <= x_coord_of_p1;
        end
        if (y_div_out_valid_p1) begin
            y_coord_of_p1 <= y_div_out_p1;
            prev_y_coord_of_p1 <= y_coord_of_p1;
        end
        if (x_div_out_valid_p2) begin
            x_coord_of_p2 <= x_div_out_p2;
            prev_x_coord_of_p2 <= x_coord_of_p2;
        end
        if (y_div_out_valid_p2) begin
            y_coord_of_p2 <= y_div_out_p2;
            prev_y_coord_of_p2 <= y_coord_of_p2;
        end
    end

    // DIVIDERS
    // ignore the output when final_num_pixels_for_p# is 0
    // (i.e. division by 0)

    // player 1 dividers
    div_gen_y y_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p1),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(y_coord_sum_for_p1),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(y_div_and_remainder_out_p1),
        .m_axis_dout_tvalid(y_div_out_valid_p1)
    );
    div_gen_x x_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p1),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(x_coord_sum_for_p1),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p1),
        .m_axis_dout_tvalid(x_div_out_valid_p1)
    );

    // player 2 dividers
    div_gen_y2 y2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p2),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(y_coord_sum_for_p2),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(y_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(y_div_out_valid_p2)
    );
    div_gen_x2 x2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p2),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(x_coord_sum_for_p2),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(x_div_out_valid_p2)
    );

    // move targets to follow p1 led & p2 led
    // only display target p1 if there are bright p1-colored pixels
    assign target_p1 = (final_num_pixels_for_p1 && 
            (hcount_mirror==x_coord_of_p1 || 
             vcount==y_coord_of_p1)) ? 12'hF00 : 12'h000;

    // only display target p2 if there are bright p2-colored pixels
    assign target_p2 = (final_num_pixels_for_p2 && 
            (hcount_mirror==x_coord_of_p2 || 
             vcount==y_coord_of_p2)) ? 12'hFFF : 12'h000;

    // move target to follow sw & display pixel value under target
    /*assign target_sw = (hcount_mirror==sw[7:0] || vcount==sw[15:8]) ?
            12'hFFF : 12'h000;
    assign display_data = sw_pixel_value;
    
    always_comb begin
        if (sw[15:8]==hcount_mirror && sw[7:0]==vcount) begin
            sw_pixel_value = cam;
        end
    end*/

    always_ff @(posedge clk_65mhz) begin
        buffer_frame_done_out <= frame_done_out;
        if (frame_done_out) frame_tally <= frame_tally + 1;

        // delta values valid after every 16 frames
        if (end_of_motion) begin
            delta_values_valid <= 1;
        // reset values to 0 after extracting final delta values
        end else if (delta_values_valid) begin
            delta_values_valid <= 0;
            p1_dx <= 0;
            p1_dy <= 0;
            p2_dx <= 0;
            p2_dy <= 0;
        // else update p1_dx, etc.
        end else begin
            p1_dx <= p1_dx + (x_coord_of_p1 - prev_x_coord_of_p1);
            p1_dy <= p1_dy + (y_coord_of_p1 - prev_y_coord_of_p1);
            p2_dx <= p2_dx + (x_coord_of_p2 - prev_x_coord_of_p2);
            p2_dy <= p2_dy + (y_coord_of_p2 - prev_y_coord_of_p2);
        end

        // on falling edge of frame_done_out, update final pixel count
        // for p1 and p2 and set div_inputs_valid to true
        if (buffer_frame_done_out && !frame_done_out) begin
            final_num_pixels_for_p1 <= count_num_pixels_for_p1;
            final_num_pixels_for_p2 <= count_num_pixels_for_p2;
            div_inputs_valid <= 1;
        end else if (div_inputs_valid) begin
            // reset values to 0 after calculating quotient
            div_inputs_valid <= 0;
            count_num_pixels_for_p1 <= 0;
            count_num_pixels_for_p2 <= 0;
            x_coord_sum_for_p1 <= 0;
            y_coord_sum_for_p1 <= 0;
            x_coord_sum_for_p2 <= 0;
            y_coord_sum_for_p2 <= 0;
        end

        // if valid pixel and (RGB value being displayed on screen at
        // (hcount, vcount) > some threshhold), increment count_num_pixels_in_spot, 
        // add hcount (x value of pixel being drawn on screen) to x_coord_sum, 
        // and add vcount (y value of pixel being drawn on screen) to y_coord_sum

        // TODO HERE

        // detect LEDS
        // player 1 LED (red LED)
        if (rgb_pixel_valid && cam[11:8]>12 && cam[7:4]<3 && cam[3:0]<3) begin
            count_num_pixels_for_p1 <= count_num_pixels_for_p1 + 1;
            x_coord_sum_for_p1 <= x_coord_sum_for_p1 + hcount_mirror;
            y_coord_sum_for_p1 <= y_coord_sum_for_p1 + vcount;
        // player 2 LED (IR LED (white))
        end else if (rgb_pixel_valid && cam[11:8]>12 && cam[7:4]>12 && cam[3:0]>12) begin
            count_num_pixels_for_p2 <= count_num_pixels_for_p2 + 1;
            x_coord_sum_for_p2 <= x_coord_sum_for_p2 + hcount_mirror;
            y_coord_sum_for_p2 <= y_coord_sum_for_p2 + vcount;
        end
    end

    // screen display
    assign xclk = (xclk_count > 2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;

    // memory holding the image from the camera
    blk_mem_gen_0 jojos_bram(.addra(pixel_addr_in), 
                             .clka(pclk_in),
                             .dina(rgb_pixel),
                             .wea(rgb_pixel_valid),
                             .addrb(pixel_addr_out),
                             .clkb(clk_65mhz),
                             .doutb(frame_buff_out));
    
    // update pixel address as displaying pixels across the screen
    always_ff @(posedge pclk_in) begin
        if (frame_done_out)begin
            pixel_addr_in <= 17'b0;  
        end else if (rgb_pixel_valid)begin
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

    // disable sw[2] making display larger // if sw[2] on, make display larger
    /*assign pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign cam = sw[2]&&((hcount<640)&&(vcount<480)) ? frame_buff_out :
        ~sw[2]&&((hcount<320)&&(vcount<240)) ? frame_buff_out : 12'h000;*/
    assign pixel_addr_out = hcount_mirror+vcount*32'd320;
    assign cam = ((hcount_mirror<320)&&(vcount<240)) ? frame_buff_out : 12'h000;

    // rgb to hsv module
    /*rgb2hsv rgb2hsv_unit (
            .clock(clk_65mhz),
            .rgb_inputs_valid(rgb_pixel_valid), 
            .r(rgb_pixel[11:8]), .g(rgb_pixel[7:4]), .b(rgb_pixel[3:0]),
            .h(hsv_pixel[11:8]), .s(hsv_pixel[7:4]), .v(hsv_pixel[3:0]),
            .hsv_valid(hsv_pixel_valid)
        );*/
                                        
    // camera module
    camera_read  my_camera(
          .p_clock_in(pclk_in),
          .vsync_in(vsync_in),
          .href_in(href_in),
          .p_data_in(pixel_in),
          .pixel_data_out(output_pixels),
          .pixel_valid_out(rgb_pixel_valid),
          .frame_done_out(frame_done_out)
        );

    // create border around screen
    wire border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);

    // set pixel_out
    always_ff @(posedge clk_65mhz) begin
        /*
        // debugging: make sure screen is working
        if (sw[1:0] == 2'b01) begin
            // 1 pixel outline of visible area (white)
            pixel_out <= {12{border}};
        end else if (sw[1:0] == 2'b10) begin
            // color bars
            pixel_out <= {{4{hcount[8]}}, {4{hcount[7]}}, {4{hcount[6]}}} ;
        */
        // if target sw is there, display 
        /*if (target_sw != 0) begin
            pixel_out <= target_sw;
        // else if target p1 is there, display*/
        if (target_p1 != 0) begin
            pixel_out <= target_p1;
        // else if target p2 is there, display 
        end else if (target_p2 != 0) begin
            pixel_out <= target_p2;
        // else display camera output
        end else begin
            pixel_out <= cam;
        end
    end

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
