#ifndef DAPHNE_ST_SIM_H
#define DAPHNE_ST_SIM_H

#include <string>
#include <exception>
#include <vector>
#include <unordered_map>
#include <iostream>
#include <fstream>
#include <memory>
#include <bitset>

#include "xsi_loader.h"
#include "fddetdataformats/DAPHNEFrame.hpp"
#include "nlohmann/json.hpp"

namespace daphne_st_simulator{

class daphne_st_top_hdl_simulator{
private:
    // Atributes
    struct port_attribute{
        uint16_t port_number;
        uint8_t port_type; // 0 = input, 1 = output, 2 = inout
        uint16_t port_size; // size of the port in bits
    };

    std::string design_libname;
    std::string simkernel_libname;
    std::unordered_map<std::string, port_attribute> port_map;
    std::unordered_map<std::string, std::vector<s_xsi_vlog_logicval>> port_values;
    std::unordered_map<uint16_t, std::string> signal_input_map;

    std::vector<uint32_t> simulation_stream = {}; //consider preallocation

    // Flags.
    bool sof_flag = false; // Start of frame flag
    bool eof_flag = false; // End of frame flag
    bool clock_tilt_flag = false; // Clock tilt flag

    uint64_t clk_sim_step = 40; // 4000 ps.

    // counters
    uint64_t packet_counter = 0;

    uint16_t ncycles_stop_condition = 2500;

    std::vector<uint16_t> enabled_channels;

    std::unique_ptr<Xsi::Loader> loader;
    s_xsi_setup_info info;
    
    // constant values
    const s_xsi_vlog_logicval one_val  = {0x00000001, 0x00000000};
    const s_xsi_vlog_logicval zero_val = {0x00000000, 0x00000000};

    void append_logic_val_bit_to_string(std::string& retVal, int aVal, int bVal);
    void append_logic_val_to_string(std::string& retVal, int aVal, int bVal, int max_bits);
    std::string logic_val_to_string(s_xsi_vlog_logicval* value, int size);
    
    void initialize_design();
    void get_module_port_numbers();
    void set_port_initial_values();
    void set_port_value(const std::string &port_name);
    void get_port_value(const std::string &port_name);
    void cycle_a_clock();
    void cycle_f_clock();
    void run_n_cycles(const int & n_cycles, const std::string & which_clock);
    void reset_design();
    void set_input_signal_ports(std::vector<uint16_t> &input_data);
    void push_back_port_value(std::vector<uint32_t> &stream, const uint32_t &value);
    std::vector<uint16_t> get_channels_input_data(const std::vector<uint16_t> &input_data, const int &iteration, const int &length_of_waveforms);
    
public:
    daphne_st_top_hdl_simulator(const std::string &design_libname, const std::string &simkernel_libname);
    daphne_st_top_hdl_simulator(const std::string &design_libname, const std::string &simkernel_libname, const bool &enable_debug);
    ~daphne_st_top_hdl_simulator();
    void set_configuration(const std::string &configFile); // Here use the same configuration as in the DAQ configuration file.
    void close();
    const std::vector<uint16_t>& get_enabled_channels() const { return this->enabled_channels;}
    void run_simulation(const std::vector<uint16_t> &input_data);
    const std::vector<uint32_t>& get_simulation_stream() const { return this->simulation_stream; }
    void set_clk_sim_step(const uint64_t &clk_sim_step) { this->clk_sim_step = clk_sim_step; }
    uint64_t get_clk_sim_step() const { return this->clk_sim_step; }
    std::vector<dunedaq::fddetdataformats::DAPHNEFrame> decode_simulation_stream(const std::vector<uint32_t> &simulation_stream);
};

}

#endif // DAPHNE_ST_SIM_H