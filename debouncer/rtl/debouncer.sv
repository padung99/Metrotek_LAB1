module debouncer #(
  parameter CLK_FREQ_MHZ   = 50,
  parameter GLITCH_TIME_NS = 200
) (
  input  logic clk_i,
  input  logic key_i,
  output logic key_pressed_stb_o
);

localparam CLK_DELAY = GLITCH_TIME_NS*CLK_FREQ_MHZ/1000;
localparam GLITCH_W  = $clog2(CLK_DELAY) + 1;

logic [2:0]          key_prev;
logic [GLITCH_W-1:0] cnt;
logic                stable;

always_ff @( posedge clk_i )
  begin
    key_prev[0] <= key_i;
    key_prev[1] <= key_prev[0];
    key_prev[2] <= key_prev[1];
  end

always_ff @( posedge clk_i )
  begin
    if( cnt == CLK_DELAY )
      stable <= 1;
    //bouncing begin (key doesn't change in 2 pulses in a row)
    else if( key_prev[1] != key_prev[2] )
      stable <= 0;
  end

always_ff @( posedge clk_i )
  begin
    //key_prev[1] != key_prev[2]: begin bouncing => begin counting; cnt == CLK_DELAY: bouncing ended ==> reset cnt
    if( ( key_prev[1] != key_prev[2] ) || ( cnt == CLK_DELAY ) )
      cnt <= (GLITCH_W)'(0);
    //counting begin when key begins to bounce, if key is stable ==> cnt = 0 (no counting)
    else if( key_prev[1] == key_prev[2] && !stable )
      cnt <= cnt + (GLITCH_W)'(1);
  end

always_ff @( posedge clk_i )
  begin
    if( cnt == CLK_DELAY )
      key_pressed_stb_o <= 1'b1;
    else
      key_pressed_stb_o <= 1'b0;
  end

endmodule
