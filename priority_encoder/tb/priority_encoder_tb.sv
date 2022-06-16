module priority_encoder_tb;

parameter WIDTH_TB           = 5;
parameter MAX_PACKAGE_SENDED = 2**(WIDTH_TB+1)+1;

bit                  clk_i_tb;

logic                srst_i_tb;
logic [WIDTH_TB-1:0] data_i_tb;
logic                data_val_i_tb;
logic [WIDTH_TB-1:0] data_left_o_tb;
logic [WIDTH_TB-1:0] data_right_o_tb;
logic                deser_data_val_o_tb;

initial 
  forever
    #5 clk_i_tb = !clk_i_tb;

default clocking cb
    @( posedge clk_i_tb );
endclocking

priority_encoder#(  
  .WIDTH            ( WIDTH_TB            )
) dut (
  .clk_i            ( clk_i_tb            ),
  .srst_i           ( srst_i_tb           ),
  .data_i           ( data_i_tb           ),
  .data_val_i       ( data_val_i_tb       ),
  .data_left_o      ( data_left_o_tb      ),
  .data_right_o     ( data_right_o_tb     ),
  .deser_data_val_o ( deser_data_val_o_tb ) 
);

//create package to send
typedef struct {
  logic [WIDTH_TB-1:0] data;
  logic                valid;
}send_pkg; 

//create struct from data_left_ and data_right_o  
typedef struct {
  logic [WIDTH_TB-1:0] left;
  logic [WIDTH_TB-1:0] right;
}data_receive;

mailbox #( send_pkg     ) pk_sended  = new();
mailbox #( data_receive ) pk_receive = new();
mailbox #( logic [15:0] ) data_valid = new();

task gen_package ( mailbox #( send_pkg ) pk_s );

for( int i = 0; i < MAX_PACKAGE_SENDED; i++ ) 
  begin
    send_pkg new_pks;
    new_pks.data  = $urandom_range( 2**WIDTH_TB-1,0 );
    new_pks.valid = $urandom_range( 1,0 );
    pk_s.put( new_pks );
  end

endtask

task send_pacakge( mailbox #( send_pkg )     pks,
                   mailbox #( data_receive ) pkr,
                   mailbox #( logic [15:0] ) data
                 );

while( pks.num() != 0 )
  begin
    send_pkg new_pks;
    pks.get( new_pks );
    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;
    if( data_val_i_tb )
      data.put( data_i_tb );
    
    if( deser_data_val_o_tb )
      begin
        data_receive new_receive;
        new_receive.left  = data_left_o_tb;
        new_receive.right = data_right_o_tb;
        pkr.put( new_receive );
      end
    ##1;
  end
endtask

task testing( mailbox #( data_receive ) pkr,
              mailbox #( logic [15:0] ) data
            );

int send_data;
int receive_data;

send_data    = data.num();
receive_data = pkr.num();

$display("###Sending");
while(  data.num() != 0 )
  begin
    logic [15:0] new_data;
    data.get( new_data );
    $display("[%0d] data_i: %0b", data.num(), new_data );
  end
$display( "###Sending done" );
$display("----------Total valid data sended: %d\n", send_data );

$display( "###Receiving" );
while( pkr.num() != 0 )
  begin
    data_receive new_receive;
    pkr.get( new_receive );
    $display("[%0d] left: %b, right: %b", pkr.num(), new_receive.left, new_receive.right );
  end
$display( "Receiving done" );
$display( "---------Total valid data received( left = right ): %0d ", receive_data );
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

      $display("-------Test done, check result on simulation screen!!!--------");
      $stop();
    end

endmodule