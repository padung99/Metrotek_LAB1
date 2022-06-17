module priority_encoder_tb;

parameter WIDTH_TB           = 5;
parameter MAX_PACKAGE_SENDED = 2**(WIDTH_TB+1)+1;

bit                  clk_i_tb;

logic                srst_i_tb;
logic [WIDTH_TB-1:0] data_i_tb;
logic                data_val_i_tb;
logic [WIDTH_TB-1:0] data_left_o_tb;
logic [WIDTH_TB-1:0] data_right_o_tb;
logic                data_val_o_tb;

initial 
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
    @( posedge clk_i_tb );
endclocking

priority_encoder#(  
  .WIDTH        ( WIDTH_TB        )
) dut (
  .clk_i        ( clk_i_tb        ),
  .srst_i       ( srst_i_tb       ),
  .data_i       ( data_i_tb       ),
  .data_val_i   ( data_val_i_tb   ),
  .data_left_o  ( data_left_o_tb  ),
  .data_right_o ( data_right_o_tb ),
  .data_val_o   ( data_val_o_tb   ) 
);

//create package to send
typedef struct {
  logic [WIDTH_TB-1:0] data;
  logic                valid;
}send_pkg_t; 

//create struct from data_left_ and data_right_o  
typedef struct {
  logic [WIDTH_TB-1:0] left;
  logic [WIDTH_TB-1:0] right;
}data_receive_t;

mailbox #( send_pkg_t )           pk_sended  = new();
mailbox #( data_receive_t )       pk_receive = new();
mailbox #( logic [WIDTH_TB-1:0] ) data_valid = new();

task gen_package ( mailbox #( send_pkg_t ) pk_s );

for( int i = 0; i < MAX_PACKAGE_SENDED; i++ ) 
  begin
    send_pkg_t new_pks;
    new_pks.data  = $urandom_range( 2**WIDTH_TB-1,0 );
    new_pks.valid = $urandom_range( 1,0 );
    pk_s.put( new_pks );
  end

endtask

task send_pacakge( mailbox #( send_pkg_t )           pks,
                   mailbox #( data_receive_t )       pkr,
                   mailbox #( logic [WIDTH_TB-1:0] ) data
                 );

while( pks.num() != 0 )
  begin
    send_pkg_t new_pks;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;
    if( data_val_i_tb )
      data.put( data_i_tb );
    
    if( data_val_o_tb )
      begin
        data_receive_t new_receive;
        new_receive.left  = data_left_o_tb;
        new_receive.right = data_right_o_tb;
        pkr.put( new_receive );
      end
    ##1;
  end
endtask

task testing( mailbox #( data_receive_t )       pkr,
              mailbox #( logic [WIDTH_TB-1:0] ) data
            );
while( ( data.num() != 0 ) && ( pkr.num() != 0 ) )
  begin
    logic [WIDTH_TB-1:0] new_data;
    logic [WIDTH_TB-1:0] left_tmp;
    logic [WIDTH_TB-1:0] right_tmp;
    data_receive_t       new_pkr;
    pkr.get( new_pkr );
    data.get( new_data );

    for( int i = 0; i < WIDTH_TB; i++ )
      begin
        left_tmp[i]  = new_data[i] & new_pkr.left[i];
        right_tmp[i] = new_data[i] & new_pkr.right[i];
      end

    $display( "data_i: %b", new_data );  
    $display( "left_o: %b, right_o: %b", new_pkr.left, new_pkr.right );
    if( left_tmp == new_pkr.left && right_tmp == new_pkr.right )
      $display( "###Data received correctly!!!\n");
    else
      begin
        if( left_tmp != new_pkr.left )
          $display( "Error on left_o!!!" );
        if( right_tmp != new_pkr.right )
          $display( "Error on right_o!!!" );
      end
    
  end
endtask

initial
  begin
    srst_i_tb = 1;
    ##1;
    srst_i_tb = 0;
  end

initial
    begin
      gen_package( pk_sended );
      send_pacakge( pk_sended, pk_receive, data_valid );
      testing( pk_receive, data_valid );

      $display("-------Test done!!!--------");
      $stop();
    end

endmodule