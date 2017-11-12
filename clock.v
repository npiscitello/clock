// Logisim implementation:
// seconds ones module
// seconds tens module
// minutes ones module
// minutes tens module
// hours module
// output adjust module
// AM/PM module

// verilog implementation
// I'm taking a page out of real life and stealing the concept
// of the UNIX timestamp. There's a master counter module, counting
// seconds from 0 (12:00:00 AM) to 86399 (11:59:59 PM). This module
// is also, as to be expected, in charge of handling user input for
// setting the time. There is an alarm module in charge of setting,
// enabling/disabling, and checking the alarm function. An output
// module manages converting the timestamp to a human readable
// form and writing it to a terminal or other device. The
// coordination module serves as a sort of Grand Central Station,
// routing information between the modules and ensuring everything
// stays encapsulated. There is not state stored in this module;
// state is managed by each module individually. This module is
// also responsible for generating the clock signal.

// state var types
`define COUNTER_T unsigned [16:0]
`define ALARM_T unsigned [0:0]

// magic numbers
`define COUNTER_MAX 86399

// routes information between modules
module main;
  reg unsigned [0:0]clock;
  wire `COUNTER_T counter_state;
  reg  `COUNTER_T counter_state_reg;
  wire `ALARM_T alarm_state;
  reg  `ALARM_T alarm_state_reg;

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
  reg `COUNTER_T _counter_state = 0;

  always @(posedge clock) begin
    if( _counter_state < `COUNTER_MAX )
      _counter_state++;
    else
      _counter_state = 0;
    counter_state = _counter_state;
  end
endmodule

// manages alarm state
module alarm_m( input wire `COUNTER_T counter_state,
                output reg `ALARM_T alarm_state);
  reg `COUNTER_T _alarm_setpoint;
  reg `ALARM_T _alarm_state;
endmodule

// manages output formatting
module out_m( input wire `COUNTER_T counter_state,
              input wire `ALARM_T alarm_state);
  // usually I like to explicitly specify the sensitivities, but
  // we want to make sure the output always reflects the most
  // current state of every input.
  always @( * ) begin
  end
endmodule
