module serializer_tb;
parameter NUMBER_OF_PACKET = 208;

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
      if( !ser_data_val_o_tb && data_val_i_tb && !busy_o_tb )
        begin     
          tmp_mod = ( data_mod_i_tb == 4'd0 ) ? 5'd16 : data_mod_i_tb;  
                  
          //Put valid data to "sending mailbox" 
          if( tmp_mod > 2 )
            data_sended.put( new_spk.data >> 16 - tmp_mod );
          else
            begin
              if( tmp_mod == 0 )
                data_sended.put( new_spk.data );
            end     
        end
      
      //Concatenate all valid output bit to an array for comparison with input data
      if( ser_data_val_o_tb )  
        begin
          new_bit_r[tmp_mod-1 - cnt] = ser_data_o_tb;
          cnt++;
        end
      

      if( cnt == tmp_mod )
        begin
          //Set all invalid bit to '0'
          for( int i = 15; i >= cnt; i-- )
            new_bit_r[i] = 0;
          //Put valid data to "receving mailbox"    
          data_receive.put( new_bit_r );
          cnt = 0;
        end
      ##1; 
    end
endtask

task testing_package( mailbox #( logic [15:0] ) data_sended,
                      mailbox #( logic [15:0] ) data_receive         
                    );

int send, receive;
int cnt;

while( data_sended.num() != 0 && data_receive.num() != 0 )
  begin
    logic [15:0] new_pks;
    logic [15:0] new_data_r;
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