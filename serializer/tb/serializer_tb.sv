module serializer_tb;
parameter TEST_CNT         = 20;
parameter MAX_TIME_DELAY   = 10;
parameter NUMBER_OF_PACKET = 75;

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
} package_send;

mailbox #( package_send ) send_pk         = new();
mailbox #( package_send ) data_send_valid = new();
mailbox #( logic        ) data_receive    = new();

task gen_package( mailbox #( package_send ) pk );
  for( int i = 0; i < NUMBER_OF_PACKET; i++ )
    begin
      package_send new_pk;
      new_pk.data  = $urandom_range( 2**16-1,0 );
      new_pk.mod   = $urandom_range( 16,0 );
      new_pk.valid = $urandom_range( 1, 0);
      pk.put( new_pk );
    end
endtask

task send_package( mailbox #( package_send ) spk,
                   mailbox #( package_send ) data_sended,
                   mailbox #( logic        ) data_receive
                 );
  
  while( spk.num() != 0 )
    begin
      package_send new_spk;
      spk.get( new_spk );
      data_i_tb     = new_spk.data;
      data_mod_i_tb = new_spk.mod;
      data_val_i_tb = new_spk.valid;

      //save valod input data to mailbox
      if( !ser_data_val_o_tb && data_val_i_tb && !busy_o_tb )
        data_sended.put( new_spk );
        
      //save valid output bits to mailbox
      if( busy_o_tb )  
        data_receive.put( ser_data_o_tb );
      ##1; 
    end
endtask

task testing_package( mailbox #( package_send ) data_sended,
                      mailbox #( logic        ) data_receive         
                    );

int send, receive;
int cnt;

send    = data_sended.num();
receive = data_receive.num();

while( data_sended.num() != 0 )
  begin
    package_send tmp_pk;
    data_sended.get(tmp_pk);
    $display( "[%0d] data_i: %0b, data_mod_i: %0d", data_sended.num(), tmp_pk.data, tmp_pk.mod );
  end
$display( "###Total valid data sended: %0d\n", send );

$display( "###Total valid bit received###");
while( data_receive.num() != 0 )
  begin
    logic tmp_ser_data;
    data_receive.get( tmp_ser_data );
    $display( "ser_data_o: %0b", tmp_ser_data );
    if( cnt[3:0] == 15 )
      $display("\n");
    cnt++;
  end
$display("-----------------Testing done--------------");
endtask

initial
  begin
    srst_i_tb     <= 1;
    ##1;
    srst_i_tb     <= 0;
  end

initial
  begin
    gen_package  ( send_pk );

    send_package ( send_pk, data_send_valid, data_receive );

    testing_package( data_send_valid, data_receive );
    $stop();
  
  end

endmodule