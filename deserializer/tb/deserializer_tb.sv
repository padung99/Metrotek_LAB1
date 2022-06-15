module deserializer_tb;

parameter NUMBER_OF_BITS             = 50;
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
} package_sended;

mailbox #( package_sended ) pk_sended   = new();
mailbox #( logic [15:0]   ) pk_receive  = new();
mailbox #( logic          ) data_sended = new();

deserializer deser_dut(
  .clk_i            ( clk_i_tb            ),
  .srst_i           ( srst_i_tb           ),
  .data_i           ( data_i_tb           ),
  .data_val_i       ( data_val_i_tb       ),
  .deser_data_o     ( deser_data_o_tb     ),
  .deser_data_val_o ( deser_data_val_o_tb )
);

task gen_package( mailbox #( package_sended ) pk_gen );
for( int i = 0; i < MAXIMUM_PACKAGE_TRANSFERED; i++ )
  begin
    package_sended new_pk;
    new_pk.data  = $urandom_range( 0,1 );
    new_pk.valid = $urandom_range( 0,1 );
    pk_gen.put( new_pk ); 
  end
endtask

task send ( mailbox #( package_sended ) pks,
            mailbox #( logic [15:0]   ) data_receive,
            mailbox #( logic          ) bit_send
          );

while( pks.num() != 0 )
  begin
    package_sended new_pks;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;

    if( deser_data_val_o_tb )
      data_receive.put( deser_data_o_tb );

    if( data_val_i_tb )
      bit_send.put( data_i_tb );

    ##1;
  end
endtask

task testing ( mailbox #( logic [15:0]   ) data_receive,
               mailbox #( logic          ) bit_send
             );

int send;
int receive;
int cnt_send;
int cnt_receive;
send    = bit_send.num();
receive = data_receive.num();

$display( "###Sending" );
while( bit_send.num() != 0 )
  begin
    logic new_bit;
    bit_send.get( new_bit );
    $display( "[%0d] bit: %0b", 15 - cnt_send[3:0], new_bit );
    if( cnt_send[3:0] == 15 )
      $display( "\n" );
    cnt_send++;
  end
$display("###Sending done");
$display("Total bits sended: %0d",  send );
$display("Unused bits: %0d", send - receive*16); 
$display("\n");

$display( "###Receiving" );
while( data_receive.num() != 0 )
  begin
    logic [15:0] new_data;
    data_receive.get( new_data );
    $display( "[%0d] data_receive: %0b", data_receive.num(), new_data );
  end
$display("###Receiving done");
$display( "Total data received: %0d", receive );

endtask

initial
  begin
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;
  end

initial
  begin
    gen_package( pk_sended );
    send( pk_sended, pk_receive, data_sended );
    testing( pk_receive, data_sended );
      
    $display("Testing done");
    $stop();
  end
endmodule