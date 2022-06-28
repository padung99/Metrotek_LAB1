module traffic_lights_tb;

//Time in red state ~ time in green state
parameter GREEN_STATE_LOWER       = 30;
parameter GREEN_STATE_UPPER       = 40;

parameter YELLOW_STATE_LOWER      = 3;
parameter YELLOW_STATE_UPPER      = 5;

//Frequency in (MHz)
parameter CLK_FREQ_TB             = 2;

//Light time (ms)
parameter TIME_RED_YELLOW_TB      = 4;
parameter BLINK_TIME_GREEN_TB     = 12;

parameter HALF_PERIOD_BLINK_TB    = 1;

parameter MAX_PACKAGE_SEND        = 21;

parameter CLK_DELAY_STANDARD_MODE = (GREEN_STATE_UPPER*2 + YELLOW_STATE_UPPER + TIME_RED_YELLOW_TB + BLINK_TIME_GREEN_TB)*CLK_FREQ_TB;

bit          clk_i_tb;
logic        srst_i_tb;
logic [2:0]  cmd_type_i_tb;
logic        cmd_valid_i_tb;
logic [15:0] cmd_data_i_tb;
logic        red_o_tb;
logic        yellow_o_tb;
logic        green_o_tb;

logic        rst_done;
int          cnt_pakage;

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @( posedge clk_i_tb );
endclocking

traffic_lights #(
  .CLK_FREQ          ( CLK_FREQ_TB          ),
  .TIME_RED_YELLOW   ( TIME_RED_YELLOW_TB   ),
  .BLINK_TIME_GREEN  ( BLINK_TIME_GREEN_TB  ),
  .HALF_PERIOD_BLINK ( HALF_PERIOD_BLINK_TB )
  ) tf_inst (
  .clk_i             ( clk_i_tb             ),
  .srst_i            ( srst_i_tb            ),
  .cmd_type_i        ( cmd_type_i_tb        ),
  .cmd_valid_i       ( cmd_valid_i_tb       ),
  .cmd_data_i        ( cmd_data_i_tb        ),
  .red_o             ( red_o_tb             ),
  .yellow_o          ( yellow_o_tb          ),
  .green_o           ( green_o_tb           )
); 

typedef struct {
  logic [15:0] data;
  logic        valid;
  logic [2:0]  type_cmd;
  int          package_delay;
  // int          cnt_type[int] = '{default:1};
} package_send_t;

typedef struct {
  int red_clk [bit]    = '{default:0};
  int green_clk [bit]  = '{default:0};
  int yellow_clk [bit] = '{default:0};
} RYG_receive_t;

mailbox #( package_send_t ) pk_send    = new();
mailbox #( RYG_receive_t )  pk_receive = new();

logic [2:0] cmd_data [MAX_PACKAGE_SEND-1:0] = { 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd0, 3'd3, 3'd4, 3'd5, 3'd3, 3'd4, 3'd5, 3'd2, 3'd2, 3'd3, 3'd4, 3'd5, 3'd1, 3'd3, 3'd4, 3'd1 };
// logic [MAX_package_send_t-1:0] cmd_valid       = { 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 1'b1, 3'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1, 1'b1 };

//Use "let" statement to return maximum between 2 elements
let max(a,b) = (a > b) ? a : b;

task gen_package( mailbox #( package_send_t ) pks );
int cnt;
for( int i = 0; i < MAX_PACKAGE_SEND; i++ )
  begin
    package_send_t new_pks;
    //Set cmt_type
    new_pks.type_cmd = cmd_data[i];
    new_pks.valid    = 1;

    if( new_pks.type_cmd == 3 || new_pks.type_cmd == 4 )
      begin
        //new_pks.data = 35;
        new_pks.data = $urandom_range( GREEN_STATE_UPPER, GREEN_STATE_LOWER );
        //$display("%0d",new_pks.data );
      end
    else if( new_pks.type_cmd == 5 )
      begin
        //new_pks.data = 5;
        new_pks.data = $urandom_range( YELLOW_STATE_UPPER, YELLOW_STATE_LOWER );
        //$display("%0d",new_pks.data );
      end
    else
      new_pks.data = $urandom_range( 2**16-1,0 );
    
    if( new_pks.type_cmd == 3'd1 )
      new_pks.package_delay = 2;
    else if( new_pks.type_cmd == 3'd2 )
      new_pks.package_delay = 30;
    else if( new_pks.type_cmd == 3'd3 ||  new_pks.type_cmd == 3'd4 ||  new_pks.type_cmd == 3'd5 )
      new_pks.package_delay = 4;
    else if( new_pks.type_cmd == 3'd0 )
      new_pks.package_delay = CLK_DELAY_STANDARD_MODE;
      
    pks.put( new_pks );
  end
endtask

task send_package( mailbox #( package_send_t ) pks,
                   mailbox #( RYG_receive_t )  pkr
                 );


int red, green;
int yellow_blink;
int yellow_noblink;
int redundant_clk_yellow;
logic detect_0;
logic detect_1;
logic detect_2;
logic [15:0] set_red;
logic [15:0] set_green;
logic [15:0] set_yellow;
RYG_receive_t  new_ryg;
int cnt_cmd_2;
int cnt_cmd_1;
int cnt_cmd_0;
int iteration_0;
int redundant_clk;
int redundant_blink_green;
while( pks.num() != 0 )
  begin
    package_send_t new_pks;

    pks.get( new_pks );
    for( int i = 0; i < new_pks.package_delay; i++ )
      begin
        cmd_data_i_tb  = new_pks.data;
        cmd_type_i_tb  = new_pks.type_cmd;
        
        if( i == 0 )
          cmd_valid_i_tb = new_pks.valid;
        else
          cmd_valid_i_tb = 0;

        if( cmd_type_i_tb == 3'd2 )
          begin
            detect_2 <= 1;
            detect_0 <= 0;
            detect_1 <= 0;
          end
        
        if( detect_2 )
          begin
            cnt_cmd_2++;
            if( cmd_type_i_tb == 3'd3 )
              set_green = cmd_data_i_tb;
            if( cmd_type_i_tb == 3'd4 )
              set_red = cmd_data_i_tb;
            if( cmd_type_i_tb == 3'd5 )
              set_yellow = cmd_data_i_tb;
          end
        else
          begin
            redundant_clk_yellow = cnt_cmd_2 - cnt_cmd_2 >> 3;
            
            if( redundant_clk_yellow < 4 )
              yellow_blink = yellow_blink + (cnt_cmd_2 >> 3)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2 + redundant_clk_yellow;
            else 
              yellow_blink = yellow_blink + ((cnt_cmd_2 >> 3) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
      
            
            cnt_cmd_2 = 0;
          end

        if( cmd_type_i_tb == 3'd1 )
          begin
            detect_1  <= 1;
            detect_2  <= 0;
            detect_0  <= 0;
            //cnt_cmd_2 = 0;
          end
        if( cmd_type_i_tb == 3'd0 )
          begin
            detect_0  <= 1;
            detect_2  <= 0;
            detect_1  <= 0;
            //cnt_cmd_2 = 0;
          end
        if( detect_0 )
          begin
            cnt_cmd_0++;
          end
        else
          begin
              iteration_0  = cnt_cmd_0 / (( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB);
              redundant_clk = cnt_cmd_0 - iteration_0*( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB;
            //BLINK_TIME_GREEN_TB/4/2;

            if( redundant_clk <= set_red*CLK_FREQ_TB )
              begin
                red    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + redundant_clk;
                yellow_noblink = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB;
                green  = iteration_0*( set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB;
              end
            else if( redundant_clk <= ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB )
              begin
                red    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + redundant_clk;
                yellow_noblink = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + redundant_clk - set_red*CLK_FREQ_TB;
                green  = iteration_0*( set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB;
              end
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green )*CLK_FREQ_TB )
              begin
                red    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB;
                yellow_noblink = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB;
                green  = iteration_0*( set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB + redundant_clk - ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB;
              end
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB )
             begin
                red    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB;
                yellow_noblink = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB;
                green  = iteration_0*( set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB + set_green*CLK_FREQ_TB;
                redundant_blink_green = redundant_clk - ( set_red + TIME_RED_YELLOW_TB + set_green )*CLK_FREQ_TB;
                if( redundant_blink_green % 8 < 4 )
                  green = green + (redundant_blink_green/8)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
                else
                  green = green + (redundant_blink_green/8)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
              end
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB )
              begin
                red    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB ;
                yellow_noblink = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB + redundant_clk - ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB;
                green  = iteration_0*( set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB;
              end
          end

        new_ryg.red_clk[red_o_tb]++;
        new_ryg.green_clk[green_o_tb]++;
        new_ryg.yellow_clk[yellow_o_tb]++;
        ##1;
      end
    // $display("yellow_blink: %0d", yellow);
    // $display( "cnt_clk_cmd_2: %0d",cnt_cmd_2 );
    $display( "iteration_0: %0d, cmd_0: %0d, redundant_clk: %0d, red: %0d, green: %0d, yellow_noblink: %0d, yellow_blink: %0d,redundant_clk_yellow: %0d, cnt_cmd_2 / 8: %0d", iteration_0, cnt_cmd_0, redundant_clk, red, green, yellow_noblink, yellow_blink, redundant_clk_yellow, cnt_cmd_2 >> 3 );
  end
pkr.put(new_ryg);
$display( "red: %0d %0d, green: %0d %0d , yellow: %0d %0d", new_ryg.red_clk[0], new_ryg.red_clk[1], new_ryg.green_clk[0], new_ryg.green_clk[1], new_ryg.yellow_clk[0], new_ryg.yellow_clk[1] );

endtask

task testing( mailbox #( package_send_t ) pkr );

int total_cmd;

total_cmd = pkr.num();

while( pkr.num() != 0 )
  begin
    package_send_t new_pkr;
    pkr.get( new_pkr );
    $display( "[%0d] valid cmd: %0b", pkr.num() ,new_pkr.type_cmd );
  end
$display( "Total cmd sended: %0d",  cnt_pakage );
$display( "Total valid cmd: %0d", total_cmd );
endtask

initial
  begin
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
    rst_done  <= 0;
  end

initial
  begin
    wait( !rst_done );
    gen_package( pk_send );
    send_package( pk_send, pk_receive );
    // testing( pk_receive );
    $display( "###Test done!!!!" );
    $stop();
  end
endmodule