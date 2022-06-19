vlib work

vlog -sv ../rtl/traffic_lights.sv
vlog -sv traffic_lights_tb.sv

vsim traffic_lights_tb

add log -r /*
add wave -r *
view -undock wave
run -all
