module debouncer #(
  parameter CLK_FREQ_MHZ   = 50,
  parameter GLITCH_TIME_NS = 200
) (
  input  logic clk_i,
  input  logic key_i,
  output logic key_pressed_stb_o
);

localparam CLK_DELAY =  GLITCH_TIME_NS*CLK_FREQ_MHZ/1000;

logic        key_prev;
logic        start_cnt; 
logic [15:0] cnt;

always_ff @( posedge clk_i )
  begin
    key_prev <= key_i;
    if( key_prev != key_i && cnt != CLK_DELAY )
      start_cnt <= 1'b1;
    else if( cnt == CLK_DELAY )
      start_cnt <= 1'b0;
  end

always_ff @( posedge clk_i )
  begin
    if( start_cnt )
      cnt <= cnt + 16'd1;
    else
      cnt <= 16'd0;
  end

always_ff @( posedge clk_i )
  begin
    if( cnt == CLK_DELAY )
      key_pressed_stb_o <= 1'b1;
    else
      key_pressed_stb_o <= 1'b0;
  end

endmodule
