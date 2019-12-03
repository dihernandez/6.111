///////////////////////////////////////////////////////////////
//
// square: generate rectangle on screen
//
///////////////////////////////////////////////////////////////

module square (
        input player, //0=p2, 1=p1
        input punch, kick, forwards, backwards,
        input [10:0] hcount_in,
        input [9:0] vcount_in,
        output logic [11:0] pixel_out
    );

    parameter WIDTH = 64;
    parameter HEIGHT = 64;

    logic [11:0] color;
    logic [10:0] x_in;
    logic [9:0] y_in;

    always_comb begin
        // player 1 => bottom left of screen
        if (player) begin 
            x_in = 100;
            y_in = 600;        
        // player 2 => bottom right of screen
        end else begin
            x_in = 800;
            y_in = 600;        
        end

        if (forwards) begin //forwards=cyan
            color = 12'h0FF;
        end else if (backwards) begin //backwards=magenta
            color = 12'hF0F;
        end else if (punch) begin // punch=red
            color = 12'hF00;
        end else if (kick) begin //kick=green
            color = 12'h0F0;
        end else begin //none=black
            color = 12'h000;
        end

        // if in square, draw square
        if ((hcount_in >= x_in && hcount_in < (x_in+WIDTH)) &&
             (vcount_in >= y_in && vcount_in < (y_in+HEIGHT))) begin
            pixel_out <= color;
        end else pixel_out = 0;
   end
endmodule
