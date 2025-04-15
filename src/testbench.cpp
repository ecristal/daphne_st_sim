#include <stdlib.h>
#include <string>
#include <cstring>
#include <iostream>
#include <unordered_map>
#include <vector>

#include "daphne_st_sim.h"

int main(int argc, char **argv)
{   
   std::cout << "This is a test for the daphne_st_top_hdl_simulator." << std::endl;
   daphne_st_simulator::daphne_st_top_hdl_simulator daphne_st_top_hdl_simulator("xsim.dir/st40_sim/xsimk.so", "librdi_simulator_kernel.so", true);
   std::vector<uint16_t> input_data = {0x0000, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006, 0x0007, 0x0008, 0x0009};
   std::vector<uint32_t> simulation_stream = daphne_st_top_hdl_simulator.run_simulation(input_data);
   daphne_st_top_hdl_simulator.close();
   for(auto& it: simulation_stream){
      std::cout << "Simulation stream: " << std::hex << it << std::endl;
   }
   std::cout << "Finished simulation correctly." << std::endl;
   return 0;
}


