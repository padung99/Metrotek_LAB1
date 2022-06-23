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

parameter MAX_PACKAGE_SEND        = 1000;

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
  int          cnt_type[int] = '{default:1};
} package_send;

mailbox #( package_send ) pk_send    = new();
mailbox #( package_send ) pk_receive = new();

//Use "let" statement to return maximum between 2 elements
let max(a,b) = (a > b) ? a : b;

task gen_package( mailbox #( package_send ) pks );
int cnt;
for( int i = 0; i < MAX_PACKAGE_SEND; i++ )
  begin
    package_send new_pks;
    //Set cmt_type
    new_pks.type_cmd = $urandom_range( 5, 0 );
    cnt = new_pks.cnt_type[new_pks.type_cmd]++;

    //------------------Input of module will be chosen by these rule--------------
    //Set time for different states(Green and red: 30-40)
    if( new_pks.type_cmd == 3 || new_pks.type_cmd == 4 )
      new_pks.data = $urandom_range( GREEN_STATE_UPPER, GREEN_STATE_LOWER );
    else if( new_pks.type_cmd == 5 )
      new_pks.data = $urandom_range( YELLOW_STATE_UPPER, YELLOW_STATE_LOWER );
    else
      new_pks.data = $urandom_range( 2**16-1,0 );

    //First cmd = 2 (notransition mode) will be valid
    if( new_pks.type_cmd == 2 && new_pks.cnt_type[2] == 2 )
      new_pks.valid = 1;
    
    //notransition mode can't be valid until 500 cmd has been sent
    else if ( new_pks.type_cmd == 2 && i < MAX_PACKAGE_SEND/2 )
      new_pks.valid = 0;
    
    //"setting time" mode (cmd = 3,4,5) always valid, but time can be set only when light is on notransition mode, in other states, module will ignore these cmd 
    else if( ( new_pks.type_cmd == 3 || new_pks.type_cmd == 4 || new_pks.type_cmd == 5 ) && new_pks.cnt_type[2] >= 2 )
      new_pks.valid = 1;

    //"Standard" mode will begin after yellow has blinked 100 first clk (notransition mode will be delayed in first 100 clk)
    else if( new_pks.type_cmd == 0 && i < 100 )
      new_pks.valid = 0;

    //"Turn off" mode could begin until 500 first clk (It means light can be turned off in first 500 clk)
    else if( new_pks.type_cmd == 1 && i < MAX_PACKAGE_SEND/2 )
      new_pks.valid = 0;
      
    pks.put( new_pks );
  end
endtask

task send_package( mailbox #( package_send ) pks,
                   mailbox #( package_send ) pkr
                 );

cnt_pakage = pks.num();

while( pks.num() != 0 )
  begin
    package_send new_pks;

    pks.get( new_pks );
    cmd_data_i_tb  = new_pks.data;
    cmd_type_i_tb  = new_pks.type_cmd;

    if( new_pks.valid == 1 )
      cmd_valid_i_tb = 1;
    
    if( cmd_valid_i_tb )
      pkr.put( new_pks );

    ##1;
    cmd_valid_i_tb = 0;   
  end
endtask

task testing( mailbox #( package_send ) pkr );

int total_cmd;

total_cmd = pkr.num();

while( pkr.num() != 0 )
  begin
    package_send new_pkr;
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
    testing( pk_receive );
    $display( "###Test done!!!!" );
    $stop();
  end
endmodule