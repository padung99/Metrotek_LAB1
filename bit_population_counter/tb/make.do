vlib work

vlog -sv ../rtl/bit_population_counter.sv
vlog -sv bit_population_counter_tb.sv

vsim bit_population_counter_tb

add log -r /*

#add wave "sim:bit_population_counter_tb/mem"

add wave -r *
run -all
