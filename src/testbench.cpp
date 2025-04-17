#include <stdlib.h>
#include <string>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <unordered_map>
#include <vector>
#include <chrono>

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
   using namespace std::chrono; 
   std::cout << "This is a test for the daphne_st_top_hdl_simulator." << std::endl;
   daphne_st_simulator::daphne_st_top_hdl_simulator daphne_st_top_hdl_simulator("xsim.dir/st40_sim/xsimk.so", "librdi_simulator_kernel.so");
   daphne_st_top_hdl_simulator.set_clk_sim_step(4000);
   daphne_st_top_hdl_simulator.set_configuration("./config/conf.json");
   int number_of_waveforms = 200;
   std::vector<uint16_t> input_data;
   auto waveform_i = read_csv_to_u16_vector("./data/fbk_dmem_signal.csv", true);  // true if there's a header row
   std::vector<uint16_t> waveform;
   for(int i=0; i<number_of_waveforms; i++){
        waveform.insert(waveform.end(), waveform_i.begin(), waveform_i.end());
   }
   std::cout << "Waveform size: " << waveform.size() << std::endl;
   int len_data = waveform.size();
   std::vector<uint16_t> enabled_channels = daphne_st_top_hdl_simulator.get_enabled_channels();
   for(int i = 0; i < enabled_channels.size() ; i++){
      for(int j=0; j < len_data; j++){
         input_data.push_back(waveform[j]);
      }
   }
   auto start = high_resolution_clock::now(); 
   daphne_st_top_hdl_simulator.run_simulation(input_data);
   auto end = high_resolution_clock::now();
   auto elapsed = duration_cast<seconds>(end - start).count();

   int hours = elapsed / 3600;
   int minutes = (elapsed % 3600) / 60;
   int seconds = elapsed % 60;

   std::cout << "Execution took: "
            << std::setfill('0') << std::setw(2) << hours << ":"
            << std::setfill('0') << std::setw(2) << minutes << ":"
            << std::setfill('0') << std::setw(2) << seconds << std::endl;

   std::vector<uint32_t> simulation_stream = daphne_st_top_hdl_simulator.get_simulation_stream();
   daphne_st_top_hdl_simulator.close();
//    for(auto& it: simulation_stream){
//       std::cout << "Simulation stream: " << std::hex << it << std::endl;
//    }
   std::cout << "Simulation finished correctly." << std::endl;
   return 0;
}


