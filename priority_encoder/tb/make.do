vlib work

vlog  -sv ../priority_encoder.sv
vlog  -sv priority_encoder_tb.sv

vsim priority_encoder_tb

add log -r /*

add wave -r *
run -all