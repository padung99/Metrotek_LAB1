module debouncer_tb;
  
parameter CLK_FREQ_MHZ_TB         = 50; //MHz
parameter KEY_PULSE_NUMBER        = 50; 
parameter NOISE_PULSE             = 1000; //Number of clk
parameter MAX_DELAY_1_PULSE_NOISE = 5;
parameter CLK_DELAY_TB            =  NOISE_PULSE*MAX_DELAY_1_PULSE_NOISE*2; //Number of delay clk (2 delay states: pause1 for '1' and pause0 for '0')
parameter GLITCH_TIME_NS_TB       = CLK_DELAY_TB*1000/CLK_FREQ_MHZ_TB; //




parameter PRESS_NUMBER = 20;

logic key_i_tb;
logic key_pressed_stb_o_tb;
bit   clk_i_tb;
int   cnt_pulse;


initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb 
  @( posedge clk_i_tb );
endclocking

debouncer #(
  .CLK_FREQ_MHZ      ( CLK_FREQ_MHZ_TB      ),
  .GLITCH_TIME_NS    ( GLITCH_TIME_NS_TB    ) // GLITCH_TIME_NS*(10^-9)/[(1/CLK_FREQ_MHZ)*(10^-6)]) = N clk
) deb_dut (
  .clk_i             ( clk_i_tb             ),
  .key_i             ( key_i_tb             ),
  .key_pressed_stb_o ( key_pressed_stb_o_tb )
);

task generate_press_signal();
int random_glitch;
int pause1, pause0;
for( int i = 0; i < PRESS_NUMBER; i++ )
  begin
    pause0        = $urandom_range( 15,2 );
    random_glitch = $urandom_range( 8, CLK_DELAY_TB + 2 );
    for( int j = 0; j < random_glitch; j++ )
      begin
        key_i_tb <= 1;
        ##1;
        key_i_tb <= 0;
        ##1;
      end
    ##pause0;
  end
endtask

task generate_pulse_noise();
int pause1, pause0, pause_key; 

for( int j = 0; j < KEY_PULSE_NUMBER; j++)
  begin
  pause_key = $urandom_range( 3*10*NOISE_PULSE, 6*10*NOISE_PULSE );
    
    //Generating noise
    for( int i = 0; i < NOISE_PULSE; i++ )
      begin
        pause1   = $urandom_range(1,MAX_DELAY_1_PULSE_NOISE);
        pause0   = $urandom_range(1,MAX_DELAY_1_PULSE_NOISE);
        key_i_tb <= 1;
        ##pause1;
        key_i_tb <= 0;
        ##pause0;
      end
    key_i_tb = 1;
    ##pause_key;

    //Generating noise
    for( int i = 0; i < NOISE_PULSE; i++ )
      begin
        pause1   = $urandom_range( 1,MAX_DELAY_1_PULSE_NOISE );
        pause0   = $urandom_range( 1,MAX_DELAY_1_PULSE_NOISE );
        key_i_tb = 1;
        ##pause1;
        key_i_tb = 0;
        ##pause0;
      end
    
    key_i_tb <= 0;
    ##pause_key; 
  end
endtask

task generate_pulse_without_noise();
int pause1, pause0, pause_key; 

for( int j = 0; j < KEY_PULSE_NUMBER; j++)
  begin
  pause_key  = $urandom_range( 3*10*NOISE_PULSE, 6*10*NOISE_PULSE );
  key_i_tb  <= 1;
  ##pause_key;
    
  key_i_tb  <= 0;
  ##pause_key;
  end
endtask

task test_reveive_pulse ();
  repeat( KEY_PULSE_NUMBER - 1 )
    begin
      @( posedge key_pressed_stb_o_tb );
      cnt_pulse++;
    end

endtask

initial
  begin
    $display("Test 1: Send clean signal");
    $display("------Sending key signal-------");
    fork
      generate_pulse_without_noise();
      test_reveive_pulse ();
    join
    $display("Test 1 done!!!!\n");

    $display("Test 2: Send signal with noise");
    $display("------Sending key signal-------");
    fork
      generate_pulse_noise();
      test_reveive_pulse ();
    join

    $display("Test 2  done!!!!\n");
    $display("Total signal received: %0d ", cnt_pulse);
    $display("Testing done, check result on simulation screen!!!!");
    $stop();
  end

endmodule 