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
    logic end_of_motion; // true at end of every 16 frames
    logic [3:0] frame_tally; // counts to 16 frames then resets
    // displacement of p1 and p2 over 16 frames; signed variables
    logic [8:0] p1_dx, p1_dy, p2_dx, p2_dy; // sometimes invalid
    logic [8:0] final_p1_dx, final_p1_dy, final_p2_dx, final_p2_dy; // always valid
    logic delta_values_valid; // true when p1_dx, etc. are valid

    // camera variables
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [7:0] pixel_buff, pixel_in;
    logic [15:0] output_pixels;
    logic [11:0] processed_pixels;
    logic valid_pixel;
    logic frame_done_out;
    logic buffer_frame_done_out; // delayed frame_done_out
    logic after_frame_before_first_pixel;

    // screen display variables
    // x value of pixel being displayed (pixel on current line)
    wire [10:0] hcount;
    // y value of pixel being displayed (line number)
    wire [9:0] vcount;
    // keep track of whether (hcount,vcount) is on or off the screen
    wire hsync, vsync, blank; // synchronized values
    // un-synchronized; outputs of screen module
    wire hsync_prev, vsync_prev, blank_prev;
    reg [11:0] rgb;    
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    logic xclk;
    logic[1:0] xclk_count;

    // track player 1 LED (RED)
    logic [15:0] count_num_pixels_for_p1; // sometimes invalid
    logic [15:0] final_num_pixels_for_p1; // final (valid) value
    logic [23:0] x_coord_sum_for_p1, y_coord_sum_for_p1;
    // track player 2 LED (IR LED)
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
    // location of p1 and p2
    // target that tracks p1
    logic [11:0] target_p1;
    logic [8:0] x_coord_of_p1;
    logic [7:0] y_coord_of_p1;
    // target that tracks p2
    logic [11:0] target_p2;
    logic [8:0] x_coord_of_p2;
    logic [7:0] y_coord_of_p2;

    // timer variables
    logic start;
    logic [3:0] value;
    logic counting, expired_pulse, one_hz;
    logic [3:0] count_out;

    // hex display: (p2_dx, p2_dy, p1_dx, p1_dy)
    logic [31:0] display_data;
    // 7-segment display; display (8) 4-bit hex
    logic [6:0] segments;
    logic [15:0] hold_led_vals;

    // LOGIC

    // set final delta values when p1_dx, etc. are valid
    always @(posedge clk_65mhz) begin
        if (delta_values_valid) begin
            final_p1_dx <= p1_dx;
            final_p1_dy <= p1_dy;
            final_p2_dx <= p2_dx;
            final_p2_dy <= p2_dy;
        end
    end
    
    // negative numbers converted to positive numbers for display
    // if val positive, leds under hex value lit up; otherwise dark
    assign led = hold_led_vals;
    always_comb begin
        if (final_p2_dx[8]) begin // if p2 moved left 
            hold_led_vals[13:12] = 2'b00;
            display_data[31:24] = ~(final_p2_dx - 1);
        end else begin // if p2 moved right
            hold_led_vals[13:12] = 2'b11;
            display_data[31:24] = final_p2_dx;
        end
        if (final_p2_dy[8]) begin // if p2 moved up (y decr.)
            hold_led_vals[11:9] = 3'b000;
            display_data[23:16] = ~(final_p2_dy - 1);
        end else begin // if p2 moved down (y incr.)
            hold_led_vals[11:9] = 3'b111;
            display_data[23:16] = final_p2_dy;
        end
        if (final_p1_dx[8]) begin // if p1 moved left
            hold_led_vals[8:7] = 2'b00;
            display_data[15:8] = ~(final_p1_dx - 1);
        end else begin // if p1 moved right
            hold_led_vals[8:7] = 2'b11;
            display_data[15:8] = final_p1_dx;
        end
        if (final_p1_dy[8]) begin // if p1 moved up (y decr.)
            hold_led_vals[6:4] = 3'b000;
            display_data[7:0] = ~(final_p1_dy - 1);
        end else begin // if p1 moved down (y incr.)
            hold_led_vals[6:4] = 3'b111;
            display_data[7:0] = final_p1_dy;
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
    assign processed_pixels = {output_pixels[15:12],
            output_pixels[10:7], output_pixels[4:1]};
    
    // TRACK LEDS

    // p1 extract solutions (w/o remainder) from output of ip divider
    assign x_div_out_p1 = x_div_and_remainder_out_p1[39:16];
    assign y_div_out_p1 = y_div_and_remainder_out_p1[39:16];
    // p2 extract solutions (w/o remainder) from output of ip divider
    assign x_div_out_p2 = x_div_and_remainder_out_p2[39:16];
    assign y_div_out_p2 = y_div_and_remainder_out_p2[39:16];

    // update x + y coords of p1 + p2 when output of div ip is valid
    always_ff @(posedge clk_65mhz) begin
        if (x_div_out_valid_p1) x_coord_of_p1 <= x_div_out_p1;
        if (y_div_out_valid_p1) y_coord_of_p1 <= y_div_out_p1;
        if (x_div_out_valid_p2) x_coord_of_p2 <= x_div_out_p2;
        if (y_div_out_valid_p2) y_coord_of_p2 <= y_div_out_p2;
    end

    // DIVIDERS
    // ignore the output when final_num_pixels_in_spot is 0
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

    // only display target p1 if there are bright p1-colored pixels
    assign target_p1 = (final_num_pixels_for_p1 && 
            (hcount==x_coord_of_p1 || 
             vcount==y_coord_of_p1)) ? 12'hF00 : 12'h000;

    // only display target p2 if there are bright p2-colored pixels
    assign target_p2 = (final_num_pixels_for_p2 && 
            (hcount==x_coord_of_p2 || 
             vcount==y_coord_of_p2)) ? 12'hFFF : 12'h000;
    
    // after every 16 frames, use p1_dx, etc. variables to determine
    // the action of p1 and p2
    assign end_of_motion = (frame_tally == 15);

    always_ff @(posedge clk_65mhz) begin
        buffer_frame_done_out <= frame_done_out;

        if (frame_done_out) frame_tally <= 1;

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

        // player 1 LED (RED)
        if (valid_pixel && cam[11:8]>13 && cam[7:4]<3 && cam[3:0]<3) begin
            count_num_pixels_for_p1 <= count_num_pixels_for_p1 + 1;
            x_coord_sum_for_p1 <= x_coord_sum_for_p1 + hcount;
            y_coord_sum_for_p1 <= y_coord_sum_for_p1 + vcount;
        // player 2 LED (IR LED (WHITE))
        end else if (valid_pixel && cam[11:8]>12 && cam[7:4]>12 && cam[3:0]>12) begin
            count_num_pixels_for_p2 <= count_num_pixels_for_p2 + 1;
            x_coord_sum_for_p2 <= x_coord_sum_for_p2 + hcount;
            y_coord_sum_for_p2 <= y_coord_sum_for_p2 + vcount;
        end
    end

    // screen display
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
        //old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;
    end

    // disable sw[2] making display larger // if sw[2] on, make display larger
    /*assign pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign cam = sw[2]&&((hcount<640)&&(vcount<480)) ? frame_buff_out :
        ~sw[2]&&((hcount<320)&&(vcount<240)) ? frame_buff_out : 12'h000;*/
    assign pixel_addr_out = hcount+vcount*32'd320;
    assign cam = ((hcount<320)&&(vcount<240)) ? frame_buff_out : 12'h000;
                                        
    // camera module
    camera_read  my_camera(
          .p_clock_in(pclk_in),
          .vsync_in(vsync_in),
          .href_in(href_in),
          .p_data_in(pixel_in),
          .pixel_data_out(output_pixels),
          .pixel_valid_out(valid_pixel),
          .frame_done_out(frame_done_out)
        );

    // create border around screen
    wire border = (hcount==0 | hcount==1023 | vcount==0 | vcount==767 |
                   hcount == 512 | vcount == 384);

    // set pixel_out
    always_ff @(posedge clk_65mhz) begin
        // debugging: make sure screen is working
        if (sw[1:0] == 2'b01) begin
            // 1 pixel outline of visible area (white)
            rgb <= {12{border}};
        end else if (sw[1:0] == 2'b10) begin
            // color bars
            rgb <= {{4{hcount[8]}}, {4{hcount[7]}}, {4{hcount[6]}}} ;
        // else if target p1 is there, display 
        end else if (target_p1 != 0) begin
            rgb <= target_p1;
        // else if target p2 is there, display 
        end else if (target_p2 != 0) begin
            rgb <= target_p2;
        // else display camera output
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
