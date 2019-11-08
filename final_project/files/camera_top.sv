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
    
    logic [11:0] cam;
    logic [11:0] frame_buff_out;
    logic [15:0] output_pixels;
    logic [15:0] old_output_pixels;
    logic [12:0] processed_pixels;
    logic [3:0] red_diff;
    logic [3:0] green_diff;
    logic [3:0] blue_diff;
    logic valid_pixel;
    logic frame_done_out;
    
    logic [16:0] pixel_addr_in;
    logic [16:0] pixel_addr_out;
    
    assign xclk = (xclk_count >2'b01);
    assign jbclk = xclk;
    assign jdclk = xclk;
    
    assign red_diff = (output_pixels[15:12]>old_output_pixels[15:12])?output_pixels[15:12]-old_output_pixels[15:12]:old_output_pixels[15:12]-output_pixels[15:12];
    assign green_diff = (output_pixels[10:7]>old_output_pixels[10:7])?output_pixels[10:7]-old_output_pixels[10:7]:old_output_pixels[10:7]-output_pixels[10:7];
    assign blue_diff = (output_pixels[4:1]>old_output_pixels[4:1])?output_pixels[4:1]-old_output_pixels[4:1]:old_output_pixels[4:1]-output_pixels[4:1];

    blk_mem_gen_0 bram_uut(.addra(pixel_addr_in), 
                             .clka(pclk_in),
                             .dina(processed_pixels),
                             .wea(valid_pixel),
                             .addrb(pixel_addr_out),
                             .clkb(clk_65mhz),
                             .doutb(frame_buff_out));
    
    always_ff @(posedge pclk_in)begin
        if (frame_done_out)begin
            pixel_addr_in <= 17'b0;  
        end else if (valid_pixel)begin
            pixel_addr_in <= pixel_addr_in +1;  
        end
    end
    
    always_ff @(posedge clk_65mhz) begin
        pclk_buff <= jb[0];
        vsync_buff <= jb[1]; 
        href_buff <= jb[2]; 
        pixel_buff <= ja;
        pclk_in <= pclk_buff;
        vsync_in <= vsync_buff;
        href_in <= href_buff;
        pixel_in <= pixel_buff;
        old_output_pixels <= output_pixels;
        xclk_count <= xclk_count + 2'b01;

        if (sw[3])begin
            //processed_pixels <= {red_diff<<2, green_diff<<2, blue_diff<<2};
            processed_pixels <= output_pixels - old_output_pixels;
        end else if (sw[4]) begin
            if ((output_pixels[15:12]>4'b1000)&&(output_pixels[10:7]<4'b1000)&&(output_pixels[4:1]<4'b1000))begin
                processed_pixels <= 12'hF00;
            end else begin
                processed_pixels <= 12'h000;
            end
        end else if (sw[5]) begin
            if ((output_pixels[15:12]<4'b1000)&&(output_pixels[10:7]>4'b1000)&&(output_pixels[4:1]<4'b1000))begin
                processed_pixels <= 12'h0F0;
            end else begin
                processed_pixels <= 12'h000;
            end
        end else if (sw[6]) begin
            if ((output_pixels[15:12]<4'b1000)&&(output_pixels[10:7]<4'b1000)&&(output_pixels[4:1]>4'b1000))begin
                processed_pixels <= 12'h00F;
            end else begin
                processed_pixels <= 12'h000;
            end
        end else begin
            processed_pixels = {output_pixels[15:12],output_pixels[10:7],output_pixels[4:1]};
        end
            
    end
    assign pixel_addr_out = sw[2]?((hcount>>1)+(vcount>>1)*32'd320):hcount+vcount*32'd320;
    assign cam = sw[2]&&((hcount<640) &&  (vcount<480))?frame_buff_out:~sw[2]&&((hcount<320) &&  (vcount<240))?frame_buff_out:12'h000;
    
    /*
    ila_0 ila_uut(.clk(clk_65mhz),    
        .probe0(pixel_in), 
        .probe1(pclk_in), 
        .probe2(vsync_in),
        .probe3(href_in),
        .probe4(jbclk)
    );
    */
                                        
   camera_read  my_camera(.p_clock_in(pclk_in),
                          .vsync_in(vsync_in),
                          .href_in(href_in),
                          .p_data_in(pixel_in),
                          .pixel_data_out(output_pixels),
                          .pixel_valid_out(valid_pixel),
                          .frame_done_out(frame_done_out));
   

    wire phsync,pvsync,pblank;

    reg b,hs,vs;
    always_ff @(posedge clk_65mhz) begin
        hs <= phsync;
        vs <= pvsync;
        b <= pblank;
        rgb <= cam;
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

    // test timer
    logic one_second_pulse;
    assign led16_b = one_second_pulse;

    always_ff @(posedge clk_65mhz) begin
        if (one_hz) begin
            one_second_pulse <= !one_second_pulse;
            data_in <= data_in + 1;
        end
    end

    // the following lines are required for the Nexys4 VGA circuit - do not change
    assign vga_r = ~b ? rgb[11:8]: 0;
    assign vga_g = ~b ? rgb[7:4] : 0;
    assign vga_b = ~b ? rgb[3:0] : 0;

    assign vga_hs = ~hs;
    assign vga_vs = ~vs;

endmodule // camera_top_level
