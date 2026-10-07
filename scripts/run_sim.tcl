if {$argc < 1} {
  puts "用法：do scripts/run_sim.tcl baseline"
  quit -code 2
}
set cfg [lindex $argv 0]
file mkdir "results/$cfg"
if {[file exists work]} { vdel -all -lib work }
vlib work
vlog -sv rtl/conv_top.v tb/tb_conv.v
vsim -voptargs=+acc work.tb_conv +CFG=$cfg
add wave sim:/tb_conv/clk
add wave sim:/tb_conv/rst_n
add wave sim:/tb_conv/start
add wave sim:/tb_conv/input_valid
add wave sim:/tb_conv/input_ready
add wave sim:/tb_conv/weight_valid
add wave sim:/tb_conv/weight_ready
add wave sim:/tb_conv/output_valid
add wave sim:/tb_conv/output_ready
add wave sim:/tb_conv/output_data
add wave sim:/tb_conv/busy
add wave sim:/tb_conv/done
add wave sim:/tb_conv/mismatch_count
add wave sim:/tb_conv/errors
run -all
