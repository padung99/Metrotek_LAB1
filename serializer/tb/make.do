vlib work

vlog -sv ../serializer.sv
vlog -sv serializer_tb.sv

vsim serializer_tb

add log -r /*

#add wave "sim:/serializer_tb/data_o"
#add wave "sim:/serializer_tb/data_test_i" 

add wave -r *
run -all
