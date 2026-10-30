# ============================================================================
# QOLink bitstream build - Nexys A7-100T (Vivado non-project mode)
#
# Run in the Vivado Tcl Shell (from any folder):
#     source C:/senior-design/repositories/branches/qolink/hw/boards/nexys_a7_100t/build.tcl
#
# Before running:
#   1. Ada built with Simulation_Build = False (src/neorv32/neorv32.ads)
#   2. build/neorv32_imem_image.vhd regenerated with image_gen
#
# Output: build/nexys_a7_100t/qolink_top.bit and reports
# ============================================================================

set board_dir [file dirname [file normalize [info script]]]
set repo      [file normalize [file join $board_dir .. .. ..]]
set home      "$repo/hw/third_party/neorv32"
set rtl       "$home/rtl"
set image     "$repo/build/neorv32_imem_image.vhd"
set outdir    "$repo/build/nexys_a7_100t"
set part      xc7a100tcsg324-1

if {![file exists $image]} {
    error "Missing $image - build the Ada program and run image_gen first"
}

# Start from an empty in-memory design (safe to re-run in the same shell)
close_project -quiet
file mkdir $outdir

# ---- NEORV32 file list, with our IMEM image swapped in (same as simulation) --
set fh [open "$rtl/file_list_core.f" r]
set lines [split [read $fh] "\n"]
close $fh

set neorv32_files {}
set image_swapped 0
foreach line $lines {
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line] || [string match "//*" $line]} {
        continue
    }
    set path [string map [list {$NEORV32_HOME} $home \
                               NEORV32_RTL_PATH_PLACEHOLDER $rtl] $line]
    if {[file pathtype $path] eq "relative"} {
        set path "$rtl/$path"
    }
    if {[file tail $path] eq "neorv32_imem_image.vhd"} {
        set path $image
        set image_swapped 1
    }
    lappend neorv32_files $path
}
if {!$image_swapped} {
    error "neorv32_imem_image.vhd not found in file_list_core.f"
}

# ---- Read sources ------------------------------------------------------------
read_vhdl -vhdl2008 -library neorv32 $neorv32_files
read_vhdl -vhdl2008 "$repo/hw/rtl/qolink_cpu.vhd"
read_verilog [list "$repo/hw/rtl/qolink_regs.v" "$repo/hw/rtl/qolink_top.v"]
read_xdc "$board_dir/nexys_a7_100t.xdc"

# ---- Synthesis -----------------------------------------------------------------
synth_design -top qolink_top -part $part
report_utilization -file "$outdir/utilization_synth.rpt"

# ---- Implementation ------------------------------------------------------------
opt_design
place_design
route_design

# ---- Reports -------------------------------------------------------------------
report_timing_summary -file "$outdir/timing_summary.rpt"
report_utilization    -file "$outdir/utilization.rpt"

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
puts "=============================================================="
puts " Worst negative slack (WNS): $wns ns"
if {$wns < 0} {
    puts " TIMING FAILED - the design is too slow for 100 MHz."
    puts " Do not program the board; see $outdir/timing_summary.rpt"
    puts "=============================================================="
    error "Timing not met"
}
puts " Timing met at 100 MHz."
puts "=============================================================="

# ---- Bitstream -----------------------------------------------------------------
write_bitstream -force "$outdir/qolink_top.bit"
puts "Bitstream: $outdir/qolink_top.bit"
