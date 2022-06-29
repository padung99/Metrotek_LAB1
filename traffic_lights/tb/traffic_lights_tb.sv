module traffic_lights_tb;

//Time in red state ~ time in green state
parameter GREEN_STATE_LOWER       = 28;
parameter GREEN_STATE_UPPER       = 45;

parameter YELLOW_STATE_LOWER      = 2;
parameter YELLOW_STATE_UPPER      = 6;

//Frequency in (MHz)
parameter CLK_FREQ_TB             = 2;

//Light time (ms)
parameter TIME_RED_YELLOW_TB      = 4;
parameter BLINK_TIME_GREEN_TB     = 8;
parameter CLK_DELAY_BLINK_GREEN   = BLINK_TIME_GREEN_TB*CLK_FREQ_TB;
parameter HALF_PERIOD_BLINK_TB    = 1; /// ( HALF_PERIOD_BLINK_TB*2 <= BLINK_TIME_GREEN_TB )

parameter MAX_PACKAGE_SEND        = 21;

parameter CLK_HALF_PERIOD_BLINK   = HALF_PERIOD_BLINK_TB*2*CLK_FREQ_TB;
parameter CLK_FULL_PERIOD_BLINK   =  CLK_HALF_PERIOD_BLINK*2;
parameter BIT_SHIFT               = $clog2(CLK_FULL_PERIOD_BLINK);
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
int          total_clk;

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
} package_send_t;

typedef struct {
  int red_clk [bit]    = '{default:0};
  int green_clk [bit]  = '{default:0};
  int yellow_clk [bit] = '{default:0};
} RYG_receive_t;

mailbox #( package_send_t ) pk_send = new();
RYG_receive_t               rgy_receive;
RYG_receive_t               rgy_data_in;

logic [2:0] cmd_data [MAX_PACKAGE_SEND-1:0] = { 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd0, 3'd3, 3'd4, 3'd5, 3'd3, 3'd4, 3'd5, 3'd2, 3'd2, 3'd3, 3'd4, 3'd5, 3'd1, 3'd3, 3'd4, 3'd1 };

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
      new_pks.data = $urandom_range( GREEN_STATE_UPPER, GREEN_STATE_LOWER );
    else if( new_pks.type_cmd == 5 )
      new_pks.data = $urandom_range( YELLOW_STATE_UPPER, YELLOW_STATE_LOWER );
    else
      new_pks.data = $urandom_range( 2**16-1,0 );
    
    if( new_pks.type_cmd == 3'd1 )
      new_pks.package_delay = 5;
    else if( new_pks.type_cmd == 3'd2 )
      new_pks.package_delay = 30;
    else if( new_pks.type_cmd == 3'd3 ||  new_pks.type_cmd == 3'd4 ||  new_pks.type_cmd == 3'd5 )
      new_pks.package_delay = 4;
    else if( new_pks.type_cmd == 3'd0 )
      // Test cases:
      // new_pks.package_delay = CLK_DELAY_STANDARD_MODE; ////////t < red
      // new_pks.package_delay = CLK_DELAY_STANDARD_MODE + 3*TIME_RED_YELLOW_TB*CLK_FREQ_TB; //////t < red + red_yellow;
      // new_pks.package_delay = CLK_DELAY_STANDARD_MODE + ( GREEN_STATE_UPPER + TIME_RED_YELLOW_TB )*CLK_FREQ_TB; /////////t < red + red_yellow + green;
      new_pks.package_delay = CLK_DELAY_STANDARD_MODE + ( GREEN_STATE_UPPER + TIME_RED_YELLOW_TB + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB; /////////t < red + red_yellow + green + blink_green;
      // new_pks.package_delay = CLK_DELAY_STANDARD_MODE + ( GREEN_STATE_UPPER + TIME_RED_YELLOW_TB + BLINK_TIME_GREEN_TB + 5)*CLK_FREQ_TB; ////t < red + red_yellow + green + blink_green + yellow;

    pks.put( new_pks );
  end
endtask

task send_package( mailbox #( package_send_t ) pks,
                   output  RYG_receive_t       new_ryg,
                           RYG_receive_t       data_in,
                           int                 cnt_total_clk
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

logic [15:0] cnt_cmd_2;
logic [15:0] cnt_cmd_1;
logic [15:0] cnt_cmd_0;

int iteration_0;
int redundant_clk;
int redundant_blink_green;
int tmp_green, tmp_green2;

cnt_cmd_2 = 16'd0;
cnt_cmd_1 = 16'd0;
cnt_cmd_0 = 16'd0;

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
          //Calculate number of clk corresponding to yellow blink
          begin
            redundant_clk_yellow = cnt_cmd_2 - ( cnt_cmd_2 >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK;
            
            if( redundant_clk_yellow < CLK_HALF_PERIOD_BLINK )
              yellow_blink =  yellow_blink + (cnt_cmd_2 >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2 + redundant_clk_yellow;
            else 
              yellow_blink =  yellow_blink + ((cnt_cmd_2 >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2; 
              
            cnt_cmd_2 = 16'd0;
          end

        if( cmd_type_i_tb == 3'd1 )
          begin
            detect_1  <= 1;
            detect_2  <= 0;
            detect_0  <= 0;
          end

        if( cmd_type_i_tb == 3'd0 )
          begin
            detect_0  <= 1;
            detect_2  <= 0;
            detect_1  <= 0;
          end
        
        //Testcase: red -- red_yellow -- green -- blink_green --yellow
        //red_o = 1 when state = red / red_yellow otherwise red_o = 0;
        //yellow_o = 1 when state = red_yellow /yellow/ notransition(yellow blink) otherwise yellow_o = 0;
        //green_o = 1 when state = green / blink_green otherwise green_o = 0;
        //In standard mode, only cmd_type = 1 or cmd_type = 2 will change traffic light's state
        //We will change "standard time" ( time in "standard mode", cmd_type = 0 ) to test different cases:
        //For example: We set "standard time" = 65 clk ( time red = 20, time red_yellow = 5, time green = 18, time blink_green = 4, time yellow = 3 )
        //==> To run all state in standard mode, traffic light need minimum 20+5+18+4+3 = 50 clk, but we set "standard time" = 65 clk
        //==> We will have 65-50 = 15 redundant clk ==> after running all states in standard mode( after 50 clk ), but cmd_type still = 0
        //==> traffic light will be in "RED state" before change to "notransition" (because we have more 15 clk)
        //Divide these cases into 5 intervals
        //t < red;
        //t < red + red_yellow;
        //t < red + red_yellow + green;
        //t < red + red_yellow + green + blink_green;
        //t < red + red_yellow + green + blink_green + yellow;
        if( detect_0 )
          begin
            cnt_cmd_0++;
          end
        else
          begin
              iteration_0   = cnt_cmd_0 / (( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB);
              redundant_clk = cnt_cmd_0 - iteration_0*( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB;

            //t < red;  
            if( redundant_clk < set_red*CLK_FREQ_TB )
              begin
                red                   = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + redundant_clk;
                yellow_noblink        = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB;    
                //Calculate number of clk corresponding to green blink
                redundant_blink_green = CLK_DELAY_BLINK_GREEN - ( CLK_DELAY_BLINK_GREEN >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK; 
                if( redundant_blink_green < CLK_HALF_PERIOD_BLINK )
                  tmp_green = (CLK_DELAY_BLINK_GREEN >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2+ redundant_blink_green;
                else 
                  tmp_green = ((CLK_DELAY_BLINK_GREEN >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;

                green  = iteration_0*set_green*CLK_FREQ_TB + tmp_green;
              end
            
            //t < red + red_yellow;
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB )
              begin
                red                    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + redundant_clk;
                yellow_noblink         = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + redundant_clk - set_red*CLK_FREQ_TB;
                redundant_blink_green = CLK_DELAY_BLINK_GREEN - ( CLK_DELAY_BLINK_GREEN >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK; 
                if( redundant_blink_green < CLK_HALF_PERIOD_BLINK )
                  tmp_green = (CLK_DELAY_BLINK_GREEN >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2+ redundant_blink_green;
                else 
                  tmp_green = ((CLK_DELAY_BLINK_GREEN >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;

                green  = iteration_0*set_green*CLK_FREQ_TB + tmp_green;
              end

            //t < red + red_yellow + green;
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green )*CLK_FREQ_TB )
              begin
                red                   = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB;
                yellow_noblink        = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB;
                redundant_blink_green = CLK_DELAY_BLINK_GREEN - ( CLK_DELAY_BLINK_GREEN >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK;

                //Calculate number of clk corresponding to green blink
                if( redundant_blink_green < CLK_HALF_PERIOD_BLINK )
                  tmp_green = (CLK_DELAY_BLINK_GREEN >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2+ redundant_blink_green;
                else 
                  tmp_green = ((CLK_DELAY_BLINK_GREEN >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;

                green  = iteration_0*set_green*CLK_FREQ_TB + tmp_green + (redundant_clk - ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB);
              end     

            //t < red + red_yellow + green + blink_green;
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB )
             begin
                red                    = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB;
                yellow_noblink         = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB;
       
                 //Calculate number of clk corresponding to green blink
                redundant_blink_green = CLK_DELAY_BLINK_GREEN - ( CLK_DELAY_BLINK_GREEN >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK; 
                if( redundant_blink_green < CLK_HALF_PERIOD_BLINK )
                  tmp_green = (CLK_DELAY_BLINK_GREEN >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2+ redundant_blink_green;
                else 
                  tmp_green = ((CLK_DELAY_BLINK_GREEN >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
                
                //Calculate unfull blink_green( blink_green --> notransition)
                redundant_blink_green = redundant_clk - ( set_red + TIME_RED_YELLOW_TB + set_green )*CLK_FREQ_TB;
                if( redundant_blink_green % CLK_FULL_PERIOD_BLINK < CLK_HALF_PERIOD_BLINK )
                  tmp_green2 = (redundant_blink_green >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
                else
                  tmp_green2 = ( (redundant_blink_green >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;
                green = (iteration_0 + 1)*set_green*CLK_FREQ_TB + tmp_green + tmp_green2;
              end

            //t < red + red_yellow + green + blink_green + yellow;
            else if( redundant_clk < ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB + set_yellow )*CLK_FREQ_TB )
              begin
                red                   = iteration_0*( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB + ( set_red + TIME_RED_YELLOW_TB )*CLK_FREQ_TB ;
                yellow_noblink        = iteration_0*( TIME_RED_YELLOW_TB + set_yellow )*CLK_FREQ_TB + TIME_RED_YELLOW_TB*CLK_FREQ_TB + redundant_clk - ( set_red + TIME_RED_YELLOW_TB + set_green + BLINK_TIME_GREEN_TB )*CLK_FREQ_TB;

                 //Calculate number of clk corresponding to green blink
                redundant_blink_green = CLK_DELAY_BLINK_GREEN - ( CLK_DELAY_BLINK_GREEN >> BIT_SHIFT )*CLK_FULL_PERIOD_BLINK; 
                if( redundant_blink_green < CLK_HALF_PERIOD_BLINK )
                  tmp_green = (CLK_DELAY_BLINK_GREEN >> BIT_SHIFT)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2+ redundant_blink_green;
                else 
                  tmp_green = ((CLK_DELAY_BLINK_GREEN >> BIT_SHIFT) + 1)*CLK_FREQ_TB*HALF_PERIOD_BLINK_TB*2;

                green  = (iteration_0 + 1)*set_green*CLK_FREQ_TB + tmp_green*2;
              end
          end

        //Count number of clk corresponding to bit 0 and bit 1 for red- green - yellow from ouput 
        new_ryg.red_clk[red_o_tb]++;
        new_ryg.green_clk[green_o_tb]++;
        new_ryg.yellow_clk[yellow_o_tb]++;
        ##1;
        cnt_total_clk++;
      end
  end
//Take number of clk in bit 0 and bit 1 for red- green - yellow from input parameters
data_in.red_clk[1]    = red;
data_in.red_clk[0]    = cnt_total_clk - red;
data_in.green_clk[1]  = green;
data_in.green_clk[0]  = cnt_total_clk - green;
data_in.yellow_clk[1] = yellow_blink + yellow_noblink;
data_in.yellow_clk[0] = cnt_total_clk - ( yellow_blink + yellow_noblink );
endtask

task testing( RYG_receive_t new_ryg,
              RYG_receive_t data_in
            );
bit check_err_r, check_err_g, check_err_y;

if( new_ryg.red_clk[0] + new_ryg.red_clk[1] != total_clk )
  begin
    $display(" Error on red: Number of clk received non equal to total clk ");
    check_err_r = 1;
  end

if( new_ryg.green_clk[0] + new_ryg.green_clk[1] != total_clk )
  begin
    $display(" Error on green: Number of clk received non equal to total clk ");
    check_err_g = 1;
  end
if( new_ryg.yellow_clk[0] + new_ryg.yellow_clk[1] != total_clk )
  begin
    $display(" Error on yellow: Number of clk received non equal to total clk ");
    check_err_y = 1;
  end

if( new_ryg.red_clk[0] != data_in.red_clk[0] || new_ryg.red_clk[1] != data_in.red_clk[1] )
  begin
    $display(" Error on red: clk received and clk set non equal");
    check_err_r = 1;
  end
if( new_ryg.green_clk[0] != data_in.green_clk[0] || new_ryg.green_clk[1] != data_in.green_clk[1] )
  begin
    $display(" Error on green: clk received and clk set non equal ");
    check_err_g = 1;
  end
if( new_ryg.yellow_clk[0] != data_in.yellow_clk[0] || new_ryg.yellow_clk[1] != data_in.yellow_clk[1] )
  begin
    $display(" Error on yellow: clk received and clk set non equal ");
    check_err_y = 1;
  end

$display( "Total clk: %0d", total_clk );
$display( "###input   red: [0] %0d [1] %0d, green: [0] %0d [1] %0d , yellow: [0] %0d [1] %0d", data_in.red_clk[0], data_in.red_clk[1], data_in.green_clk[0], data_in.green_clk[1], data_in.yellow_clk[0], data_in.yellow_clk[1] );
$display( "###Output  red: [0] %0d [1] %0d, green: [0] %0d [1] %0d , yellow: [0] %0d [1] %0d", new_ryg.red_clk[0], new_ryg.red_clk[1], new_ryg.green_clk[0], new_ryg.green_clk[1], new_ryg.yellow_clk[0], new_ryg.yellow_clk[1] );

if( !check_err_r && !check_err_g && !check_err_y )
  $display( "No error!!!!" );
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
    send_package( pk_send, rgy_receive, rgy_data_in, total_clk );
    testing( rgy_receive, rgy_data_in );
    $display( "###Test done!!!!" );
    $stop();
  end
endmodule