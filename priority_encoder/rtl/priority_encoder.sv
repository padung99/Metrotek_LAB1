module priority_encoder #(
  parameter WIDTH = 5
) (
  input  logic             clk_i,
  input  logic             srst_i,
  input  logic [WIDTH-1:0] data_i,
  input  logic             data_val_i,
  output logic [WIDTH-1:0] data_left_o,
  output logic [WIDTH-1:0] data_right_o,
  output logic             deser_data_val_o 
);

integer           r; //most right's index
integer           l; //most left's index

logic [WIDTH-1:0] left;  
logic [WIDTH-1:0] right; 

logic             valid_l;
logic             valid_r;
logic             valid;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      begin
        valid        <= 0;
        data_left_o  <= 0;
        data_right_o <= 0;
      end
    else
      begin              
        valid        <= data_val_i && valid_r && valid_l && ( r != l );
        data_left_o  <= left;
        data_right_o <= right;
      end
  end

always_comb
  begin
    //Find most right index '1'
    r       = 0;
    valid_r = data_i[r];
    while( ( !valid_r ) && ( r != WIDTH - 1 ) )
      begin
        r       = r + 1;
        valid_r = data_i[r];
      end

    //Set right output, only right[r] = 1, others = 0;
    for(int i = 0; i < WIDTH; i++)
      if( i != r )
        right[i]  =  0;
      else
        right[i]  =  1;
  end

always_comb
  begin
    //Find most left index '1'
    l       = WIDTH - 1;
    valid_l = data_i[l];
    while( ( !valid_l ) && ( l != 0 ) )
      begin
        l       = l - 1;
        valid_l = data_i[l];
      end
    
    //Set left output, only left[l] = 1, others = 0;
    for(int i = 0; i < WIDTH; i++)
      if( i != l )
        left[i]  =  0;
      else
        left[i]  =  1;
        
  end

assign deser_data_val_o = valid;

endmodule
