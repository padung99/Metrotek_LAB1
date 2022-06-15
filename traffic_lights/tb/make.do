vlib work

vlog -sv ../traffic_lights.sv
vlog -sv traffic_lights_tb.sv

vsim traffic_lights_tb

add log -r /*
add wave -r *
run -all
