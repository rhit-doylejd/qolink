# ============================================================================
# QOLink full-system simulation (Vivado xsim)
#
# Run in the Vivado Tcl Shell (from any folder):
#     source C:/senior-design/repositories/branches/qolink/hw/sim/run_system_sim.tcl
#
# Before running:
#   1. Ada built with Simulation_Build = True (src/neorv32/neorv32.ads)
#   2. build/neorv32_imem_image.vhd regenerated with image_gen
# ============================================================================

# Repo root = two folders above this script (hw/sim -> repo)
set repo   [file normalize [file join [file dirname [info script]] .. ..]]
set home   "$repo/hw/third_party/neorv32"
set rtl    "$home/rtl"
set image  "$repo/build/neorv32_imem_image.vhd"
set simdir "$repo/build/sim"

if {![file exists "$rtl/file_list_core.f"]} {
    error "Cannot find $rtl/file_list_core.f - is the NEORV32 submodule checked out?"
}
if {![file exists $image]} {
    error "Missing $image - build the Ada program and run image_gen first"
}

# ---- 1. NEORV32 file list, with our IMEM image swapped in --------------------
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
    # The list writes paths as $NEORV32_HOME/rtl/core/<file>
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
    error "neorv32_imem_image.vhd not found in file_list_core.f - cannot insert our image"
}
puts "NEORV32: [llength $neorv32_files] files, IMEM image = $image"
puts "First file: [lindex $neorv32_files 0]"

# ---- 2. Compile, elaborate, run (always return to the repo root) -------------
file mkdir $simdir
cd $simdir
try {
    puts [exec -ignorestderr xvhdl --2008 --work neorv32 {*}$neorv32_files]
    puts [exec -ignorestderr xvhdl --2008 "$repo/hw/rtl/qolink_cpu.vhd"]
    puts [exec -ignorestderr xvlog "$repo/hw/rtl/qolink_regs.v" \
                                   "$repo/hw/rtl/qolink_top.v" \
                                   "$repo/hw/sim/qolink_top_tb.v"]
    puts [exec -ignorestderr xelab qolink_top_tb -L neorv32 -debug typical -s qolink_top_sim]
    puts [exec -ignorestderr xsim qolink_top_sim -R]
} finally {
    cd $repo
}