// hardware: DE2I-150 FPGA

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
// I'm attempting to encapsulate state within each module, emulating OOP. Maybe that's not a very
// good thing to do in HDL?

// uncomment to enable more verbose debugging output or pass '-D DEBUG' during compilation
//`define DEBUG

// uncomment to enable console-specific prettiness or pass '-D PRETTY' during compilation
//`define PRETTY

`ifdef PRETTY
  `define PREPEND "\033[1m"
  `define APPEND "\033[0m"
`else
  `define PREPEND "[[[ "
  `define APPEND " ]]]"
`endif

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
  out_m out(clock, counter_state_reg, alarm_state_reg);
  test_m test(set_flag, set_time, alarm_flag, alarm_time);

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
`ifdef DEBUG
    $display("clock: %d", clock);
`endif
    #1 clock = ~clock;
  end
endmodule



// manages main timing state
module counter_m( input wire unsigned [0:0]clock,
                  input wire `FLAG_T set_flag,
                  input wire `COUNTER_T set_time,
                  output reg `COUNTER_T counter_state);
  reg `FLAG_T _set_flag = 0;
  reg `COUNTER_T _counter_state = 0;

  // initialize output state
  initial begin
    counter_state = _counter_state;
  end

  always @( posedge clock) begin
    // store input state
    _set_flag = 0;

    if( set_flag )
      _counter_state = set_time;
    else begin
      if( _counter_state < `COUNTER_MAX )
        _counter_state++;
      else
        _counter_state = 0;
      end

      // write output state
    counter_state = _counter_state;
  end
endmodule



// manages alarm state
module alarm_m( input wire `COUNTER_T counter_state,
                input wire `FLAG_T set_flag,
                input wire `FLAG_T alarm_flag,
                input wire `COUNTER_T alarm_time,
                output reg `FLAG_T alarm_state);
  reg `FLAG_T _alarm_flag = 0;
  reg `COUNTER_T _alarm_time = 0;
  reg `FLAG_T _alarm_state = 0;

  // initialize output states
  initial begin
    alarm_state = _alarm_state;
  end

  always @( alarm_flag, alarm_time ) begin
    // store input state
    _alarm_flag = alarm_flag;
    _alarm_time = alarm_time;

    if( !_alarm_flag )
      _alarm_state = 0;

    // write output state
    alarm_state = _alarm_state;
  end

  always @( counter_state ) begin
    if( _alarm_flag && !set_flag ) begin
      if( counter_state == alarm_time )
        _alarm_state = 1;

      // write output state - usually this would be at the root of the always @ block, but in this
      // case we don't want to do anything unless the alarm is enabled
      alarm_state = _alarm_state;
    end
  end
endmodule



// manages output formatting. Since this system is based off the second timestamp, this can be
// easily adapted to a 24 hour clock, or a 6 hour clock, or hex output, or really whatever you want.
// Moral of the story: by design, changes to this module don't affect the operation of the clock.
module out_m( input wire [0:0]clock,
              input wire `COUNTER_T counter_state,
              input wire `FLAG_T alarm_state);
  reg `TIME_T _hour;
  reg `TIME_T _min;
  reg `TIME_T _sec;
  reg unsigned [1*7:0] _ampm;
  reg unsigned [3*7:0] _alarm_str;

  // output on negative edges because all the action happens on positive edges. This way, we can be
  // sure everything has been calculated and pushed into the state registers before we print the
  // contents of those registers.
  always @( negedge clock ) begin
    // store input state
    // We could save a little time by not subtracting and letting integer division take care of
    // rounding off the numbers, but I think it's more readable this way.
    _sec = counter_state % `SEC_ROLLOVER;
    _min = ((counter_state - _sec) / `MIN_TICK) % `MIN_ROLLOVER;
    _hour = ((counter_state - _sec - (_min * `MIN_TICK)) / `HOUR_TICK) % `HOUR_ROLLOVER;
    if( (counter_state - _sec - (_min * `MIN_TICK) - (_hour * `HOUR_TICK)) / `AMPM_TICK )
      _ampm = "P";
    else
      _ampm = "A";
    if( alarm_state )
      _alarm_str = "<!>";
    else
      _alarm_str = "   ";

    // hour 0 is actually 12 - the assignment doesn't matter because we've already calculated AM/PM
    // and it'll get recalculated on the next run
    if( _hour == 0 )
      _hour = 12;

    $display("%s %02d:%02d:%02d %cM %s", _alarm_str, _hour, _min, _sec, _ampm, _alarm_str);
  end
endmodule



// simulates user input for testing
module test_m(  output reg `FLAG_T set_flag,
                output reg `COUNTER_T set_time,
                output reg `FLAG_T alarm_flag,
                output reg `COUNTER_T alarm_time);
  /* we drive outputs directly b/c these are inputs; the state is stored in the respective modules
   * reg `FLAG_T _set_flag = 0;
   * reg `COUNTER_T _set_time = 0;
   * reg `FLAG_T _alarm_flag = 0;
   * reg `COUNTER_T _alarm_time = 0; 
   */

  initial begin
    // initialize output states
    set_flag = 0;
    set_time = 0;
    alarm_flag = 0;
    alarm_time = 0;

    // one second is 2 system ticks
    $display("\n%sinitialization + 11 ticks (5 seconds, stop with clock low)%s", `PREPEND, `APPEND);
    #11;

    // this should hold the counter at the set value; we allow 5 seconds to go by but we should only
    // see one line of output. Hacking movement FTW!
    $display("%sraising set flag, time set to 34953 (9:42:33 AM); 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    set_flag = 1; set_time = 34953; // 9:42:33 AM
    #10;

    // releasing the set flag should start the clock ticking again at the set time
    $display("%sreleasing set flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    set_flag = 0;
    #10;

    // setting the alarm to a future time shouldn't have any affect
    $display("%sraising alarm flag, alarm set to 34961 (9:42:41 AM); 20 ticks (10 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 1; alarm_time = 34961;
    #20;

    // releasing the alarm flag should clear the triggered alarm
    $display("%sreleasing alarm flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 0;
    #10;

    // since releasing the flag should clear the state, raising it again should have no effect
    $display("%sraising alarm flag, time left at previous setpoint; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 1;
    #10;

    // releasing the alarm flag shouldn't clear the setpoint though...
    $display("%sraising set flag, time set to 34955 (9:42:35 AM); 4 ticks (2 seconds)%s", `PREPEND, `APPEND);
    set_flag = 1; set_time = 34955; // 9:42:35 AM
    #4;

    $display("%sreleasing set flag; 20 ticks (10 seconds)%s", `PREPEND, `APPEND);
    set_flag = 0;
    #20;

    $display("%sreleasing alarm flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 0;
    #10;

    // This test is a compound test: raising set with a time then raising alarm with the same time
    // should not trigger the alarm, even after set is released, since that time has already passed.
    // This is definitely an edge case and the 'correct' behavior can be argued either way; this is
    // the side I chose because it makes more sense to me. While you're holding set, the time is
    // current, but we don't want the alarm to trigger since we've deliberately set the clock to
    // that time. When set is released, that time has now passed, so the alarm needs to wait until
    // the next time around.
    $display("%sraising set flag, time set to 50925 (2:08:45 PM); 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    set_flag = 1; set_time = 50925;
    #10;

    $display("%sraising alarm flag, time set to 50925 (2:08:45 PM); 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 1; alarm_time = 50925;
    #10;

    $display("%sreleasing set flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    set_flag = 0;
    #10;

    // The alarm should trigger, however, if the time is set to one second before the alarm setpoint
    $display("%sraising set flag, time set to 50924 (2:08:44 PM); 4 ticks (2 seconds)%s", `PREPEND, `APPEND);
    set_flag = 1; set_time = 50924;
    #10;

    $display("%sreleasing set flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    set_flag = 0;
    #10;

    $display("%sreleasing alarm flag; 10 ticks (5 seconds)%s", `PREPEND, `APPEND);
    alarm_flag = 0;
    #10

    $display();
    $finish;
  end

endmodule
