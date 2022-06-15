module bit_population_counter #(
  parameter WIDTH                 = 16
) (
  input  logic                    clk_i,
  input  logic                    srst_i,
  input  logic [WIDTH-1:0]        data_i,
  input  logic                    data_val_i,
  output logic [$clog2(WIDTH):0]  data_o,
  output logic                    data_val_o
);

logic [$clog2(WIDTH):0] cnt;

//After module receive input data, result will valid after 1 clk (Latency = 1)
always_ff @( posedge clk_i )
  begin
    if( srst_i )
        data_val_o  <= 0;
    else
      begin 
        if( data_val_i )
          data_val_o <= 1;
        else
          data_val_o <= 0;
      end
  end

always_ff @( posedge clk_i )
  begin
    if( data_val_i )
      data_o     <= cnt;
  end

//This block will finish after 1 clk 
always_comb
  begin
    cnt = ($clog2(WIDTH)+1)'(0);   
    for( int i = 0; i < WIDTH; i++ )
      begin
        if( data_i[i] == (WIDTH)'(1) )
          cnt = cnt + ($clog2(WIDTH)+1)'(1);
      end  
  end

endmodule