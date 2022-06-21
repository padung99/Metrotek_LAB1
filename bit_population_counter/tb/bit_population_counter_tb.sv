module bit_population_counter_tb;

parameter WIDTH_TB           = 16;
parameter MAX_PACKAGE_SEND   = 100;
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
  logic [WIDTH_TB-1:0] data;
  logic                valid;
} package_sended_t;

typedef struct {
  logic [WIDTH_TB-1:0] data;
  logic [WIDTH_O-1:0]  cnt_bit_1;
} data_send_t;

mailbox #( package_sended_t )    pk_send     = new();
mailbox #( logic [WIDTH_O-1:0] ) output_data  = new();
mailbox #( data_send_t )         data_sended = new();

task gen_package ( mailbox #( package_sended_t ) pks );
for( int i = 0; i < MAX_PACKAGE_SEND; i++ )
  begin
    package_sended_t new_pk;
    new_pk.data  = $urandom_range( 2**16-1, 0 );
    new_pk.valid = $urandom_range( 1,0 );
    pks.put( new_pk );        
  end
endtask

task send_pk( mailbox #( package_sended_t )    pks,
              mailbox #( logic [WIDTH_O-1:0] ) data_o,
              mailbox #( data_send_t )         sdata
            );
logic [WIDTH_O-1:0] cnt;
while( pks.num() != 0 )
  begin
    package_sended_t new_pks;
    data_send_t      new_dts;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;

    if( data_val_o_tb )
      data_o.put( data_o_tb );
    
    if( data_val_i_tb )
      begin
        new_dts.cnt_bit_1 = $countones(data_i_tb);
        new_dts.data      = data_i_tb;
        sdata.put( new_dts );
      end
    ##1;
  end
endtask

task testing ( mailbox #( logic [WIDTH_O-1:0] ) data_o,
               mailbox #( data_send_t )         sdata
             );

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
endtask

initial
  begin 
    srst_i_tb <= 1;
    ##1;
    srst_i_tb <= 0;  
    gen_package( pk_send );
    send_pk( pk_send, output_data, data_sended );
    testing( output_data, data_sended );

    $display("Test done!!!!");
    $stop();

  end
endmodule