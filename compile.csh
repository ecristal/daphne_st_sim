#!/bin/csh -xvf

# Set VIVADO_BIN_DIR to the directory which has vivado executable

#set VIVADO_BIN_DIR="$RDI_ROOT/prep/rdi/vivado/bin"
setenv XILINX_VIVADO /opt/Xilinx/Vivado/2024.1
source $XILINX_VIVADO/settings64.csh

set VIVADO_BIN_DIR="$XILINX_VIVADO/bin"

set OUT_SIM_SNAPSHOT="st40_sim"
set XSI_INCLUDE_DIR="$VIVADO_BIN_DIR/../data/xsim/include"
set XSI_LOADER_INCLUDE_DIR="$VIVADO_BIN_DIR/../examples/xsim/verilog/xsi/counter"
set GCC_COMPILER="/usr/bin/g++"
set XSIM_ELAB="xelab"
set OUT_EXE="selftrigger_simulation"
set SRC_DIR="./src"
set INC_DIR="./include"
set LIB_DIR="./lib"
setenv LD_LIBRARY_PATH $PWD/lib:$XILINX_VIVADO/lib/lnx64.o:$XILINX_VIVADO/lib/lnx64.o/Default:${LD_LIBRARY_PATH}

# 🧹 Step 0: Cleanup previous simulation
echo "Cleaning up previous simulation artifacts..."
rm -rf *.o $OUT_EXE

# Compile the C++ code that interfaces with XSI of ISim
$GCC_COMPILER -fPIC -I$XSI_INCLUDE_DIR -I$INC_DIR -I$XSI_LOADER_INCLUDE_DIR -I -O3 -c -o $SRC_DIR/xsi_loader.o $XSI_LOADER_INCLUDE_DIR/xsi_loader.cpp

# Compile the C++ code that interfaces with XSI of ISim
$GCC_COMPILER -fPIC -I$XSI_INCLUDE_DIR -I$INC_DIR -I$XSI_LOADER_INCLUDE_DIR -O3 -c -o $SRC_DIR/daphne_st_top_hdl_simulator.o $SRC_DIR/daphne_st_top_hdl_simulator.cpp

# Compile the program that needs to simulate the HDL design
#$GCC_COMPILER -I$XSI_INCLUDE_DIR -I$INC_DIR -I$XSI_LOADER_INCLUDE_DIR  -O3 -c -o $SRC_DIR/testbench.o $SRC_DIR/testbench.cpp

$GCC_COMPILER -shared -fPIC $SRC_DIR/daphne_st_top_hdl_simulator.o $SRC_DIR/xsi_loader.o -o $LIB_DIR/libdaphne_st_sim_lib.so

$GCC_COMPILER -I$XSI_INCLUDE_DIR -I$XSI_LOADER_INCLUDE_DIR -I$INC_DIR $SRC_DIR/testbench.cpp -L$LIB_DIR -ldl -lrt -ldaphne_st_sim_lib -o $OUT_EXE 

# Run the program
./$OUT_EXE