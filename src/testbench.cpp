#include <stdlib.h>
#include <string>
#include <cstring>
#include <iostream>
#include <unordered_map>
#include <vector>

#include "daphne_st_sim.h"

std::vector<uint16_t> read_csv_to_u16_vector(const std::string& filename, bool skip_header = false) {
   std::vector<uint16_t> result;
   std::ifstream file(filename);
   
   if (!file.is_open()) {
       std::cerr << "Error opening file: " << filename << std::endl;
       return result;
   }

   std::string line;
   if (skip_header && std::getline(file, line)) {
       // Skip first line
   }

   while (std::getline(file, line)) {
       std::stringstream ss(line);
       std::string value;
       while (std::getline(ss, value, ',')) {
           try {
               int num = std::stoi(value);
               if (num >= 0 && num <= 0xFFFF) {
                   result.push_back(static_cast<uint16_t>(num));
               } else {
                   std::cerr << "Value out of range for uint16_t: " << num << std::endl;
               }
           } catch (const std::exception& e) {
               std::cerr << "Error parsing line: '" << line << "' - " << e.what() << std::endl;
           }
       }
   }

   return result;
}

int main(int argc, char **argv)
{   
   std::cout << "This is a test for the daphne_st_top_hdl_simulator." << std::endl;
   daphne_st_simulator::daphne_st_top_hdl_simulator daphne_st_top_hdl_simulator("xsim.dir/st40_sim/xsimk.so", "librdi_simulator_kernel.so", true);
   daphne_st_top_hdl_simulator.set_configuration("./config/conf.json");
   std::vector<uint16_t> input_data;
   auto waveform = read_csv_to_u16_vector("./data/fbk_dmem_signal.csv", true);  // true if there's a header row
   int len_data = waveform.size();
   std::vector<uint16_t> enabled_channels = daphne_st_top_hdl_simulator.get_enabled_channels();
   for(int i = 0; i < enabled_channels.size() ; i++){
      for(int j=0; j < len_data; j++){
         input_data.push_back(waveform[j]);
      }
   }
   std::vector<uint32_t> simulation_stream = daphne_st_top_hdl_simulator.run_simulation(input_data);
   daphne_st_top_hdl_simulator.close();
   for(auto& it: simulation_stream){
      std::cout << "Simulation stream: " << std::hex << it << std::endl;
   }
   std::cout << "Finished simulation correctly." << std::endl;
   return 0;
}


