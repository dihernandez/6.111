///////////////////////////////////////////////////////////////
//
// IIR filter module
//
///////////////////////////////////////////////////////////////

module iir_filter (
        input [8:0] prev_delta_x_val_out, // prev iir output for x coord
        input [8:0] prev_delta_y_val_out, // prev iir output for y coord
        input [8:0] delta_x_val_in, // x coord input
        input [8:0] delta_y_val_in, // y coord input
        input [3:0] decay_factor, // sw[14:11]
        output logic [8:0] delta_x_val_out, // iir output for x coord
        output logic [8:0] delta_y_val_out // iir output for y coord
    ); 

    // formula: iir_out[n] = iir_in[n] - iir_in[n] * d/16 + iir_out[n-1] * d/16

    // x coordinate
    // multiply by some factor so that the max/min values align with the
    // left/right sides of the screen
    assign delta_x_val_out = (delta_x_val_in - (delta_x_val_in*decay_factor)/16
          + (prev_delta_x_val_out*decay_factor)/16) >> 1;

    // y coordinate
    // multiply by some factor so that the max/min values align with the
    // top/bottom sides of the screen
    assign delta_y_val_out = (delta_y_val_in - (delta_y_val_in*decay_factor)/16
          + (prev_delta_y_val_out*decay_factor)/16) >> 1;

endmodule
