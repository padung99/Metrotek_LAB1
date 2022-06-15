module deserializer(
  input  logic        clk_i,
  input  logic        srst_i,
  input  logic        data_i,
  input  logic        data_val_i,
  output logic [15:0] deser_data_o,
  output logic        deser_data_val_o
);

logic [15:0] data_buf;
logic [4:0]  bit_index; 
logic        data_val;
logic        delay_data_val_i;

always_ff @( posedge clk_i )
  begin
    if( srst_i )
      bit_index <= 5'd0;
    else
      begin
        if( data_val_i )
          bit_index    <= bit_index + 5'd1;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( data_val_i )
      data_buf <= {data_buf[14:0], data_i};
  end

always_ff @( posedge clk_i )
  begin
    if( ( data_val_i ) )
      delay_data_val_i <= 1;
    else
      delay_data_val_i <= 0;
  end

assign data_val       =  bit_index[3:0] == 4'h0 ;
assign deser_data_val_o =  data_val & delay_data_val_i;
assign deser_data_o     =  data_buf;
  
endmodule