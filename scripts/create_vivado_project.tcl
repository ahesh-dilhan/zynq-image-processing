# Rebuild a minimal source-first Vivado project for the authoritative RTL.
# Usage: vivado -mode batch -source scripts/create_vivado_project.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $repo_dir build vivado]

create_project zynq_mean_filter $project_dir -part xc7z020clg484-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse [file join $repo_dir rtl axis_mean_filter_3x3.sv]
set_property top axis_mean_filter_3x3 [current_fileset]
update_compile_order -fileset sources_1

add_files -fileset sim_1 -norecurse \
    [file join $repo_dir sim tb_axis_mean_filter_3x3.sv]
set_property top tb_axis_mean_filter_3x3 [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "Created source-first project at $project_dir"
puts "No Zynq PS, AXI DMA, constraints, or board-specific block design is added."
