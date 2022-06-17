module priority_encoder #
(
  parameter WIDTH = 5
) (
  input  logic             clk_i,
  input  logic             srst_i,
  input  logic [WIDTH-1:0] data_i,
  input  logic             data_val_i,
  output logic [WIDTH-1:0] data_left_o,
  output logic [WIDTH-1:0] data_right_o,
  output logic             data_val_o
);

integer             r;
integer             l;
logic   [WIDTH-1:0] left;  //most left's index
logic   [WIDTH-1:0] right; //most right's index

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        data_val_o   <= 0;
        data_left_o  <= 0;
        data_right_o <= 0;
      end
    else
      begin
        data_left_o  <= left;
        data_right_o <= right;
        
        if( data_val_i )               
          data_val_o <= 1;
        else
          data_val_o <= 0;
      end
  end

always_comb
  begin
    //Find most left's index of "bit 1" in a bit stream
    left = (WIDTH)'(0);
    for( l = WIDTH - 1; l >= 0; l-- )
      if( data_i[l] ) //left
        break;

      //Set left output 
      for( int i = 0; i < WIDTH; i++ )
        if( i != l )
          left[i]  =  0;
        else
          left[i]  =  1;
  end

always_comb
  begin
    right = (WIDTH)'(0);
    //Find most right's index of "bit 1" in a bit stream
    for( r = 0; r < WIDTH; r++)
      if( data_i[r] ) //right
          break;

    //Set right output
    for( int i = 0; i < WIDTH; i++ )
      if( i != r )
        right[i]  =  0;
      else
        right[i]  =  1;

  end

// assign data_left_o  = left;
// assign data_right_o = right;

endmodule