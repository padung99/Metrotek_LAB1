module deserializer_tb;

parameter MAXIMUM_PACKAGE_TRANSFERED = 256;

bit          clk_i_tb;
logic        srst_i_tb;
logic        data_i_tb;
logic        data_val_i_tb;
logic [15:0] deser_data_o_tb;
logic        deser_data_val_o_tb;

initial
  forever  
    begin
      #5 clk_i_tb = !clk_i_tb;
    end

default clocking cb
  @( posedge clk_i_tb );
endclocking

typedef struct {
  logic data;
  logic valid;
} package_sended_t;

mailbox #( package_sended_t ) pk_sended   = new();
mailbox #( logic [15:0] )     pk_receive  = new();
mailbox #( logic [15:0] )     data_sended = new();

deserializer deser_dut(
  .clk_i            ( clk_i_tb            ),
  .srst_i           ( srst_i_tb           ),
  .data_i           ( data_i_tb           ),
  .data_val_i       ( data_val_i_tb       ),
  .deser_data_o     ( deser_data_o_tb     ),
  .deser_data_val_o ( deser_data_val_o_tb )
);

task gen_package( mailbox #( package_sended_t ) pk_gen );
for( int i = 0; i < MAXIMUM_PACKAGE_TRANSFERED; i++ )
  begin
    package_sended_t new_pk;
    new_pk.data  = $urandom_range( 0,1 );
    new_pk.valid = $urandom_range( 0,1 );
    pk_gen.put( new_pk ); 
  end
endtask

task send ( mailbox #( package_sended_t ) pks,
            mailbox #( logic [15:0] )     data_receive,
            mailbox #( logic [15:0] )     bit_send
          );
int cnt;
logic [15:0] data_send;

while( pks.num() != 0 )
  begin
    package_sended_t new_pks;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;

    if( deser_data_val_o_tb )
      data_receive.put( deser_data_o_tb );

    if( data_val_i_tb )
      begin
        data_send[15-cnt] = data_i_tb;
        cnt++;
      end

    if( cnt == 16 )
      begin
        bit_send.put( data_send );
        cnt = 0;
      end 
    ##1;
  end
endtask

task testing ( mailbox #( logic [15:0] ) data_receive,
               mailbox #( logic [15:0] ) bit_send
             );

while( data_receive.num() != 0 && bit_send.num() != 0 )
  begin
    logic [15:0] new_bit_s;
    logic [15:0] new_data_r;
    data_receive.get( new_data_r );
    bit_send.get( new_bit_s );
    $display( "[%0d] data received: %b, bit sended: %b", bit_send.num(), new_data_r, new_bit_s );
    if( new_data_r != new_bit_s )
      $display( "Error on receiving!!!\n" );
    else
      $display( "Data received correctly!!!\n" );
  end

if( bit_send.num() != 0 )
  $display("%0d more data in sending mailbox!!!", bit_send.num() );
else
  $display("Sending mailbox is empty!!!");

if( data_receive.num() != 0 )
  $display("%0d more data in receiving mailbox!!!", data_receive.num() );
else
  $display("Receiving mailbox is empty!!!");
endtask

initial
  begin
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;

    gen_package( pk_sended );
    send( pk_sended, pk_receive, data_sended );
    testing( pk_receive, data_sended );
      
    $display("#####Testing done!!!");
    $stop();
  end
endmodule