module traffic_lights_tb;

parameter MAX_PACKAGE_SEND        = 50;

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

//Number of clk delay for each states
parameter CLK_FREQ_RED_YELLOW_TB  = CLK_FREQ_TB*TIME_RED_YELLOW_TB;
parameter CLK_FREQ_BLINK_GREEN_TB = CLK_FREQ_TB*BLINK_TIME_GREEN_TB;

//Total delay clk in standard mode (Running mode) - cmd_type_i = 0
parameter CLK_DELAY1 = GREEN_STATE_LOWER*CLK_FREQ_TB + CLK_FREQ_RED_YELLOW_TB + GREEN_STATE_LOWER*CLK_FREQ_TB + CLK_FREQ_BLINK_GREEN_TB + YELLOW_STATE_LOWER*CLK_FREQ_RED_YELLOW_TB;
parameter CLK_DELAY2 = GREEN_STATE_UPPER*CLK_FREQ_TB + CLK_FREQ_RED_YELLOW_TB + GREEN_STATE_UPPER*CLK_FREQ_TB + CLK_FREQ_BLINK_GREEN_TB + YELLOW_STATE_UPPER*CLK_FREQ_RED_YELLOW_TB;

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

  //light time (ms)
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
} package_send;

mailbox #( package_send ) pk_send    = new();
mailbox #( package_send ) pk_receive = new();

//Use "let" statement to return maximum between 2 elements
let max(a,b) = (a > b) ? a : b;

task gen_package( mailbox #( package_send ) pks );
for( int i = 0; i < MAX_PACKAGE_SEND; i++ )
  begin
    package_send new_pks;
    //Set cmt_type
    new_pks.type_cmd = $urandom_range( 5, 0 );

    //Set time for different states(Green and red: 30-40)
    if( new_pks.type_cmd == 3 || new_pks.type_cmd == 4 )
      new_pks.data = $urandom_range( GREEN_STATE_UPPER, GREEN_STATE_LOWER );
    else if( new_pks.type_cmd == 5 )
      new_pks.data = $urandom_range( YELLOW_STATE_UPPER, YELLOW_STATE_LOWER );
    else
      new_pks.data = $urandom_range( 2**16-1,0 );

    if( new_pks.type_cmd == 3 || new_pks.type_cmd == 4 || new_pks.type_cmd == 5 )
      new_pks.valid = 1;
    else
      new_pks.valid = $urandom_range( 1,0 );

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
    cmd_valid_i_tb = new_pks.valid;
    
    if( cmd_valid_i_tb )
      begin
        pkr.put( new_pks );
      end

    //To run all states in standard mode(Red --> RedYellow --> Green --> Blink green --> Yellow --> Red), we need to delay amount of clk, which is sum of all clk delay in each state
    if( cmd_type_i_tb == 0 && cmd_valid_i_tb )
      begin
        int pause;
        pause = max( CLK_DELAY1 + 2, CLK_DELAY2 + 2 );
        ##pause;
      end
    
    //clk delay in notransition mode
    if( cmd_type_i_tb == 2 && cmd_valid_i_tb )
      ##30;

    ##1; 
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