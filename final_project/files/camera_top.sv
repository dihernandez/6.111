`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// camera_top_level module
//
//////////////////////////////////////////////////////////////////////////////////

module camera_top_module (
        input clk_65mhz,
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
        output[7:0] an,    // Display location 0-7
        // 1=user action true; 0=user action false
        output logic p1_punch, p1_kick, p1_move_forwards, p1_move_backwards,
        output logic p2_punch, p2_kick, p2_move_forwards, p2_move_backwards
    );

    // VARIABLES

    // camera variables
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [7:0] pixel_buff, pixel_in;
    logic [15:0] output_pixels;
    logic [11:0] rgb_pixel;
    logic rgb_pixel_valid;
    logic frame_done_out;
    logic buffer_frame_done_out; // delayed frame_done_out
    logic rising_edge_frame_done_out;
    logic falling_edge_frame_done_out;
    assign rising_edge_frame_done_out = !buffer_frame_done_out && frame_done_out;
    assign falling_edge_frame_done_out= buffer_frame_done_out && !frame_done_out;
    logic after_frame_before_first_pixel;

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

    // state variables STATE VARIABLES
    logic [2:0] frame_tally; // counts to 8 frames then resets
    logic end_of_motion; // true at end of every 8 frames
    assign end_of_motion = (frame_tally == 7);

    // track player 1 + player 2 LEDs
    // calculate size of player LEDs
    logic [15:0] count_num_pixels_for_p1, count_num_pixels_for_p2; // sometimes invalid
    logic [15:0] final_num_pixels_for_p1, final_num_pixels_for_p2; // final (valid) value
    logic [15:0] prev_final_num_pixels_for_p1, prev_final_num_pixels_for_p2;
    logic [23:0] p1_x_coord_sum, p1_y_coord_sum, p2_x_coord_sum, p2_y_coord_sum;
    // calculate LED size change over 2 frames
    logic [8:0] p1_2frame_size_delta, p2_2frame_size_delta; // change in LED size over 2 frames
    logic p1_2frame_size_delta_sign, p2_2frame_size_delta_sign; // 1=neg; 0=pos
    // calculate LED size change over 8 frames
    logic [12:0] p1_8frame_size_delta, p2_8frame_size_delta; // change in LED size over 8 frames
    logic p1_8frame_size_delta_sign, p2_8frame_size_delta_sign; // 1=neg; 0=pos
    // calculate LED displacement over 2 frames
    logic [8:0] p1_2frame_dx, p1_2frame_dy, p2_2frame_dx, p2_2frame_dy;
    logic p1_2frame_dx_sign, p1_2frame_dy_sign; // 1=neg; 0=pos
    logic p2_2frame_dx_sign, p2_2frame_dy_sign; // 1=neg; 0=pos
    // calculate LED displacement over 8 frames
    logic [12:0] p1_8frame_dx, p1_8frame_dy, p2_8frame_dx, p2_8frame_dy;
    logic p1_8frame_dx_sign, p1_8frame_dy_sign; // 1=neg; 0=pos
    logic p2_8frame_dx_sign, p2_8frame_dy_sign; // 1=neg; 0=pos
    // true when LED size change and LED displacement over 8 frames are valid
    logic delta_8frame_values_valid;
    logic reset_8frame_delta_values;

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

    // timer variables
    logic start;
    logic [3:0] value;
    logic counting, expired_pulse, one_hz;
    logic [3:0] count_out;

    logic [31:0] display_data; // 8 hex display
    logic [6:0] segments; // 7-segment display
    logic [15:0] hold_led_vals;
    assign led = hold_led_vals;
    // determine if player made action
    // RED = punch; GREEN = kick
    assign led16_r = p1_punch;
    assign led16_g = p1_kick;
    assign led17_r = p2_punch;
    assign led17_g = p2_kick;

    // LOGIC
    parameter PUNCH_DX_MIN = 'h40;
    parameter PUNCH_DY_MAX = 'h30;
    parameter KICK_DY_MIN = 'h40;
    parameter KICK_DX_MAX = 'h30;

    always_comb begin
        if (delta_8frame_values_valid) begin
            // for debugging: hex display and leds under hex display
            // left=p2, right=p1
            display_data = {3'b000, p2_8frame_size_delta[12:0], 3'b000, p1_8frame_size_delta[15:0]};

            // light up leds under delta values if positive
            hold_led_vals[13:9] = ~p2_8frame_size_delta_sign ? 5'b11111 : 0;
            hold_led_vals[8:4] = ~p1_8frame_dx_sign ? 5'b11111 : 0;

            // get move forwards/backwards, kick, + punch actions
            // player 1
            if (p1_8frame_size_delta > 20) begin
                p1_move_forwards = p1_8frame_size_delta_sign;
                p1_move_backwards = !p1_8frame_size_delta_sign;
                p1_punch = 0;
                p1_kick = 0;
            end else begin
                p1_move_forwards = 0;
                p1_move_backwards = 0;
                p1_punch = (p1_8frame_dx > PUNCH_DX_MIN) && (p1_8frame_dy < PUNCH_DY_MAX);
                p1_kick = (p1_8frame_dy > KICK_DY_MIN) && (p1_8frame_dx < KICK_DX_MAX);
            end
            // player 2
            if (p2_8frame_size_delta > 20) begin
                p2_move_forwards = p2_8frame_size_delta_sign;
                p2_move_backwards = !p2_8frame_size_delta_sign;
                p2_punch = 0;
                p2_kick = 0;
            end else begin
                p2_move_forwards = 0;
                p2_move_backwards = 0;
                p2_punch = (p2_8frame_dx > PUNCH_DX_MIN) && (p2_8frame_dy < PUNCH_DY_MAX);
                p2_kick = (p2_8frame_dy > KICK_DY_MIN) && (p2_8frame_dx < KICK_DX_MAX);
            end
        end
    end

    // draw squares
    logic [11:0] p1_square_pixel;
    logic [11:0] p2_square_pixel;
    square sq_p1 (
            .player(1), // 1 = player 1
            .punch(p1_punch),
            .kick(p1_kick),
            .forwards(p1_move_forwards),
            .backwards(p1_move_backwards),
            .hcount_in(hcount),
            .vcount_in(vcount),
            .pixel_out(p1_square_pixel)
        );

    square sq_p2 (
            .player(0), // 0 = player 2
            .kick(p2_kick),
            .punch(p2_punch),
            .forwards(p2_move_forwards),
            .backwards(p2_move_backwards),
            .hcount_in(hcount),
            .vcount_in(vcount),
            .pixel_out(p2_square_pixel)
        );

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
        .s_axis_dividend_tdata(p1_y_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(y_div_and_remainder_out_p1),
        .m_axis_dout_tvalid(y_div_out_valid_p1)
    );
    div_gen_x x_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p1),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p1_x_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p1),
        .m_axis_dout_tvalid(x_div_out_valid_p1)
    );

    // player 2 dividers
    div_gen_y2 y2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p2),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p2_y_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(y_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(y_div_out_valid_p2)
    );
    div_gen_x2 x2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(final_num_pixels_for_p2),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p2_x_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(x_div_out_valid_p2)
    );

    // move targets to follow p1 led & p2 led
    // only display target p1 if there are bright p1-colored pixels
    assign target_p1 = (final_num_pixels_for_p1>5 && 
            (hcount_mirror==x_coord_of_p1 || 
             vcount==y_coord_of_p1)) ? 12'hF00 : 12'h000;

    // only display target p2 if there are bright p2-colored pixels
    assign target_p2 = (final_num_pixels_for_p2>5 && 
            (hcount_mirror==x_coord_of_p2 || 
             vcount==y_coord_of_p2)) ? 12'hFFF : 12'h000;

    // calc. sign and delta over 2 frames
    always_comb begin
        // 2frame change in position 
        // signs (1=neg., 0=pos.)
        p1_2frame_dx_sign = (prev_x_coord_of_p1 > x_coord_of_p1);
        p1_2frame_dy_sign = (prev_y_coord_of_p1 > y_coord_of_p1);
        p2_2frame_dx_sign = (prev_x_coord_of_p2 > x_coord_of_p2);
        p2_2frame_dy_sign = (prev_y_coord_of_p2 > y_coord_of_p2);
        // magnitudes
        if (p1_2frame_dx_sign) p1_2frame_dx = prev_x_coord_of_p1 - x_coord_of_p1;
        else p1_2frame_dx = x_coord_of_p1 - prev_x_coord_of_p1;
        if (p1_2frame_dy_sign) p1_2frame_dy = prev_y_coord_of_p1 - y_coord_of_p1;
        else p1_2frame_dy = y_coord_of_p1 - prev_y_coord_of_p1;
        if (p2_2frame_dx_sign) p2_2frame_dx = prev_x_coord_of_p2 - x_coord_of_p2;
        else p2_2frame_dx = x_coord_of_p2 - prev_x_coord_of_p2;
        if (p2_2frame_dy_sign) p2_2frame_dy = prev_y_coord_of_p2 - y_coord_of_p2;
        else p2_2frame_dy = y_coord_of_p2 - prev_y_coord_of_p2;

        // 2frame change in size 
        // signs (1=neg., 0=pos.)
        p1_2frame_size_delta_sign = (prev_final_num_pixels_for_p1 > final_num_pixels_for_p1);
        p2_2frame_size_delta_sign = (prev_final_num_pixels_for_p2 > final_num_pixels_for_p2);
        // magnitudes
        if (p1_2frame_size_delta_sign) begin
            p1_2frame_size_delta = prev_final_num_pixels_for_p1 - final_num_pixels_for_p1;
        end else begin
            p1_2frame_size_delta = final_num_pixels_for_p1 - prev_final_num_pixels_for_p1;
        end
        if (p2_2frame_size_delta_sign) begin
            p2_2frame_size_delta = prev_final_num_pixels_for_p2 - final_num_pixels_for_p2;
        end else begin
            p2_2frame_size_delta = final_num_pixels_for_p2 - prev_final_num_pixels_for_p2;
        end
    end

    always_ff @(posedge clk_65mhz) begin
        buffer_frame_done_out <= frame_done_out;
        if (rising_edge_frame_done_out) frame_tally <= frame_tally + 1;

        // delta values valid after every 8 frames
        if (end_of_motion) begin
            delta_8frame_values_valid <= 1;
        // reset values to 0 after extracting final delta values
        end else if (delta_8frame_values_valid) begin
            reset_8frame_delta_values <= 1;
            delta_8frame_values_valid <= 0;
        end else if (reset_8frame_delta_values) begin
            reset_8frame_delta_values <= 0;
            p1_8frame_dx <= 0;
            p1_8frame_dy <= 0;
            p2_8frame_dx <= 0;
            p2_8frame_dy <= 0;
            p1_8frame_size_delta <= 0;
            p2_8frame_size_delta <= 0;
        // else if new frame, calculate change in LED pos. and size over 8 frames
        end else if (rising_edge_frame_done_out) begin
            // update dx of p1 LED over 8 frames 
            if (p1_8frame_dx_sign==p1_2frame_dx_sign) begin
                // same sign => add
                p1_8frame_dx <= p1_8frame_dx + p1_2frame_dx;
                p1_8frame_dx_sign <= p1_8frame_dx_sign;
            end else begin
                // diff. sign => subtract smaller value
                if (p1_8frame_dx > p1_2frame_dx) begin
                    p1_8frame_dx <= p1_8frame_dx - p1_2frame_dx;
                    p1_8frame_dx_sign <= p1_8frame_dx_sign;
                end else begin
                    p1_8frame_dx <= p1_2frame_dx - p1_8frame_dx;
                    p1_8frame_dx_sign <= p1_2frame_dx_sign;
                end
            end
                    
            // update dy of p1 LED over 8 frames 
            if (p1_8frame_dy_sign==p1_2frame_dy_sign) begin
                // same sign => add
                p1_8frame_dy <= p1_8frame_dy + p1_2frame_dy;
                p1_8frame_dy_sign <= p1_8frame_dy_sign;
            end else begin
                // diff. sign => subtract smaller value
                if (p1_8frame_dy > p1_2frame_dy) begin
                    p1_8frame_dy <= p1_8frame_dy - p1_2frame_dy;
                    p1_8frame_dy_sign <= p1_8frame_dy_sign;
                end else begin
                    p1_8frame_dy <= p1_2frame_dy - p1_8frame_dy;
                    p1_8frame_dy_sign <= p1_2frame_dy_sign;
                end
            end
            
            // update dx of p2 LED over 8 frames 
            if (p2_8frame_dx_sign==p2_2frame_dx_sign) begin
                // same sign => add
                p2_8frame_dx <= p2_8frame_dx + p2_2frame_dx;
                p2_8frame_dx_sign <= p2_8frame_dx_sign;
            end else begin
                // diff. sign => subtract
                if (p2_8frame_dx > p2_2frame_dx) begin
                    p2_8frame_dx <= p2_8frame_dx - p2_2frame_dx;
                    p2_8frame_dx_sign <= p2_8frame_dx_sign;
                end else begin
                    p2_8frame_dx <= p2_2frame_dx - p2_8frame_dx;
                    p2_8frame_dx_sign <= p2_2frame_dx_sign;
                end
            end
                    
            // update dy of p2 LED over 8 frames 
            if (p2_8frame_dy_sign==p2_2frame_dy_sign) begin
                p2_8frame_dy <= p2_8frame_dy + p2_2frame_dy;
                p2_8frame_dy_sign <= p2_8frame_dy_sign;
            end else begin
                if (p2_8frame_dy > p2_2frame_dy) begin
                    p2_8frame_dy <= p2_8frame_dy - p2_2frame_dy;
                    p2_8frame_dy_sign <= p2_8frame_dy_sign;
                end else begin
                    p2_8frame_dy <= p2_2frame_dy - p2_8frame_dy;
                    p2_8frame_dy_sign <= p2_2frame_dy_sign;
                end
            end

            // update size change of p1 LED over 8 frames
            if (p1_2frame_size_delta_sign==p1_8frame_size_delta_sign) begin
                p1_8frame_size_delta <= p1_8frame_size_delta + p1_2frame_size_delta; 
                p1_8frame_size_delta_sign <= p1_8frame_size_delta_sign;
            end else begin
                if (p1_8frame_size_delta > p1_2frame_size_delta) begin
                    p1_8frame_size_delta <= p1_8frame_size_delta - p1_2frame_size_delta; 
                    p1_8frame_size_delta_sign <= p1_8frame_size_delta_sign;
                end else begin
                    p1_8frame_size_delta <= p1_2frame_size_delta - p1_8frame_size_delta; 
                    p1_8frame_size_delta_sign <= p1_2frame_size_delta_sign;
                end
            end

            // update size change of p2 LED over 8 frames
            if (p2_2frame_size_delta_sign==p2_8frame_size_delta_sign) begin
                p2_8frame_size_delta <= p2_8frame_size_delta + p2_2frame_size_delta; 
                p2_8frame_size_delta_sign <= p2_8frame_size_delta_sign;
            end else begin
                if (p2_8frame_size_delta > p2_2frame_size_delta) begin
                    p2_8frame_size_delta <= p2_8frame_size_delta - p2_2frame_size_delta; 
                    p2_8frame_size_delta_sign <= p2_8frame_size_delta_sign;
                end else begin
                    p2_8frame_size_delta <= p2_2frame_size_delta - p2_8frame_size_delta; 
                    p2_8frame_size_delta_sign <= p2_2frame_size_delta_sign;
                end
            end
        end

        // on falling edge of frame_done_out, update final pixel count
        // for p1 and p2 and set div_inputs_valid to true
        if (falling_edge_frame_done_out) begin
            // update prev values
            prev_final_num_pixels_for_p1 <= final_num_pixels_for_p1;
            prev_final_num_pixels_for_p2 <= final_num_pixels_for_p2;
            // update current values
            final_num_pixels_for_p1 <= count_num_pixels_for_p1;
            final_num_pixels_for_p2 <= count_num_pixels_for_p2;
            div_inputs_valid <= 1;
        end else if (div_inputs_valid) begin
            // reset values to 0 after calculating quotient
            div_inputs_valid <= 0;
            count_num_pixels_for_p1 <= 0;
            count_num_pixels_for_p2 <= 0;
            p1_x_coord_sum <= 0;
            p1_y_coord_sum <= 0;
            p2_x_coord_sum <= 0;
            p2_y_coord_sum <= 0;
        end

        // if valid pixel and (RGB value being displayed on screen at
        // (hcount, vcount) > some threshhold), increment count_num_pixels_in_spot, 
        // add hcount (x value of pixel being drawn on screen) to x_coord_sum, 
        // and add vcount (y value of pixel being drawn on screen) to y_coord_sum

        // detect LEDS
        // player 1 LED (red LED)
        if (rgb_pixel_valid && cam[11:8]>11 && cam[7:4]<2 && cam[3:0]<2) begin
            count_num_pixels_for_p1 <= count_num_pixels_for_p1 + 1;
            p1_x_coord_sum <= p1_x_coord_sum + hcount_mirror;
            p1_y_coord_sum <= p1_y_coord_sum + vcount;
        // player 2 LED (IR LED (white))
        end else if (rgb_pixel_valid && cam[11:8]>13 && cam[7:4]>13 && cam[3:0]>13) begin
            count_num_pixels_for_p2 <= count_num_pixels_for_p2 + 1;
            p2_x_coord_sum <= p2_x_coord_sum + hcount_mirror;
            p2_y_coord_sum <= p2_y_coord_sum + vcount;
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
        if (frame_done_out) begin
            pixel_addr_in <= 17'b0;  
        end else if (rgb_pixel_valid)begin
            pixel_addr_in <= pixel_addr_in +1;  
        end
    end
    
    // update screen variables
    always_ff @(posedge clk_65mhz) begin
        // flow of data: jb[1] => vsync_buff => vsync_in
        // jb[0] => pclk_buff => pclk_in
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

    assign pixel_addr_out = hcount_mirror+vcount*32'd320;
    assign cam = ((hcount_mirror<320)&&(vcount<240)) ? frame_buff_out : 12'h000;

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
        // if target p1 is there, display*/
        if (target_p1 != 0) begin
            pixel_out <= target_p1;
        // else if target p2 is there, display 
        end else if (target_p2 != 0) begin
            pixel_out <= target_p2;
        // else display camera output
        end else if (cam != 0) begin
            pixel_out <= cam;
        // else draw p1 square
        end else if (p1_square_pixel) begin
            pixel_out <= p1_square_pixel;
        // else draw p2 square
        end else begin
            pixel_out <= p2_square_pixel;
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
