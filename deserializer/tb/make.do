vlib work

vlog -sv ../rtl/deserializer.sv
vlog -sv deserializer_tb.sv

vsim deserializer_tb

add log -r /*

#add wave "sim:/deserializer_tb/bits_valid"

add wave -r *
run -all
