module bit_population_counter_tb;

parameter WIDTH_TB           = 16;
parameter MAX_PACKAGE_SEND   = 105;
parameter WIDTH_O            = $clog2(WIDTH_TB) + 1;

logic                          srst_i_tb;
logic [WIDTH_TB-1:0]           data_i_tb;
logic                          data_val_i_tb;
logic [WIDTH_O-1:0]            data_o_tb;
logic                          data_val_o_tb;

bit clk_i_tb;

initial 
  forever
    #4 clk_i_tb = !clk_i_tb;

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
  logic [WIDTH_TB-1:0] data;
  logic [WIDTH_O-1:0]  cnt_bit_1;
} data_send_t;

mailbox #( logic [WIDTH_O-1:0] ) output_data = new();
mailbox #( data_send_t )         data_sended = new();

task gen_package_send ( mailbox #( data_send_t ) sdata );
for( int i = 0; i < MAX_PACKAGE_SEND; i++ )
  begin
    data_send_t      new_dts;

    data_i_tb     = $urandom_range( 2**16-1, 0 );
    data_val_i_tb = $urandom_range( 1,0 );

    if( data_val_i_tb === 1'b1 )
      begin
        new_dts.cnt_bit_1 = $countones( data_i_tb );
        new_dts.data      = data_i_tb;
        sdata.put( new_dts );
      end
    ##1;
  end
endtask

task reveive_pk ( mailbox #( logic [WIDTH_O-1:0] ) data_o ); 
for( int i = 0; i < MAX_PACKAGE_SEND; i++ ) 
  begin
    if( data_val_o_tb === 1'b1)
        data_o.put( data_o_tb );
    ##1;
  end
endtask

task testing ( mailbox #( logic [WIDTH_O-1:0] ) data_o,
               mailbox #( data_send_t )         sdata
             );
$display( "Valid send:    %0d elements", sdata.num() );
$display( "Valid receive: %0d elements", data_o.num() );
while( sdata.num() != 0 && data_o.num() != 0 )
  begin
    logic [WIDTH_O-1:0] new_data_out;
    data_send_t         new_data_s;
    data_o.get( new_data_out );
    sdata.get( new_data_s );
    $display( "[%0d] data_i: %b", sdata.num(), new_data_s.data );
    if( new_data_s.cnt_bit_1 != new_data_out )
      begin
        $display("Error on counting!!!!\n");
        $display("Input: %0d, output: %0d", new_data_out, new_data_s.cnt_bit_1 );
      end
    else
      begin
        $display("Input: %0d, output: %0d", new_data_out, new_data_s.cnt_bit_1 );
        $display( "Module runs correctly!!!\n" );
      end
  end

if( sdata.num() != 0 )
  $display("%0d more data in sending mailbox!!!", sdata.num() );
else
  $display("Sending mailbox is empty!!!");

if( data_o.num() != 0 )
  $display("%0d more data in receiving mailbox!!!", data_o.num() );
else
  $display("Receiving mailbox is empty!!!");
endtask

initial
  begin 
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;  

    fork
      gen_package_send( data_sended );
      reveive_pk( output_data );
    join
    testing( output_data, data_sended );

    $display("Test done!!!!");
    //$stop();

  end
endmodule