module debouncer_tb;
  
parameter CLK_FREQ_MHZ_TB   = 50; //50 MHz
parameter NOISE_PULSE       = 1000; //Number of noise clk
parameter GLITCH_TIME_NS_TB = ( 1.11*NOISE_PULSE*1000 )/CLK_FREQ_MHZ_TB;

parameter PRESS_NUMBER      = 30;

logic key_i_tb;
logic key_pressed_stb_o_tb;
bit   clk_i_tb;

int   cnt_1_duration;
int   cnt_0_duration;
int   cnt_signal;

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb 
  @( posedge clk_i_tb );
endclocking

debouncer #(
  .CLK_FREQ_MHZ      ( CLK_FREQ_MHZ_TB      ),
  .GLITCH_TIME_NS    ( GLITCH_TIME_NS_TB    )
) deb_dut (
  .clk_i             ( clk_i_tb             ),
  .key_i             ( key_i_tb             ),
  .key_pressed_stb_o ( key_pressed_stb_o_tb )
);

//Describing pressing key process with struct
typedef struct {
  int noise_before_stable;
  int stable_time_1;
  int noise_after_stable;
  int stable_time_0;
} press_key;

mailbox #( press_key ) pkey = new();

task gen_package ( mailbox #( press_key ) press,
                   bit                    noise_signal = 1
                 );
for( int i = 0; i < PRESS_NUMBER; i++ )
  begin
    press_key new_pk;

    //Generating noise signal
    if( noise_signal )
      begin
        new_pk.noise_before_stable = $urandom_range( 1.1*NOISE_PULSE, NOISE_PULSE );
        new_pk.stable_time_1       = $urandom_range( 3*NOISE_PULSE, 5*NOISE_PULSE );
        new_pk.noise_after_stable  = $urandom_range( 1.1*NOISE_PULSE, NOISE_PULSE );
        new_pk.stable_time_0       = $urandom_range( 3*NOISE_PULSE, 5*NOISE_PULSE );
      end
    else
      begin
         //Generating clean signal
        new_pk.noise_before_stable = 0;
        new_pk.stable_time_1       = $urandom_range( 3*NOISE_PULSE, 5*NOISE_PULSE );
        new_pk.noise_after_stable  = 0;
        new_pk.stable_time_0       = $urandom_range( 3*NOISE_PULSE, 5*NOISE_PULSE );
      end
    press.put( new_pk );
  end
endtask

task send_signal( mailbox #( press_key ) press );

while( press.num() != 0 )
  begin
    press_key new_pk;
    press.get( new_pk );

    for( int i = 0; i < new_pk.noise_before_stable; i++ )
      begin
        key_i_tb = $urandom_range( 1,0 );
        ##1;
        if( key_pressed_stb_o_tb )
          cnt_1_duration++;
        else
          cnt_0_duration++;
      end
    
    for( int i = 0; i < new_pk.stable_time_1; i++ )
      begin
        key_i_tb = 1;
        ##1;
        if( key_pressed_stb_o_tb )
          cnt_1_duration++;
        else
          cnt_0_duration++;
      end
    
    for( int i = 0; i < new_pk.noise_after_stable; i++ )
      begin
        key_i_tb = $urandom_range( 1,0 );
        ##1;
        if( key_pressed_stb_o_tb )
          cnt_1_duration++;
        else
          cnt_0_duration++;
      end
    
    for( int i = 0; i < new_pk.stable_time_0; i++ )
      begin
        key_i_tb = 0;
        ##1;
        if( key_pressed_stb_o_tb )
          cnt_1_duration++;
        else
          cnt_0_duration++;
      end
      cnt_signal++;
  end

endtask

initial
  begin
    gen_package( pkey, 1 );
    $display(" ###TEST 1: Sending noise signal ");
    send_signal( pkey );
    $display( "Average '1' duration: %f ", cnt_1_duration/PRESS_NUMBER );
    $display( "Average '0' duration: %f ", cnt_0_duration/PRESS_NUMBER );

    $display( "\n");
    cnt_1_duration = 0;
    cnt_0_duration = 0;
    
    gen_package( pkey, 0 );
    $display("###TEST 2: Sending clean signal");
    send_signal( pkey );
    cnt_1_duration = cnt_1_duration + NOISE_PULSE*2*PRESS_NUMBER;
    cnt_0_duration = cnt_0_duration + NOISE_PULSE*2*PRESS_NUMBER;
    $display( "Average '1' duration: %f ", cnt_1_duration/PRESS_NUMBER );
    $display( "Average '0' duration: %f ", cnt_0_duration/PRESS_NUMBER );

    $display( "Total signal sended: %0d, received: %0d", 2*PRESS_NUMBER, cnt_signal );
    $display( "Testing done!!!!" );
    $stop();
  end

endmodule 