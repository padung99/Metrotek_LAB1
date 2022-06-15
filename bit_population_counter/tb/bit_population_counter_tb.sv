module bit_population_counter_tb;

parameter WIDTH_TB           = 16;
parameter MAX_PACKAGE_SENDED = 30;
parameter WIDTH_O            = $clog2(WIDTH_TB) + 1;

logic                          srst_i_tb;
logic [WIDTH_TB-1:0]           data_i_tb;
logic                          data_val_i_tb;
logic [WIDTH_O-1:0]            data_o_tb;
logic                          data_val_o_tb;

bit clk_i_tb;

initial 
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
  @( posedge clk_i_tb );
endclocking

bit_population_counter#(
      .WIDTH      ( WIDTH_TB      )
) dut (
      .clk_i      ( clk_i_tb      ),
      .srst_i     ( srst_i_tb     ),
      .data_i     ( data_i_tb     ),
      .data_val_i ( data_val_i_tb ),
      .data_o     ( data_o_tb     ),
      .data_val_o ( data_val_o_tb ) 
);

typedef struct {
  logic [15:0] data;
  logic        valid;
} package_sended;

mailbox #( package_sended )      pk_send     = new();
mailbox #( logic [WIDTH_O-1:0] ) ouput_data  = new();
mailbox #( logic [15:0] )        data_sended = new();

task gen_package ( mailbox #( package_sended ) pks );
for( int i = 0; i < MAX_PACKAGE_SENDED; i++ )
  begin
    package_sended new_pk;
    new_pk.data  = $urandom_range( 2**16-1, 0 );
    new_pk.valid = $urandom_range( 1,0 );
    pks.put( new_pk );        
  end
endtask

task send_pk( mailbox #( package_sended )      pks,
              mailbox #( logic [WIDTH_O-1:0] ) data_o,
              mailbox #( logic [15:0] )        sdata
            );

while( pks.num() != 0 )
  begin
    package_sended new_pks;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;

    if( data_val_o_tb )
      data_o.put( data_o_tb );
    
    if( data_val_i_tb )
      sdata.put( data_i_tb );

    ##1;
  end
endtask

task testing ( mailbox #( logic [WIDTH_O-1:0] ) data_o,
               mailbox #( logic [15:0] )        sdata
             );

int send;
int receive;
int cnt_send;
int cnt_receive;
send    = sdata.num();
receive = data_o.num();

$display( "###Sending" );
while( sdata.num() != 0 )
  begin
    logic [15:0] new_sdata;
    sdata.get( new_sdata );
    $display( "[%0d] data_i valid: %0b", sdata.num(), new_sdata );
  end

$display("###Sending done");
$display("Total valid data sended: %0d",  send );
$display("\n");

$display( "###Receiving" );

while( data_o.num() != 0 )
  begin
    logic [WIDTH_O-1:0] new_odata;
    data_o.get( new_odata );
    $display( "[%0d] data_o: %0d", data_o.num(), new_odata );
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
    gen_package( pk_send );
    send_pk( pk_send, ouput_data, data_sended );
    testing( ouput_data, data_sended );

    $display("Test done!!!!");
    $stop();

  end
endmodule