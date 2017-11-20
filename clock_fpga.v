// hardware: DE2I-150 FPGA
// This should work with quartus for the above board
// More documentation available in clock.v

// state var types
`define COUNTER_T unsigned [16:0]
`define FLAG_T unsigned [0:0]
`define TIME_T unsigned [5:0]
`define SSD_T unsigned [7:0]

// Abracadabra!
`define COUNTER_MAX 86399 // 60 sec * 60 min * 24 hours, zero indexed
`define SEC_ROLLOVER 60
`define MIN_TICK 60
`define MIN_ROLLOVER 60
`define HOUR_TICK 3600    // 60 sec * 60 min
`define HOUR_ROLLOVER 12  // 0 is converted to 12 on the fly during output
`define AMPM_TICK 43200   // 60 sec * 60 min * 12 hours

// routes information between modules
// use the same switches for set_time and alarm_time
// use momentary buttons for set_flag and alarm_flag
// output to SSDs
//   * ampm flag is the hours (ones and tens) decimal points
//   * alarm is the seconds (ones and tens) decimal points
module clock_fpga(  input wire [0:0]clock,
                    input wire `FLAG_T set_flag,
                    input wire `COUNTER_T set_time,
                    input wire `FLAG_T alarm_flag,
                    input wire `COUNTER_T alarm_time,
                    output wire `SSD_T hour_tens,
                    output wire `SSD_T hour_ones,
                    output wire `SSD_T minute_tens,
                    output wire `SSD_T minute_ones,
                    output wire `SSD_T second_tens,
                    output wire `SSD_T second_ones );

  wire `COUNTER_T counter_state;
  wire `FLAG_T alarm_state;

  counter_m counter(clock, set_flag, set_time, counter_state);
  alarm_m alarm(counter_state, set_flag, alarm_flag, alarm_time, alarm_state);
  out_m out(clock, counter_state, alarm_state,
    hour_tens, hour_ones, minute_tens, minute_ones, second_tens, second_ones);
endmodule



// manages main timing state
module counter_m( input wire unsigned [0:0]clock,
                  input wire `FLAG_T set_flag,
                  input wire `COUNTER_T set_time,
                  output wire `COUNTER_T counter_state);
  reg `COUNTER_T _counter_state = 0;
  assign counter_state = _counter_state;

  always @( posedge clock) begin
    if( set_flag )
      _counter_state = set_time;
    else begin
      if( _counter_state < `COUNTER_MAX )
        _counter_state = _counter_state + 1;
      else
        _counter_state = 0;
      end
  end
endmodule



// manages alarm state
module alarm_m( input wire `COUNTER_T counter_state,
                input wire `FLAG_T set_flag,
                input wire `FLAG_T alarm_flag,
                input wire `COUNTER_T alarm_time,
                output wire `FLAG_T alarm_state);
  reg `FLAG_T _alarm_state = 0;
  assign alarm_state = _alarm_state;

  // Quartus doesn't like _alarm_state being driven from 2 different always loops...
  always @( alarm_flag, counter_state ) begin
    if( alarm_flag ) begin
      if( !set_flag ) begin
        if( counter_state == alarm_time )
          _alarm_state = 1;
      end
    end else
      _alarm_state = 0;
  end
endmodule



// manages output formatting. Since this system is based off the second timestamp, this can be
// easily adapted to a 24 hour clock, or a 6 hour clock, or hex output, or really whatever you want.
// Moral of the story: by design, changes to this module don't affect the operation of the clock.
module out_m( input wire [0:0]clock,
              input wire `COUNTER_T counter_state,
              input wire `FLAG_T alarm_state,
              output wire `SSD_T hour_tens,
              output wire `SSD_T hour_ones,
              output wire `SSD_T minute_tens,
              output wire `SSD_T minute_ones,
              output wire `SSD_T second_tens,
              output wire `SSD_T second_ones );

  reg `TIME_T _hour;
  reg `TIME_T _min;
  reg `TIME_T _sec;
  reg `FLAG_T _pm;

  reg `SSD_T _hour_tens;
  reg `SSD_T _hour_ones;
  reg `SSD_T _minute_tens;
  reg `SSD_T _minute_ones;
  reg `SSD_T _second_tens;
  reg `SSD_T _second_ones;
  assign hour_tens = _hour_tens;
  assign hour_ones = _hour_ones;
  assign minute_tens = _minute_tens;
  assign minute_ones = _minute_ones;
  assign second_tens = _second_tens;
  assign second_ones = _second_ones;

  // I'm lazy so I'm using a lookup table instead of logic
  reg `SSD_T _ssd_table [9:0];

  initial begin
    _ssd_table[0] = 8'b00000011;
    _ssd_table[1] = 8'b10011111;
    _ssd_table[2] = 8'b00100101;
    _ssd_table[3] = 8'b00001101;
    _ssd_table[4] = 8'b10011001;
    _ssd_table[5] = 8'b01001001;
    _ssd_table[6] = 8'b01000001;
    _ssd_table[7] = 8'b00011111;
    _ssd_table[8] = 8'b00000001;
    _ssd_table[9] = 8'b00001001;
  end

  // output on negative edges because all the action happens on positive edges. This way, we can be
  // sure everything has been calculated and pushed into the state registers before we print the
  // contents of those registers.
  always @( negedge clock ) begin
    // We could save a little time by not subtracting and letting integer division take care of
    // rounding off the numbers, but I think it's more readable this way.
    _sec = counter_state % `SEC_ROLLOVER;
    _min = ((counter_state - _sec) / `MIN_TICK) % `MIN_ROLLOVER;
    _hour = ((counter_state - _sec - (_min * `MIN_TICK)) / `HOUR_TICK) % `HOUR_ROLLOVER;
    if( (counter_state - _sec - (_min * `MIN_TICK) - (_hour * `HOUR_TICK)) / `AMPM_TICK )
      _pm = 1;
    else
      _pm = 0;

    // hour 0 is actually 12 - the assignment doesn't matter because we've already calculated AM/PM
    // and it'll get recalculated on the next run
    if( _hour == 0 )
      _hour = 12;

    /*
    _second_ones = _ssd_table[_sec % 10];
    _second_tens = _ssd_table[(_sec - _second_ones) / 10];
    _minute_ones = _ssd_table[_min % 10];
    _minute_tens = _ssd_table[(_min - _minute_ones) / 10];
    _hour_ones = _ssd_table[_hour % 10];
    _hour_tens = _ssd_table[(_hour - _hour_ones) / 10];
    */

    _second_ones = _ssd_table[counter_state / 1    % 10];
    _second_tens = _ssd_table[counter_state / 10   % 10];
    _minute_ones = _ssd_table[counter_state / 100  % 10];
    _minute_tens = _ssd_table[counter_state / 1000 % 10];
    _hour_ones = _ssd_table[counter_state / 10000  % 10];
    _hour_tens = _ssd_table[counter_state / 100000 % 10];
  end
endmodule
