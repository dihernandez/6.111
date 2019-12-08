`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//
// camera_top_level module
//
//////////////////////////////////////////////////////////////////////////////////

module camera_top_module (
        //inputs
        input clk_65mhz,
        input[15:0] sw,
        input [7:0] ja,
        input [2:0] jb,
        input [2:0] jd,
        //outputs
        output logic jbclk,
        output logic jdclk,
        output logic hsync, vsync, blank,
        output logic [11:0] pixel_out,
        output logic [31:0] display_data, // goes to hex display; for debugging
        // 1=user action true; 0=user action false
        output logic p1_punch, p1_kick, p1_move_forwards, p1_move_backwards,
        output logic p2_punch, p2_kick, p2_move_forwards, p2_move_backwards,
        output logic [10:0] hcount,
        output logic [9:0] vcount
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
    wire [10:0] hcount_mirror;  //,hcount //CHANGED
    assign hcount_mirror = 319-hcount; // make camera display mirror image
    // keep track of whether (hcount,vcount) is on or off the screen
    // un-synchronized; outputs of screen module
    wire hsync_prev, vsync_prev, blank_prev;
    logic pclk_buff, pclk_in;
    logic vsync_buff, vsync_in;
    logic href_buff, href_in;
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    logic xclk;
    logic[1:0] xclk_count;

    // state variables STATE VARIABLES
    logic [2:0] eight_frame_tally; // counts to 8 frames then resets
    logic end_of_8_frames; // true at end of every 8 frames
    assign end_of_8_frames = (eight_frame_tally == 7);

    // track player 1 + player 2 LEDs
    // calculate size of player LEDs (number of LED pixels detected)
    //logic [15:0] p1_size, p2_size; // sometimes invalid
    //logic [15:0] p1_final_size, p2_final_size; // final (valid) value
    //logic [15:0] p1_prev_final_size, p2_prev_final_size; // 1 clock cycle ago
    logic [15:0] count_num_pixels_for_p1, count_num_pixels_for_p2; // sometimes invalid
    logic [15:0] final_num_pixels_for_p1, final_num_pixels_for_p2; // final (valid) value
    // sizes: 0=[x0,x50), 1=[x50,x100), 2=[x100,x400), 3=[x400,x800)
    logic [1:0] p1_final_size, p1_prev_final_size, p2_final_size, p2_prev_final_size; 
    // change in LED size over 2 and 8 frames
    //logic [16:0] p1_2frame_size_delta, p2_2frame_size_delta;
    //logic [18:0] p1_8frame_size_delta, p2_8frame_size_delta;
    logic [2:0] p1_2frame_size_delta, p2_2frame_size_delta;
    logic p1_2frame_size_delta_sign, p2_2frame_size_delta_sign; // 1=neg; 0=pos
    logic [5:0] p1_8frame_size_delta, p2_8frame_size_delta;
    logic p1_8frame_size_delta_sign, p2_8frame_size_delta_sign; // 1=neg; 0=pos
    // x and y coordinate sum for calculating centers of LEDs
    logic [23:0] p1_x_coord_sum, p1_y_coord_sum, p2_x_coord_sum, p2_y_coord_sum;
    // calculate LED displacement over 2 frames
    logic [8:0] p1_2frame_dx, p1_2frame_dy, p2_2frame_dx, p2_2frame_dy;
    logic p1_2frame_dx_sign, p1_2frame_dy_sign; // 1=neg; 0=pos
    logic p2_2frame_dx_sign, p2_2frame_dy_sign; // 1=neg; 0=pos
    // calculate LED displacement over 8 frames
    logic [12:0] p1_8frame_dx, p1_8frame_dy, p2_8frame_dx, p2_8frame_dy;
    logic p1_8frame_dx_sign, p1_8frame_dy_sign; // 1=neg; 0=pos
    logic p2_8frame_dx_sign, p2_8frame_dy_sign; // 1=neg; 0=pos
    // reset LED displacement values after 8 frames
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

    /*
    // convert (x,y) and size variables to unsigned variables
    // for low pass filter
    logic [13:0] p1_8frame_dx_unsigned, p1_8frame_dy_unsigned;
    logic [13:0] p2_8frame_dx_unsigned, p2_8frame_dy_unsigned;
    logic [19:0] p1_8frame_size_delta_unsigned;
    logic [19:0] p2_8frame_size_delta_unsigned;

    // max values
    parameter MAX_DX = 2000;
    parameter MAX_DY = 2000;
    parameter MAX_DSIZE = 50000;

    // shift up magnitude + sign variables by max value to make magnitude only
    always_comb begin
        if (end_of_8_frames) begin
            if (p1_8frame_dx_sign) begin // if negative
                p1_8frame_dx_unsigned = MAX_DX - p1_8frame_dx;
            end else begin
                p1_8frame_dx_unsigned = MAX_DX + p1_8frame_dx;
            end

            if (p1_8frame_dy_sign) begin // if negative
                p1_8frame_dy_unsigned = MAX_DY - p1_8frame_dy; 
            end else begin
                p1_8frame_dy_unsigned = MAX_DY + p1_8frame_dy;
            end

            if (p1_8frame_size_delta_sign) begin // if negative
                p1_8frame_size_delta_unsigned = MAX_DSIZE - p1_8frame_size_delta;
            end else begin
                p1_8frame_size_delta_unsigned = MAX_DSIZE + p1_8frame_size_delta;
            end

            if (p2_8frame_dx_sign) begin // if negative
                p2_8frame_dx_unsigned = MAX_DX - p2_8frame_dx;
            end else begin
                p2_8frame_dx_unsigned = MAX_DX + p2_8frame_dx;
            end

            if (p2_8frame_dy_sign) begin // if negative
                p2_8frame_dy_unsigned = MAX_DY - p2_8frame_dy; 
            end else begin
                p2_8frame_dy_unsigned = MAX_DY + p2_8frame_dy;
            end

            if (p2_8frame_size_delta_sign) begin // if negative
                p2_8frame_size_delta_unsigned = MAX_DSIZE - p2_8frame_size_delta;
            end else begin
                p2_8frame_size_delta_unsigned = MAX_DSIZE + p2_8frame_size_delta;
            end
        end
    end
    */
    

    /*
    // iir low pass filter to reduce noise
    logic [13:0] prev_smooth_p1_8frame_dx_unsigned, prev_smooth_p1_8frame_dy_unsigned;
    logic [13:0] smooth_p1_8frame_dx_unsigned, smooth_p1_8frame_dy_unsigned;
    logic [19:0] prev_smooth_p1_8frame_size_delta_unsigned;
    logic [19:0] smooth_p1_8frame_size_delta_unsigned;
    iir_filter p1_iir_filter(
            // prev iir outputs
            .prev_dx_val_out(prev_smooth_p1_8frame_dx_unsigned),
            .prev_dy_val_out(prev_smooth_p1_8frame_dy_unsigned),
            .prev_delta_size_out(prev_smooth_p1_8frame_size_delta_unsigned),
            // current iir inputs
            .dx_val_in(p1_8frame_dx_unsigned), 
            .dy_val_in(p1_8frame_dy_unsigned), 
            .delta_size_in(p1_8frame_size_delta_unsigned),
            // iir outputs
            .dx_val_out(smooth_p1_8frame_dx_unsigned),
            .dy_val_out(smooth_p1_8frame_dy_unsigned),
            .delta_size_out(smooth_p1_8frame_size_delta_unsigned)
        );

    logic [12:0] prev_smooth_p2_8frame_dx_unsigned, prev_smooth_p2_8frame_dy_unsigned;
    logic [12:0] smooth_p2_8frame_dx_unsigned, smooth_p2_8frame_dy_unsigned;
    logic [18:0] prev_smooth_p2_8frame_size_delta_unsigned;
    logic [18:0] smooth_p2_8frame_size_delta_unsigned;
    iir_filter p2_iir_filter(
            // prev iir outputs
            .prev_dx_val_out(prev_smooth_p2_8frame_dx_unsigned),
            .prev_dy_val_out(prev_smooth_p2_8frame_dy_unsigned),
            .prev_delta_size_out(prev_smooth_p2_8frame_size_delta_unsigned),
            // current iir inputs
            .dx_val_in(p2_8frame_dx_unsigned), 
            .dy_val_in(p2_8frame_dy_unsigned), 
            .delta_size_in(p2_8frame_size_delta_unsigned),
            // iir outputs
            .dx_val_out(smooth_p2_8frame_dx_unsigned),
            .dy_val_out(smooth_p2_8frame_dy_unsigned),
            .delta_size_out(smooth_p2_8frame_size_delta_unsigned)
        );

    // convert magnitude only variables to magnitude + sign
    logic [12:0] final_smooth_p1_8frame_dx, final_smooth_p1_8frame_dy;
    logic final_smooth_p1_8frame_dx_sign, final_smooth_p1_8frame_dy_sign;
    logic [12:0] final_smooth_p2_8frame_dx, final_smooth_p2_8frame_dy;
    logic final_smooth_p2_8frame_dx_sign, final_smooth_p2_8frame_dy_sign;
    logic [18:0] final_smooth_p1_8frame_size_delta;
    logic final_smooth_p1_8frame_size_delta_sign;
    logic [18:0] final_smooth_p2_8frame_size_delta;
    logic final_smooth_p2_8frame_size_delta_sign;

    always_comb begin
        // buffer time for iir filter to finish
        //if (eight_frame_tally==0) begin
        if (end_of_8_frames) begin
            if (smooth_p1_8frame_dx_unsigned > MAX_DX) begin // if positive
                final_smooth_p1_8frame_dx = smooth_p1_8frame_dx_unsigned - MAX_DX;
                final_smooth_p1_8frame_dx_sign = 0;
            end else begin // else if negative
                final_smooth_p1_8frame_dx = MAX_DX - smooth_p1_8frame_dx_unsigned;
                final_smooth_p1_8frame_dx_sign = 1;
            end

            if (smooth_p1_8frame_dy_unsigned > MAX_DY) begin // if positive
                final_smooth_p1_8frame_dy = smooth_p1_8frame_dy_unsigned - MAX_DY;
                final_smooth_p1_8frame_dy_sign = 0;
            end else begin // else if negative
                final_smooth_p1_8frame_dy = MAX_DY - smooth_p1_8frame_dy_unsigned;
                final_smooth_p1_8frame_dy_sign = 1;
            end

            if (smooth_p1_8frame_size_delta_unsigned > MAX_DSIZE) begin // if positive
                final_smooth_p1_8frame_size_delta = smooth_p1_8frame_size_delta_unsigned - MAX_DSIZE;
                final_smooth_p1_8frame_size_delta_sign = 0;
            end else begin // else if negative
                final_smooth_p1_8frame_size_delta = MAX_DSIZE - smooth_p1_8frame_size_delta_unsigned;
                final_smooth_p1_8frame_size_delta_sign = 1;
            end

            if (smooth_p2_8frame_dx_unsigned > MAX_DX) begin // if positive
                final_smooth_p2_8frame_dx = smooth_p2_8frame_dx_unsigned - MAX_DX;
                final_smooth_p2_8frame_dx_sign = 0;
            end else begin // else if negative
                final_smooth_p2_8frame_dx = MAX_DX - smooth_p2_8frame_dx_unsigned;
                final_smooth_p2_8frame_dx_sign = 1;
            end

            if (smooth_p2_8frame_dy_unsigned > MAX_DY) begin // if positive
                final_smooth_p2_8frame_dy = smooth_p2_8frame_dy_unsigned - MAX_DY;
                final_smooth_p2_8frame_dy_sign = 0;
            end else begin // else if negative
                final_smooth_p2_8frame_dy = MAX_DY - smooth_p2_8frame_dy_unsigned;
                final_smooth_p2_8frame_dy_sign = 1;
            end

            if (smooth_p2_8frame_size_delta_unsigned > MAX_DSIZE) begin // if positive
                final_smooth_p2_8frame_size_delta = smooth_p2_8frame_size_delta_unsigned - MAX_DSIZE;
                final_smooth_p2_8frame_size_delta_sign = 0;
            end else begin // else if negative
                final_smooth_p2_8frame_size_delta = MAX_DSIZE - smooth_p2_8frame_size_delta_unsigned;
                final_smooth_p2_8frame_size_delta_sign = 1;
            end
        end
    end
    */

    // timer variables
    logic start;
    logic [3:0] value;
    logic counting, expired_pulse, one_hz;
    logic [3:0] count_out;

    // LOGIC
    // treshholds
    logic [7:0] PUNCH_DX_MIN, PUNCH_DY_MAX, KICK_DX_MAX, KICK_DY_MIN;
    logic [2:0] MIN_SIZE_DELTA;
    // punch: move LED in x direction
    /*assign PUNCH_DX_MIN = 'h40 + 'h5 * sw[15:13]; // use sw to calibrate threshholds
    assign PUNCH_DY_MAX = 'h10 + 'h5 * sw[12:11];*/
    assign PUNCH_DX_MIN = 60;
    assign PUNCH_DY_MAX = 30;
    // kick: move LED in y direction
    /*assign KICK_DY_MIN = 'h40 + 'h5 * sw[15:13]; // use sw to calibrate threshholds
    assign KICK_DX_MAX = 'h10 + 'h5 * sw[12:11];*/
    assign KICK_DY_MIN = 60;
    assign KICK_DX_MAX = 30;
    // min change in size to indicate forward/backward movement
    assign MIN_SIZE_DELTA = sw[15:13]; // use sw to calibrate threshhold

    always_comb begin
        // after 8 frames get forward, backward, kick, punch states
        if (end_of_8_frames) begin
            // use switches to decide what to output to hex display
            if (sw[2]) begin
                display_data = {p1_8frame_size_delta_sign,
                                3'd0,
                                p1_8frame_size_delta}; 
            end else if (sw[3]) begin
                display_data = {p1_8frame_dx_sign,
                                3'd0,
                                p1_8frame_dx}; 
            end else if (sw[4]) begin
                display_data = {p1_8frame_dy_sign,
                                3'd0,
                                p1_8frame_dy}; 
            end else if (sw[5]) begin
                display_data = {p2_8frame_size_delta_sign,
                                3'd0,
                                p2_8frame_size_delta}; 
            end else if (sw[6]) begin
                display_data = {p2_8frame_dx_sign,
                                3'd0,
                                p2_8frame_dx}; 
            end else if (sw[7]) begin
                display_data = {p2_8frame_dy_sign,
                                3'd0,
                                p2_8frame_dy}; 
            end

            // get move forwards/backwards
            // player 1
            if (p1_8frame_size_delta > MIN_SIZE_DELTA) begin
                p1_move_forwards = !p1_8frame_size_delta_sign; //0=pos=forwards
                p1_move_backwards = p1_8frame_size_delta_sign; //1=neg=backwards
            end else begin
                p1_move_forwards = 0; 
                p1_move_backwards = 0;
            end
            // player 2
            if (p2_8frame_size_delta > MIN_SIZE_DELTA) begin
                p2_move_forwards = !p2_8frame_size_delta_sign; //0=pos=forwards
                p2_move_backwards = p2_8frame_size_delta_sign; //1=neg=backwards
            end else begin
                p2_move_forwards = 0; 
                p2_move_backwards = 0;
            end

            // get punch, kick
            p1_punch = (p1_8frame_dx>PUNCH_DX_MIN)&&(p1_8frame_dy<PUNCH_DY_MAX);
            p1_kick = (p1_8frame_dy>KICK_DY_MIN)&&(p1_8frame_dx<KICK_DX_MAX);
            p2_punch = (p2_8frame_dx>PUNCH_DX_MIN)&&(p2_8frame_dy<PUNCH_DY_MAX);
            p2_kick = (p2_8frame_dy>KICK_DY_MIN)&&(p2_8frame_dx<KICK_DX_MAX);
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
//    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
//    assign dp = 1'b1;  // turn off the period
/*    display_8hex display(
            .clk_in(clk_65mhz),
            .data_in(display_data), 
            .seg_out(segments), 
            .strobe_out(an)
    ); */
    
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
    // ignore the output when p#_final_size is 0
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
        .s_axis_divisor_tdata(final_num_pixels_for_p2),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p1_x_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p1),
        .m_axis_dout_tvalid(x_div_out_valid_p1)
    );

    // player 2 dividers
    div_gen_y2 y2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(p2_final_size),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p2_y_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(y_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(y_div_out_valid_p2)
    );
    div_gen_x2 x2_div_uut (
        .aclk(clk_65mhz),
        .s_axis_divisor_tdata(p2_final_size),
        .s_axis_divisor_tvalid(div_inputs_valid),
        .s_axis_dividend_tdata(p2_x_coord_sum),
        .s_axis_dividend_tvalid(div_inputs_valid),
        .m_axis_dout_tdata(x_div_and_remainder_out_p2),
        .m_axis_dout_tvalid(x_div_out_valid_p2)
    );

    // move targets to follow p1 led & p2 led
    // only display target p1 if there are bright p1-colored pixels
    assign cam = ((hcount_mirror<320)&&(vcount<240)) ? frame_buff_out : 12'h000;
    assign target_p1 = (final_num_pixels_for_p1>5 && 
            (hcount_mirror==x_coord_of_p1 || vcount==y_coord_of_p1) &&
            (hcount_mirror<320 && vcount<240)) ? 12'hF00 : 12'h000;

    // only display target p2 if there are bright p2-colored pixels
    assign target_p2 = (final_num_pixels_for_p2>5 && 
            (hcount_mirror==x_coord_of_p2 || vcount==y_coord_of_p2) &&
            (hcount_mirror<320 && vcount<240)) ? 12'hFFF : 12'h000;

    // calc. sign and delta over 2 frames
    always_comb begin
        // change in position over 2 frames
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

        // calculate size grade from num. pixels
        if (final_num_pixels_for_p1 < 'h50) begin
            p1_final_size = 0;
        end else if (final_num_pixels_for_p1 < 'h100) begin
            p1_final_size = 1;
        end else if (final_num_pixels_for_p1 < 'h400) begin
            p1_final_size = 2;
        end else begin
            p1_final_size = 3;
        end
        if (final_num_pixels_for_p2 < 'h50) begin
            p2_final_size = 0;
        end else if (final_num_pixels_for_p2 < 'h100) begin
            p2_final_size = 1;
        end else if (final_num_pixels_for_p2 < 'h400) begin
            p2_final_size = 2;
        end else begin
            p2_final_size = 3;
        end

        // change in size grade over 2 frames
        // signs (1=neg., 0=pos.)
        p1_2frame_size_delta_sign = (p1_prev_final_size > p1_final_size);
        p2_2frame_size_delta_sign = (p2_prev_final_size > p2_final_size);
        // magnitudes
        if (p1_2frame_size_delta_sign) p1_2frame_size_delta=p1_prev_final_size-p1_final_size;
        else p1_2frame_size_delta = p1_final_size - p1_prev_final_size;
        if (p2_2frame_size_delta_sign) p2_2frame_size_delta=p2_prev_final_size-p2_final_size;
        else p2_2frame_size_delta = p2_final_size - p2_prev_final_size;
    end

    // led threshholds
    logic [4:0] RED_MIN_R, RED_MAX_G, RED_MAX_B;
    logic [4:0] IR_MIN_R, IR_MIN_G, IR_MIN_B;
    /*assign RED_MIN_R = 8 + sw[8:6]; // use switches to calibrate threshholds
    assign RED_MAX_G = 1 + sw[5:4];
    assign RED_MAX_B = 1 + sw[5:4];
    assign IR_MIN_R = 8 + sw[3:1];
    assign IR_MIN_G = 8 + sw[3:1];
    assign IR_MIN_B = 8 + sw[3:1];*/
    assign RED_MIN_R = 11;
    assign RED_MAX_G = 3;
    assign RED_MAX_B = 3;
    assign IR_MIN_R = 12;
    assign IR_MIN_G = 12;
    assign IR_MIN_B = 12;

    always_ff @(posedge clk_65mhz) begin
        // update previous outputs of iir filter
        /*prev_smooth_p1_8frame_dx_unsigned <= smooth_p1_8frame_dx_unsigned;
        prev_smooth_p1_8frame_dy_unsigned <= smooth_p1_8frame_dy_unsigned;
        prev_smooth_p2_8frame_dx_unsigned <= smooth_p2_8frame_dx_unsigned;
        prev_smooth_p2_8frame_dy_unsigned <= smooth_p2_8frame_dy_unsigned;
        prev_smooth_p1_8frame_size_delta_unsigned <= smooth_p1_8frame_size_delta_unsigned;
        prev_smooth_p2_8frame_size_delta_unsigned <= smooth_p2_8frame_size_delta_unsigned;*/

        // update buffer frame and frame tally
        buffer_frame_done_out <= frame_done_out;
        if (rising_edge_frame_done_out) eight_frame_tally <= eight_frame_tally + 1;

        // at end_of_8_frames, extract delta values then reset to 0
        if (end_of_8_frames) begin
            reset_8frame_delta_values <= 1;
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
        
        /*
            logic [15:0] count_num_pixels_for_p1, count_num_pixels_for_p2; // sometimes invalid
    logic [15:0] final_num_pixels_for_p1, final_num_pixels_for_p2; // final (valid) value

        
        */

        // on falling edge of frame_done_out, update final pixel count
        // for p1 and p2 and set div_inputs_valid to true
        if (falling_edge_frame_done_out) begin
            // update prev values
            p1_prev_final_size <= p1_final_size;
            p2_prev_final_size <= p2_final_size;
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
        if (rgb_pixel_valid && cam[11:8]>RED_MIN_R && cam[7:4]<RED_MAX_G 
                && cam[3:0]<RED_MAX_B) begin
            count_num_pixels_for_p1 <= count_num_pixels_for_p1 + 1;
            p1_x_coord_sum <= p1_x_coord_sum + hcount_mirror;
            p1_y_coord_sum <= p1_y_coord_sum + vcount;
        // player 2 LED (IR LED (white))
        end else if (rgb_pixel_valid && cam[11:8]>IR_MIN_R && cam[7:4]>IR_MIN_G 
                && cam[3:0]>IR_MIN_B) begin
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
        // if target p1 is there, display
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
endmodule
