#!/bin/csh -xvf

# Set VIVADO_BIN_DIR to the directory which has vivado executable

#set VIVADO_BIN_DIR="$RDI_ROOT/prep/rdi/vivado/bin"
setenv XILINX_VIVADO /opt/Xilinx/Vivado/2024.1
source $XILINX_VIVADO/settings64.csh
setenv LD_LIBRARY_PATH $XILINX_VIVADO/lib/lnx64.o:$XILINX_VIVADO/lib/lnx64.o/Default:${LD_LIBRARY_PATH}

set VIVADO_BIN_DIR="$XILINX_VIVADO/bin"

set OUT_SIM_SNAPSHOT="st40_sim"
set XSI_INCLUDE_DIR="$VIVADO_BIN_DIR/../data/xsim/include"
set GCC_COMPILER="/usr/bin/g++"
set XSIM_ELAB="xelab"
set OUT_EXE="selftrigger_simulation"
set SRC_DIR="./src"
set INC_DIR="./include"

# 🧹 Step 0: Cleanup previous simulation
echo "Cleaning up previous simulation artifacts..."
rm -rf xsim.dir *.jou *.log *.pb *.wdb *.o $OUT_EXE

# Compile the HDL design into a simulatable Shared Library
$XSIM_ELAB work.st40_top_wrapper -prj selftrigger_project.prj --incr --relax -L work -L unisims_ver -L unimacro_ver -L secureip -dll -s $OUT_SIM_SNAPSHOT -debug wave -log elaborate.log
