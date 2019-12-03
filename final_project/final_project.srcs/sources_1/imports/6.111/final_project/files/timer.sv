`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////
// lab 4 timer module
//
// counter goes from 0 to N (pulse value):
//
// N-1      N                     0                   1          
//          if(begin_one_hz):     if(begin_one_hz):
//              one_hz=1              one_hz=0        expired_pulse=0
//                                if(counting&&count_out>0):
//                                    if(count_out==1):
//                                        counting=0
//                                       expired_pulse=1
//                                    count_out-=1
//
// On start_timer, counting=1, counting_out=value,
//            counter=0, begin_one_hz=1
//
// update every clock cycle:
//  - counter
//////////////////////////////////////////////////////////////

module timer(clock, start_timer, value, counting, 
    expired_pulse, one_hz, count_out);

    input clock, start_timer;
    input [3:0] value;
    output logic counting; 
    output logic expired_pulse; 
    output logic one_hz;
    output logic [3:0] count_out;
    
    // start_timer delayed by one clock cycle
    // fixes problem with clock delays and inputs
    logic start_timer_delay;

    // count from 0 to N 
    logic [25:0] counter = 0; // counts to 1 Hz

    // pulse value (3 in sim) 65,000,000-1
    const logic [25:0] N = 64999999;

    // reset is true on clock cycle after start_timer is true
    // on clock cycle after start_timer, do not decrement count_out
    logic reset = 0;

    always_ff @(posedge clock) begin
        start_timer_delay <= start_timer;
        // init values on start_timer
        if (start_timer_delay) begin
            counting <= 1;
            count_out <= value;
            counter <= 0;
            reset <= 1;
        end else if (counter==N) begin
            one_hz <= 1;
            counter <= 0; // reset counter if N
        end else if (counter==0) begin
            one_hz <= 0;
            if (counting) begin
                if ((count_out==1) || (reset && (value==0))) begin
                    counting <= 0;
                    expired_pulse <= 1;
                end else if (reset) begin
                    reset <= 0;
                end 

                if (count_out>0 && !reset) begin
                    // on clock cycle after start_timer, do not decrement count_out
                    count_out <= count_out - 1;
                end
            end
            // increment counter if < N
            counter <= counter + 1;
        end else begin
            // increment counter if < N
            counter <= counter + 1;
            expired_pulse <= 0;
        end 
    end                        
endmodule
