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
 
 typedef struct {
  logic [WIDTH_TB-1:0] data;
  int                  l;
  int                  r;
 }lr_send_t;

//create struct from data_left_ and data_right_o  
typedef struct {
  logic [WIDTH_TB-1:0] left;
  logic [WIDTH_TB-1:0] right;
}data_receive_t;

mailbox #( send_pkg_t )     pk_sended  = new();
mailbox #( data_receive_t ) pk_receive = new();
mailbox #( lr_send_t )      data_valid = new();

task gen_package ( mailbox #( send_pkg_t ) pk_s );

for( int i = 0; i < MAX_PACKAGE_SENDED; i++ ) 
  begin
    send_pkg_t new_pks;
    new_pks.data  = $urandom_range( 2**WIDTH_TB-1,0 );
    new_pks.valid = $urandom_range( 1,0 );
    pk_s.put( new_pks );
  end

endtask

task send_pacakge( mailbox #( send_pkg_t )     pks,
                   mailbox #( data_receive_t ) pkr,
                   mailbox #( lr_send_t )      data
                 );
int l,r;
while( pks.num() != 0 )
  begin
    send_pkg_t new_pks;
    lr_send_t  new_lr;
    pks.get( new_pks );

    data_i_tb     = new_pks.data;
    data_val_i_tb = new_pks.valid;
    if( data_val_i_tb )
    begin
      for( int i = 0; i < WIDTH_TB; i++)
        begin
          r = i;
          if( data_i_tb[i] == 1 )
            break;
        end

      for( int i = WIDTH_TB-1; i >= 0; i--)
        begin
          l = i;
          if( data_i_tb[i] == 1 )
            break; 
        end
      new_lr.l    = l;
      new_lr.r    = r;
      new_lr.data = data_i_tb;
      data.put( new_lr );
    end  
         
    //save left and right output from tb to compare with left and right output from module
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

task testing( mailbox #( data_receive_t ) pkr,
              mailbox #( lr_send_t )      data
            );
while( ( data.num() != 0 ) && ( pkr.num() != 0 ) )
  begin
    data_receive_t new_pkr;
    lr_send_t      new_lr_send;
    pkr.get( new_pkr );
    data.get( new_lr_send );
    $display( "[%0d] data_i: %b", data.num(), new_lr_send.data );  
    
    //Check right: Ex: 00010
    for( int i = 0; i < WIDTH_TB; i++ )
      begin
        if( i != new_lr_send.r && new_pkr.right[i] != 0 )
          $display( "Error on bit [%0d]\n", i );

        if( i == new_lr_send.r && new_pkr.right[i]== new_lr_send.data[i] )
          $display( "right received: %b, right correct!!", new_pkr.right );
        else if( i == new_lr_send.r && new_pkr.right[i] != new_lr_send.data[i] )
          $display( "right received: %b, right error!!", new_pkr.right );     
      end

    //Check left: Ex: 10000
    for( int i = WIDTH_TB-1; i >= 0; i-- )
      begin
        if( i != new_lr_send.l && new_pkr.left[i] != 0 )
          $display( "Error on bit [%0d]\n", i );

        if( i == new_lr_send.l && new_pkr.left[i] == new_lr_send.data[i] )
          $display( "left received: %b, left correct!!\n", new_pkr.left );
        else if( i == new_lr_send.l && new_pkr.left[i] != new_lr_send.data[i] )
          $display( "left received: %b, left error!!\n", new_pkr.left );
        
      end
  end
endtask

initial
    begin
      srst_i_tb = 1;
      ##1;
      srst_i_tb = 0;
      gen_package( pk_sended );
      send_pacakge( pk_sended, pk_receive, data_valid );
      testing( pk_receive, data_valid );

      $display("-------Test done!!!--------");
      $stop();
    end

endmodule