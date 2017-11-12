// I'm taking a page out of real life and stealing the concept of the UNIX timestamp. There's a 
// master counter module, counting seconds from 0 (12:00:00 AM) to 86399 (11:59:59 PM). This module
// is also, as to be expected, in charge of handling user input for setting the time. There is an 
// alarm module in charge of setting, enabling/disabling, and checking the alarm function. An output
// module manages converting the timestamp to a human readable form and writing it to a terminal or
// other device. An input module parses user input (setting the time and alarm, etc.) into a form
// usable by the modules that need the information.

// A coordination module serves as a sort of Grand Central Station, routing information between the
// modules and ensuring everything stays encapsulated. There is no state stored in this module;
// state is managed by each module individually. This module is also responsible for generating the
// clock signal.

// Maybe it's the C programmer in me - this probably isn't very well optimized for FPGA hardware.

// state var types
`define COUNTER_T unsigned [16:0]
`define FLAG_T unsigned [0:0]
`define TIME_T unsigned [5:0]

// Abracadabra!
`define COUNTER_MAX 86399 // 60 sec * 60 min * 24 hours, zero indexed
`define SEC_ROLLOVER 60
`define MIN_TICK 60
`define MIN_ROLLOVER 60
`define HOUR_TICK 3600    // 60 sec * 60 min
`define HOUR_ROLLOVER 12  // 0 is converted to 12 on the fly during output
`define AMPM_TICK 43200   // 60 sec * 60 min * 12 hours

// routes information between modules
module main;
  reg unsigned [0:0]clock;
  wire `COUNTER_T counter_state;
  reg  `COUNTER_T counter_state_reg;
  wire `FLAG_T set_flag;
  reg  `FLAG_T set_flag_reg;
  wire `COUNTER_T set_time;
  reg  `COUNTER_T set_time_reg;
  wire `FLAG_T alarm_state;
  reg  `FLAG_T alarm_state_reg;
  wire `FLAG_T alarm_flag;
  reg  `FLAG_T alarm_flag_reg;
  wire `COUNTER_T alarm_time;
  reg  `COUNTER_T alarm_time_reg;

  counter_m counter(clock, set_flag_reg, set_time_reg, counter_state);
  alarm_m alarm(counter_state_reg, set_flag_reg, alarm_flag_reg, alarm_time_reg, alarm_state);
  out_m out(counter_state_reg, alarm_state_reg);

  initial begin
    assign counter_state_reg = counter_state;
    assign set_flag_reg = set_flag;
    assign set_time_reg = set_time;
    assign alarm_state_reg = alarm_state;
    assign alarm_flag_reg = alarm_flag;
    assign alarm_time_reg = alarm_time;
    clock = 0;
  end

  // tick, tock, tick, tock...
  always begin
    #2 clock = ~clock;
  end
endmodule



// manages main timing state
module counter_m( input wire unsigned [0:0]clock,
                  input wire `FLAG_T set_flag,
                  input wire `COUNTER_T set_time,
                  output reg `COUNTER_T counter_state);
  reg `COUNTER_T _counter_state = 0;

  always @(posedge clock) begin
    if( set_flag )
      _counter_state = set_time;
    else begin
      if( _counter_state < `COUNTER_MAX )
        _counter_state++;
      else
        _counter_state = 0;
      end
    counter_state = _counter_state;
  end
endmodule



// manages alarm state
module alarm_m( input wire `COUNTER_T counter_state,
                input wire `FLAG_T set_flag,
                input wire `FLAG_T alarm_flag,
                input wire `COUNTER_T alarm_time,
                output reg `FLAG_T alarm_state);
  reg `COUNTER_T _alarm_time;
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
    _sec = counter_state % `SEC_ROLLOVER;
    _min = ((counter_state - _sec) / `MIN_TICK) % `MIN_ROLLOVER;
    _hour = ((counter_state - _sec - (_min * `MIN_TICK)) / `HOUR_TICK) % `HOUR_ROLLOVER;
    if( (counter_state - _sec - (_min * `MIN_TICK) - (_hour * `HOUR_TICK)) / `AMPM_TICK )
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



// manages user input
module in_m(  output reg `FLAG_T set_flag,
              output reg `COUNTER_T set_time,
              output reg `FLAG_T alarm_flag,
              output reg `COUNTER_T alarm_time);
  reg `FLAG_T _set_flag = 0;
  reg `COUNTER_T _set_time = 0;
  reg `FLAG_T _alarm_flag = 0;
  reg `COUNTER_T _alarm_time = 0;

  initial begin
    set_flag = _set_flag;
    set_time = _set_time;
    alarm_flag = _alarm_flag;
    alarm_time = _alarm_time;
  end
endmodule
