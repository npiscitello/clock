// Logisim implementation:
// seconds ones module
// seconds tens module
// minutes ones module
// minutes tens module
// hours module
// output adjust module
// AM/PM module

// verilog implementation
// I'm taking a page out of real life and stealing the concept of the UNIX timestamp. There's a 
// master counter module, counting seconds from 0 (12:00:00 AM) to 86399 (11:59:59 PM). This module
// is also, as to be expected, in charge of handling user input for setting the time. There is an 
// alarm module in charge of setting, enabling/disabling, and checking the alarm function. An output
// module manages converting the timestamp to a human readable form and writing it to a terminal or
// other device. The coordination module serves as a sort of Grand Central Station, routing 
// information between the modules and ensuring everything stays encapsulated. There is not state
// stored in this module; state is managed by each module individually. This module is also 
// responsible for generating the clock signal.

// state var types
`define COUNTER_T unsigned [16:0]
`define FLAG_T unsigned [0:0]
`define TIME_T unsigned [5:0]

// magic numbers
`define COUNTER_MAX 86399

// routes information between modules
module main;
  reg unsigned [0:0]clock;
  wire `COUNTER_T counter_state;
  reg  `COUNTER_T counter_state_reg;
  wire `FLAG_T alarm_state;
  reg  `FLAG_T alarm_state_reg;

  counter_m counter(clock, counter_state);
  alarm_m alarm(counter_state_reg, alarm_state);
  out_m out(counter_state_reg, alarm_state_reg);

  initial begin
    assign counter_state_reg = counter_state;
    assign alarm_state_reg = alarm_state;
    clock = 0;
  end

  // tick, tock, tick, tock...
  always begin
    #2 clock = ~clock;
  end
endmodule

// manages main timing state
module counter_m( input wire unsigned [0:0]clock,
                  output reg `COUNTER_T counter_state);
  // bad form, perhaps, but the conversion is implicit...
  reg `COUNTER_T _counter_state = -1;

  /*
  always @(posedge clock) begin
    if( _counter_state < `COUNTER_MAX )
      _counter_state++;
    else
      _counter_state = 0;
    counter_state = _counter_state;
  end
  */

  // temporary one-shot for testing
  always @(posedge clock) begin
    if( _counter_state < `COUNTER_MAX )
      _counter_state++;
    else if( _counter_state == 131071 )
      _counter_state = 0;
    else
      $finish;
    counter_state = _counter_state;
  end
  // temporary one-shot for testing

endmodule

// manages alarm state
module alarm_m( input wire `COUNTER_T counter_state,
                output reg `FLAG_T alarm_state);
  reg `COUNTER_T _alarm_setpoint;
  reg `FLAG_T _alarm_state;
endmodule

// manages output formatting
module out_m( input wire `COUNTER_T counter_state,
              input wire `FLAG_T alarm_state);
  reg `TIME_T _hour;
  reg `TIME_T _min;
  reg `TIME_T _sec;
  reg unsigned [7:0] _ampm;
  // usually I like to explicitly specify the sensitivities, but we want to make sure the output
  // always reflects the most current state of every input.
  always @( * ) begin
    // We could save a little time by not subtracting and letting integer division take care of
    // rounding off the numbers, but I think it's more readable this way.
    // count every second, rollover 59->0
    _sec = counter_state % 60;
    // count every 60 seconds, rollover 59->0
    _min = ((counter_state - _sec) / 60) % 60;
    // count every 3600 seconds (60 minutes), rollover 11->0
    _hour = ((counter_state - _sec - (_min * 60)) / 3600) % 12;
    // count every 43200 seconds (12 hours)
    if( (counter_state - _sec - (_min * 60) - (_hour * 3600)) / 43200 )
      _ampm = "P";
    else
      _ampm = "A";

    // hour 0 is actually 12 - the assignment doesn't matter because we've already calculated AM/PM
    // and it'll get recalculated on the next run
    if( _hour == 0 )
      _hour = 12;

    $display("%02d:%02d:%02d %cM", _hour, _min, _sec, _ampm);
  end
endmodule
