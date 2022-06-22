module top_tb;

bit_population_counter_tb dut1();
bit_population_counter_tb dut2();
bit_population_counter_tb dut3();

defparam dut1.WIDTH_TB = 5;
defparam dut2.WIDTH_TB = 10; 
defparam dut3.WIDTH_TB = 16;

endmodule