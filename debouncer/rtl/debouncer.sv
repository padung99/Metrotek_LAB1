module debouncer #(
  parameter CLK_FREQ_MHZ   = 50,
  parameter GLITCH_TIME_NS = 200
) (
  input  logic clk_i,
  input  logic key_i,
  output logic key_pressed_stb_o
);

localparam CLK_DELAY =  GLITCH_TIME_NS*CLK_FREQ_MHZ/1000;

logic                  key_prev;

//initialize signal because we don't have "reset" 
logic                  start_cnt = 0; 
logic [CLK_DELAY-1: 0] cnt       = 0;

logic                  key_tmp;
logic                  stable;

always_ff @( posedge clk_i )
  begin
    key_prev <= key_i; 

    //key_i != key_prev && !start_cnt: begin counting; cnt == CLK_DELAY: end counting ==> module will jump to this condition once
	 if( ( cnt == CLK_DELAY ) || ( key_i != key_prev && !start_cnt ) ) 
      begin
        cnt <= 0;  
        if( cnt != CLK_DELAY )
          begin
            start_cnt <= 1;
            stable    <= 0;
          end
        else
          begin
            start_cnt <= 0;
            stable    <= 1;
          end
      end 
    else
      begin
        if( start_cnt )
          cnt <= cnt + (CLK_DELAY)'(1);
        
        if( stable )
         key_pressed_stb_o <= key_i;
      end
  end

endmodule
