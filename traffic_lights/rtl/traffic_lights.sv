module traffic_lights #(
  //frequency = 2kHz / period = 0.5 ms
  parameter CLK_FREQ              = 2,

  //light time (ms)
  parameter TIME_RED_YELLOW       = 10,
  parameter BLINK_TIME_GREEN      = 15,

  parameter HALF_PERIOD_BLINK     = 3 //max period = 1000 ms = 1s ==> max half period = 500ms = 0.5s
) (
  input  logic        clk_i,
  input  logic        srst_i,
  input  logic [2:0]  cmd_type_i,
  input  logic        cmd_valid_i,
  input  logic [15:0] cmd_data_i,
  output logic        red_o,
  output logic        yellow_o,
  output logic        green_o
);

localparam CLK_FREQ_RED_YELLOW   = CLK_FREQ*TIME_RED_YELLOW;
localparam CLK_FREQ_BLINK_GREEN  = CLK_FREQ*BLINK_TIME_GREEN;
localparam PERIOD_BLINK          = 2*HALF_PERIOD_BLINK;  
logic        turn_on;
logic        turn_off;
logic        notransition;
logic        set_yellow_time;
logic        set_red_time;
logic        set_green_time;

logic [15:0] time_red;
logic [15:0] time_yellow;
logic [15:0] time_green;

logic [15:0] clk_red;
logic [15:0] clk_yellow;
logic [15:0] clk_green;

logic [15:0] clk_red_yellow;
logic [15:0] clk_blink_green;

//Maximum blink period 1000 ms  = 1s ==> half period = 500ms ==> 9 bit
logic [8:0] cnt_blink_yellow;
logic [8:0] cnt_blink_green;

logic        timeout_yellow;
logic        timeout_green;
logic        timeout_red;

//Saving previous state of yellow_o and green_o to avoid error
//"always_comb construct does not infer purely combinational logic" in "control output" block FSM
logic        yellow_prev;
logic        green_prev;


enum logic [2:0] {
  IDLE_S,
  RED_S,
  RED_YELLOW_S,
  GREEN_S,
  BLINK_GREEN_S,
  YELLOW_S,
  NOTRANSITION_S
} state, next_state;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      state <= IDLE_S;
    else
      state <= next_state;
  end

//State control
always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S:
        begin
          if( turn_on && cmd_valid_i )
            next_state = RED_S;
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      RED_S:
        begin
          if( timeout_red ) 
            next_state = RED_YELLOW_S;
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S;
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      RED_YELLOW_S:
        begin
          if( clk_red_yellow == CLK_FREQ_RED_YELLOW - 16'd1)
            next_state = GREEN_S;
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S; 
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      GREEN_S:
        begin
          if( timeout_green ) 
            next_state = BLINK_GREEN_S;
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S;  
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      BLINK_GREEN_S:
        begin
          if( clk_blink_green == CLK_FREQ_BLINK_GREEN - 16'd1)
            next_state = YELLOW_S;
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S;
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      YELLOW_S:
        begin
          if( timeout_yellow ) 
            next_state = RED_S;
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S;
          if( notransition && cmd_valid_i )
            next_state = NOTRANSITION_S;
        end
      
      NOTRANSITION_S:
        begin
          if( turn_off && cmd_valid_i )
            next_state = IDLE_S;
          if( turn_on && cmd_valid_i )
            next_state = RED_S;
        end
      default:
        next_state = IDLE_S;
    endcase
  end

//output control
always_comb
  begin
    red_o    = 1'b0;
    yellow_o = yellow_prev;
    green_o  = green_prev;
    case( state )
      IDLE_S:
        begin
          red_o    = 1'b0;
          yellow_o = 1'b0;
          green_o  = 1'b0;
        end
      
      RED_S:
        begin
          red_o    = 1'b1;
          yellow_o = 1'b0;
          green_o  = 1'b0;
        end
      
      RED_YELLOW_S:
        begin
          red_o    = 1'b1;
          yellow_o = 1'b1;
          green_o  = 1'b0;
        end
      
      GREEN_S:
        begin
          red_o    = 1'b0;
          yellow_o = 1'b0;
          green_o  = 1'b1;
        end
      
      BLINK_GREEN_S:
        begin
          red_o    = 1'b0;
          yellow_o = 1'b0;

          //blink green
          if( cnt_blink_green == PERIOD_BLINK*CLK_FREQ - 9'd1 )
            green_o  = !green_o;
        end
      
      YELLOW_S:
        begin
          red_o    = 1'b0;
          yellow_o = 1'b1;
          green_o  = 1'b0;
        end
      
      NOTRANSITION_S:
        begin
          red_o    = 1'b0;
          green_o  = 1'b0;

          //blink yellow
          if( cnt_blink_yellow == PERIOD_BLINK*CLK_FREQ - 9'd1 )
            yellow_o  = !yellow_o;
        end        
    endcase
  end

//Timer control
always_ff @( posedge clk_i )
  begin
    if( state == IDLE_S )
      begin
        clk_red          <= 16'd0;
        clk_red_yellow   <= 16'd0; 
        clk_green        <= 16'd0;
        clk_blink_green  <= 16'd0;
        clk_yellow       <= 16'd0;
        timeout_green    <= 1'b0;
        timeout_red      <= 1'b0;
        timeout_yellow   <= 1'b0;
        cnt_blink_green  <= 9'd0;
        cnt_blink_yellow <= 9'd0;
        green_prev       <= green_o;
        yellow_prev      <= yellow_o;

      end
    else if( state == RED_S )
      begin   
        timeout_red <= 1'b0;
        if( clk_red == time_red*CLK_FREQ - 16'd2)
          begin
            clk_red     <= 16'd0;
            timeout_red <= 1'b1;
          end
        else if( !timeout_red )
          clk_red <= clk_red + 16'd1;
            
      end
    else if( state == RED_YELLOW_S )
      begin
        if( clk_red_yellow == CLK_FREQ_RED_YELLOW - 16'd1)
          clk_red_yellow <= 16'd0;
        else
          clk_red_yellow <= clk_red_yellow + 16'd1;
      end
    else if( state == GREEN_S )
      begin
        timeout_green <= 1'b0;
        if( clk_green == CLK_FREQ*time_green  - 16'd2)
          begin
            clk_green     <= 16'd0;
            timeout_green <= 1'b1;
          end
        else if( !timeout_green )
          clk_green <= clk_green + 16'd1;  
      end
    else  if( state == BLINK_GREEN_S )
      begin   
        green_prev <= green_o;
        if( clk_blink_green == CLK_FREQ_BLINK_GREEN - 16'd1 )
          clk_blink_green <= 16'd0;
        else if( cnt_blink_green == PERIOD_BLINK*CLK_FREQ - 9'd1 )
          cnt_blink_green <= 9'd0;
        else
          begin
            clk_blink_green <= clk_blink_green + 16'd1;
            cnt_blink_green <= cnt_blink_green + 9'd1;
          end
      end
    else if( state == YELLOW_S )
      begin  
         timeout_yellow <= 1'b0;
        if( clk_yellow == time_yellow*CLK_FREQ - 16'd2)
          begin
            clk_yellow     <= 16'd0;
            timeout_yellow <= 1'b1;
          end
        else if( !timeout_yellow )
          clk_yellow <= clk_yellow + 16'd1;    
      end
    else if( state == NOTRANSITION_S )
      begin
        yellow_prev <= yellow_o;
        if( cnt_blink_yellow == PERIOD_BLINK*CLK_FREQ - 9'd1 )
          cnt_blink_yellow <= 9'd0;
        else
          cnt_blink_yellow <= cnt_blink_yellow + 9'd1;
      end   
  end

always_ff @( posedge clk_i )
  begin
    if( cmd_valid_i )
      begin
        if( set_green_time )
          time_green  <= cmd_data_i;
        else if( set_red_time )
          time_red    <= cmd_data_i;
        else if( set_yellow_time )
          time_yellow <= cmd_data_i;
      end
  end

//Decode cmd_type_i
always_comb
  begin
    case( cmd_type_i )
      3'd0:
        begin
          turn_on         = 1'b1;
          turn_off        = 1'b0;
          notransition    = 1'b0;
          set_green_time  = 1'b0;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b0;
        end
      
      3'd1:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b1;
          notransition    = 1'b0;
          set_green_time  = 1'b0;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b0;
        end
      
      3'd2:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b0;
          notransition    = 1'b1;
          set_green_time  = 1'b0;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b0;
        end
      
      3'd3:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b0;
          notransition    = 1'b0;
          set_green_time  = 1'b1;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b0;
        end

      3'd4:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b0;
          notransition    = 1'b0;
          set_green_time  = 1'b0;
          set_red_time    = 1'b1;
          set_yellow_time = 1'b0;
        end

      3'd5:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b0;
          notransition    = 1'b0;
          set_green_time  = 1'b0;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b1;
        end
      default:
        begin
          turn_on         = 1'b0;
          turn_off        = 1'b0;
          notransition    = 1'b0;
          set_green_time  = 1'b0;
          set_red_time    = 1'b0;
          set_yellow_time = 1'b0;
        end
    endcase
  end

endmodule
