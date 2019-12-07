///////////////////////////////////////////////////////////////
//
// IIR filter module
//
///////////////////////////////////////////////////////////////

module iir_filter (
        input [12:0] prev_dx_val_out, // prev iir output for delta x
        input [12:0] prev_dy_val_out, // prev iir output for delta y
        input [8:0] prev_delta_size_out, // prev iir output for change in size
        input [8:0] delta_x_val_in, // delta x coord input
        input [8:0] delta_y_val_in, // delta y coord input
        input [8:0] delta_size_in, // delta size input
        output logic [8:0] delta_x_val_out, // iir output for delta x 
        output logic [8:0] delta_y_val_out, // iir output for delta y
        output logic [8:0] delta_size_out // iir output for delta size
    ); 

    // formula: iir_out[n] = iir_in[n] - iir_in[n] * d/16 + iir_out[n-1] * d/16
    parameter decay_factor = 16;

    // delta x coordinate
    // multiply by some factor so that the max/min values align with the
    // left/right sides of the screen
    assign delta_x_val_out = (delta_x_val_in - (delta_x_val_in*decay_factor)/16
          + (prev_delta_x_val_out*decay_factor)/16) >> 1;

    // delta y coordinate
    // multiply by some factor so that the max/min values align with the
    // top/bottom sides of the screen
    assign delta_y_val_out = (delta_y_val_in - (delta_y_val_in*decay_factor)/16
        + (prev_delta_y_val_out*decay_factor)/16) >> 1;

    // delta size
    assign delta_size_out = (delta_size_in - (delta_size_in*decay_factor)/16
        + (prev_delta_size_out*decay_factor)/16) >> 1;

endmodule
