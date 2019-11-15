`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// camera module
//////////////////////////////////////////////////////////////////////////////////

module camera_read(
        input  p_clock_in,
        input  vsync_in,
        input  href_in,
        input  [7:0] p_data_in,
        output logic [15:0] pixel_data_out,
        output logic [1:0] hsv_thresh_data_out,
        output logic rgb_pixel_valid_out, 
        output logic hsv_thresh_valid_out, 
        output logic hsv_frame_done_out,
        output logic rgb_frame_done_out
    );
    
    // state variables
    logic [1:0] FSM_state = 0;
    logic pixel_half = 0;

    // calculate hsv_frame_done_out (buffered frame_done_out)
    logic [11:0] buffer_frame_done;
    assign hsv_frame_done_out = buffer_frame_done[11];
	
    // rgb to hsv module
    logic hsv_valid_out;
    logic [11:0] hsv;
    rgb_to_hsv rgb_to_hsv_uut(
            .clk_in(p_clock_in),
            .valid_in(rgb_pixel_valid_out),
            .rgb({pixel_data_out[15:12],pixel_data_out[10:7],pixel_data_out[4:1]}),
            .valid_out(hsv_valid_out),
            .hsv(hsv)
        );

    // from hsv value, calculate hsv_thresh_data_out (if valid)
    // 0=no match; 1-3=match with color 1-3
    always_ff @(posedge p_clock_in) begin
        // if hsv valid 
        if (hsv_valid_out) begin
            // if saturation and value greater than some value
            // (i.e. color is not close to white or black)
            if (hsv[7:4]>3 && hsv[3:0]>3) begin
                if (hsv[11:9]==3'b00) begin // red
                    hsv_thresh_data_out <= 1; 
                end else if (hsv[11:9]==3'b011) begin // green
                    hsv_thresh_data_out <= 2;
                end else if (hsv[11:9]==3'b111) begin // blue
                    hsv_thresh_data_out <= 3;
                end else begin
                    hsv_thresh_data_out <= 0;
                end
            end else begin
                hsv_thresh_data_out <= 0;
            end

            // after hsv_thresh_data_out calculated, hsv_thresh_valid_out is true
            hsv_thresh_valid_out <= 1;
        end else begin
            // else hsv_thresh_valid_out is false
            hsv_thresh_valid_out <= 0;
        end
    end

	localparam WAIT_FRAME_START = 0;
	localparam ROW_CAPTURE = 1;
	
	always_ff@(posedge p_clock_in) begin 
        case(FSM_state)
            WAIT_FRAME_START: begin //wait for VSYNC
               FSM_state <= (!vsync_in) ? ROW_CAPTURE : WAIT_FRAME_START;
               rgb_frame_done_out <= 0;
               buffer_frame_done <= {buffer_frame_done[10:0], rgb_frame_done_out};
               pixel_half <= 0;
            end
            
            ROW_CAPTURE: begin 
                FSM_state <= vsync_in ? WAIT_FRAME_START : ROW_CAPTURE;
                rgb_frame_done_out <= vsync_in ? 1 : 0;
                buffer_frame_done <= {buffer_frame_done[10:0], rgb_frame_done_out};
                rgb_pixel_valid_out <= (href_in && pixel_half) ? 1 : 0; 
                if (href_in) begin
                    pixel_half <= ~pixel_half;
                    if (pixel_half) begin
                        pixel_data_out[7:0] <= p_data_in;
                    end else begin
                        pixel_data_out[15:8] <= p_data_in;
                    end
                end
            end
        endcase
	end
	
endmodule
