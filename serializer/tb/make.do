vlib work

vlog -sv ../rtl/serializer.sv
vlog -sv serializer_tb.sv

vsim serializer_tb

add log -r /*

#add wave "sim:/serializer_tb/data_o"
#add wave "sim:/serializer_tb/data_test_i" 

add wave -r *
view -undock wave
run -all
