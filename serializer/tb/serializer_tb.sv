module serializer_tb;
parameter TEST_CNT         = 20;
parameter MAX_TIME_DELAY   = 10;
parameter NUMBER_OF_PACKET = 110;

bit          clk_i_tb;
logic        srst_i_tb;
logic [15:0] data_i_tb; 
logic [3:0]  data_mod_i_tb;
logic        data_val_i_tb;
logic        ser_data_o_tb;
logic        ser_data_val_o_tb;
logic        busy_o_tb;


mailbox #( logic [15:0] ) gen_data = new();

initial
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
    @( posedge clk_i_tb );
endclocking

serializer serializer_inst(
  .clk_i          ( clk_i_tb          ),
  .srst_i         ( srst_i_tb         ),
  .data_i         ( data_i_tb         ), 
  .data_mod_i     ( data_mod_i_tb     ),
  .data_val_i     ( data_val_i_tb     ),
  .ser_data_o     ( ser_data_o_tb     ),
  .ser_data_val_o ( ser_data_val_o_tb ),
  .busy_o         ( busy_o_tb         )
  );

//Create package to send
typedef struct {
  logic [15:0] data;
  logic [3:0]  mod;
  logic        valid;
} package_send_t;

mailbox #( package_send_t ) send_pk         = new();
mailbox #( logic [15:0] )   data_send_valid = new();
mailbox #( logic [15:0] )   data_receive    = new();

task gen_package( mailbox #( package_send_t ) pk );
  for( int i = 0; i < NUMBER_OF_PACKET; i++ )
    begin
      package_send_t new_pk;
      new_pk.data  = $urandom_range( 2**16-1,0 );
      new_pk.mod   = $urandom_range( 16,0 );
      new_pk.valid = $urandom_range( 1, 0);
      pk.put( new_pk );
    end
endtask

task send_package( mailbox #( package_send_t ) spk,
                   mailbox #( logic [15:0]   ) data_sended,
                   mailbox #( logic [15:0]   ) data_receive
                 );
  int cnt;
  while( spk.num() != 0 )
    begin
      package_send_t new_spk;
      logic [15:0]   new_bit_r;
      logic [4:0]    tmp_mod;
      spk.get( new_spk );
      data_i_tb     = new_spk.data;
      data_mod_i_tb = new_spk.mod;
      data_val_i_tb = new_spk.valid;

      //Save valid input data to mailbox:
      //In sending mailbox data will be more than in receiving mailbox "1 data"
      //because valid data can be pushed to "receving mailbox" when new data valid pushed to "sending mailbox" 
      if( !ser_data_val_o_tb && data_val_i_tb && !busy_o_tb )
        begin     
          //Put valid data to "sending mailbox" 
          if( data_mod_i_tb > 2  )
            data_sended.put( new_spk.data >> 16 - data_mod_i_tb );
          else
            begin
              if( data_mod_i_tb == 1 || data_mod_i_tb == 2 )
                data_sended.put( 16'd0 );

              if( data_mod_i_tb == 0 )
                data_sended.put( new_spk.data  );
            end
          
          //Set all invalid bit to '0'
          for( int i = 15; i >= cnt; i-- )
            new_bit_r[i] = 0;
          //Put valid data to "receving mailbox"    
          data_receive.put( new_bit_r );

          tmp_mod = ( data_mod_i_tb == 4'd0 ) ? 5'd16 : data_mod_i_tb;
          cnt = 0;
        end
      
      //combine all valid output data to an array for comparison with input data
      if( ser_data_val_o_tb )  
        begin
          new_bit_r[tmp_mod-1 - cnt] = ser_data_o_tb;
          cnt++;
        end
      ##1; 
    end
endtask

task testing_package( mailbox #( logic [15:0] ) data_sended,
                      mailbox #( logic [15:0] ) data_receive         
                    );

int send, receive;
int cnt;
logic [15:0] new_data_r;

//Throw out 1-st data in mailbox because it's trash data
data_receive.get( new_data_r );

while( data_sended.num() != 0 && data_receive.num() != 0 )
  begin
    logic [15:0] new_pks;
    data_receive.get( new_data_r );
    data_sended.get( new_pks );
    
    $display( "data sended: %b, data received: %b ", new_pks, new_data_r );
    if( new_pks != new_data_r )
      $display( "Error on receiving!!!\n" );
    else
      $display( "Data received correctly!!!\n" );
  end

if( data_sended.num() != 0 )
  $display("%0d more data in sending mailbox!!!", data_sended.num() );
else
  $display("Sending mailbox is empty!!!");

if( data_receive.num() != 0 )
  $display("%0d more data in receiving mailbox!!!", data_receive.num() );
else
  $display("Receiving mailbox is empty!!!");
endtask

initial
  begin
    srst_i_tb     <= 1;
    ##1;
    srst_i_tb     <= 0;

    gen_package  ( send_pk );

    send_package ( send_pk, data_send_valid, data_receive );

    testing_package( data_send_valid, data_receive );
    $display( "Test done!!!" );
    $stop();
  
  end

endmodule