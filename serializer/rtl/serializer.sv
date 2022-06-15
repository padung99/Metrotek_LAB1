module serializer (
input  logic        clk_i,
input  logic        srst_i,
input  logic [15:0] data_i, 
input  logic [3:0]  data_mod_i,
input  logic        data_val_i,
output logic        ser_data_o,
output logic        ser_data_val_o,
output logic        busy_o
);

logic [4:0]         bit_index;
logic [15:0]        data_tmp;     //save data_i temporary
logic [3:0]         data_mod_tmp; //save data_mod_i temporary

enum logic  [1:0] {
  IDLE_S,
  WRITE_S,
  WRITE_FULL_S
} state, next_state;

always_ff @( posedge clk_i )
  if( srst_i )
    state <= IDLE_S;
  else
    state <= next_state;

//---------------------"State" FSM control--------------------
always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S:
        begin
          if( data_val_i )
            begin
              if( data_mod_i > 4'd2 )
                next_state =  WRITE_S;
              else 
                begin
                  if( ( data_mod_i == 4'd1 ) || ( data_mod_i == 4'd2 ) )
                    next_state = IDLE_S;
                  else if( data_mod_i == 4'd0 )
                    next_state = WRITE_FULL_S;
                end
            end
        end

      WRITE_S, WRITE_FULL_S:
        begin
          if( bit_index == 5'd15 )
            next_state = IDLE_S;
        end

      default:
        next_state = IDLE_S;

    endcase

end

//--------------Control bit_index-----------------
always_ff @( posedge clk_i )
  begin
    if( state == IDLE_S )
      begin
        data_tmp     <= data_i;
        data_mod_tmp <= data_mod_i; 
        bit_index    <= 5'd0;
      end
    else if( state == WRITE_S || state == WRITE_FULL_S)
      begin
        if( bit_index == 5'd15 )
          bit_index  <= 5'd0;                                
        else 
          bit_index  <= bit_index + 5'd1;
      end
  end

//--------------"Output" FSM control----------------------
always_comb
  begin
    busy_o         = 0;
    ser_data_o     = 0;
    ser_data_val_o = 0;
    case( state )
      IDLE_S:
        begin
          busy_o         = 0;
          ser_data_o     = 0;
          ser_data_val_o = 0;
        end

      WRITE_S:
        begin
          ser_data_o     = data_tmp[15-bit_index[3:0]];
          busy_o         = 1; 
          ser_data_val_o = 1; 

          if ( bit_index == 5'd15 + 5'd1 )
            begin
              busy_o         = 0; 
              ser_data_val_o = 0;               
            end       
          else if( bit_index == data_mod_tmp )
            ser_data_val_o = 0;  
          else if( ( bit_index > data_mod_tmp ) && ( bit_index < 5'd15 + 5'd1 ) )
            ser_data_val_o = 0;  
        end

      WRITE_FULL_S:
        begin
          ser_data_o     = data_tmp[15-bit_index[3:0]];
          busy_o         = 1; 
          ser_data_val_o = 1; 

          if ( bit_index == 5'd15 + 5'd1 )
            begin
              ser_data_val_o = 0; 
              busy_o         = 0;            
            end 
        end
    endcase
end

endmodule
