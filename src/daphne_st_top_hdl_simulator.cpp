#include "daphne_st_sim.h"

daphne_st_simulator::daphne_st_top_hdl_simulator::daphne_st_top_hdl_simulator(const std::string &design_libname, const std::string &simkernel_libname){
    try{
        this->design_libname = design_libname;
        this->simkernel_libname = simkernel_libname;
        this->loader = std::make_unique<Xsi::Loader>(this->design_libname, this->simkernel_libname);
        this->info.logFileName = NULL;
        this->info.wdbFileName = NULL;
        this->loader->open(&this->info);

        this->initialize_design();
    }
    catch (std::exception& e) {
        std::cerr << "ERROR: An exception occurred: " << e.what() << std::endl;
        throw;
    }
}

daphne_st_simulator::daphne_st_top_hdl_simulator::daphne_st_top_hdl_simulator(const std::string &design_libname, const std::string &simkernel_libname, const bool &enable_debug){
    try{
        this->design_libname = design_libname;
        this->simkernel_libname = simkernel_libname;
        this->loader = std::make_unique<Xsi::Loader>(this->design_libname, this->simkernel_libname);
        char wdbName[] = "debug_waveforms.wdb";
        this->info.logFileName = NULL;
        this->info.wdbFileName = wdbName;
        this->loader->open(&this->info);
        this->loader->trace_all();
        this->initialize_design();
    }
    catch (std::exception& e) {
        std::cerr << "ERROR: An exception occurred: " << e.what() << std::endl;
        throw;
    }
}

daphne_st_simulator::daphne_st_top_hdl_simulator::~daphne_st_top_hdl_simulator(){
    this->loader->close();
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::initialize_design(){

    this->port_map = { // {port_name,{port_number,input = 0 or output = 1}}
        {"reset_aclk", {0, 0, 1}},                      //reset_aclk: in std_logic;
        {"reset_fclk", {0, 0, 1}},                      //reset_fclk: in std_logic;
        {"adhoc", {0, 0, 8}},                           //adhoc: in std_logic_vector(7 downto 0);
        {"st_config", {0, 0, 14}},                      //st_config: in std_logic_vector(13 downto 0);
        {"signal_delay", {0, 0, 5}},                    //signal_delay: in std_logic_vector(4 downto 0);
        {"threshold_xc", {0, 0, 42}},                   //in std_logic_vector(41 downto 0);
        {"ti_trigger", {0, 0, 8}},                      //in std_logic_vector(7 downto 0);
        {"ti_trigger_stbr", {0, 0, 1}},                 //ti_trigger_stbr: in std_logic;
        {"reset_st_counters", {0, 0, 1}},               //reset_st_counters: in std_logic;
        {"slot_id", {0, 0, 4}},                         //slot_id: in std_logic_vector(3 downto 0);
        {"crate_id", {0, 0, 10}},                       //crate_id: in std_logic_vector(9 downto 0);
        {"detector_id", {0, 0, 6}},                     //detector_id: in std_logic_vector(5 downto 0);
        {"version_id", {0, 0, 6}},                      //version_id: in std_logic_vector(5 downto 0);
        {"enable", {0, 0, 40}},                         //enable: in std_logic_vector(39 downto 0);
        {"afe_comp_enable", {0, 0, 40}},                //afe_comp_enable: in std_logic_vector(39 downto 0);
        {"invert_enable", {0, 0, 40}},                  //invert_enable: in std_logic_vector(39 downto 0);
        {"st_40_signals_enable_reg", {0, 0, 6}},        //st_40_signals_enable_reg: in std_logic_vector(5 downto 0);
        {"st_40_selftrigger_4_spybuffer", {0, 1, 1}},   //st_40_selftrigger_4_spybuffer: out std_logic;
        {"filter_output_selector", {0, 0, 2}},          //filter_output_selector: in std_logic_vector(1 downto 0);
        {"aclk", {0, 0, 1}},                            //aclk: in std_logic;
        {"timestamp", {0, 0, 64}},                      //timestamp: in std_logic_vector(63 downto 0);
        {"afe_dat_0_0", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_1", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_2", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_3", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_4", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_5", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_6", {0, 0, 14}},                    // in std_logic_vector(13 downto 0);
        {"afe_dat_0_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_0_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_5", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_0_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_0_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_0_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_5", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_1_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_5", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_2_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_5", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_3_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_0", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_1", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_2", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_3", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_4", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_5", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_6", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_7", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_4_8", {0, 0, 14}}, // in std_logic_vector(13 downto 0);
        {"afe_dat_0_0_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_1_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_2_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_3_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_4_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_5_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_6_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_7_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_0_8_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_0_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_1_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_2_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_3_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_4_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_5_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_6_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_7_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_1_8_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_0_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_1_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_2_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_3_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_4_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_5_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_6_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_7_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_2_8_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_0_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_1_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_2_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_3_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_4_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_5_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_6_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_7_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_3_8_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_0_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_1_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_2_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_3_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_4_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_5_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_6_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_7_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"afe_dat_4_8_filtered", {0, 1, 14}}, // out std_logic_vector(13 downto 0);
        {"oeiclk", {0, 0, 1}}, //oeiclk: in std_logic;
        {"fclk", {0, 0, 1}}, //fclk: in std_logic;
        {"dout",{0, 1, 32}},
        {"kout",{0, 1, 4}},
        {"Rcount_addr",{0, 0, 32}},
        {"Rcount",{0, 1, 64}}
    };

    this->port_values = {
        {"reset_aclk", {this->zero_val}},
        {"reset_fclk", {this->zero_val}},
        {"adhoc", {this->zero_val}},
        {"st_config", {this->zero_val}},
        {"signal_delay", {this->zero_val}},
        {"threshold_xc", {this->zero_val, this->zero_val}},
        {"ti_trigger", {this->zero_val}},
        {"ti_trigger_stbr", {this->zero_val}},
        {"reset_st_counters", {this->zero_val}},
        {"slot_id", {this->zero_val}},
        {"crate_id", {this->zero_val}},
        {"detector_id", {this->zero_val}},
        {"version_id", {this->zero_val}},
        {"enable", {this->zero_val, this->zero_val}},
        {"afe_comp_enable", {this->zero_val, this->zero_val}},
        {"invert_enable", {this->zero_val, this->zero_val}},
        {"st_40_signals_enable_reg", {this->one_val}},
        {"st_40_selftrigger_4_spybuffer", {this->zero_val}},
        {"filter_output_selector", {this->zero_val}},
        {"aclk", {this->zero_val}},
        {"timestamp", {this->zero_val, this->zero_val}},
        {"afe_dat_0_0", {this->zero_val}},
        {"afe_dat_0_1", {this->zero_val}},
        {"afe_dat_0_2", {this->zero_val}},
        {"afe_dat_0_3", {this->zero_val}},
        {"afe_dat_0_4", {this->zero_val}},
        {"afe_dat_0_5", {this->zero_val}},
        {"afe_dat_0_6", {this->zero_val}},
        {"afe_dat_0_7", {this->zero_val}},
        {"afe_dat_0_8", {this->zero_val}},
        {"afe_dat_1_0", {this->zero_val}},
        {"afe_dat_1_1", {this->zero_val}},
        {"afe_dat_1_2", {this->zero_val}},
        {"afe_dat_1_3", {this->zero_val}},
        {"afe_dat_1_4", {this->zero_val}},
        {"afe_dat_1_5", {this->zero_val}},
        {"afe_dat_1_6", {this->zero_val}},
        {"afe_dat_1_7", {this->zero_val}},
        {"afe_dat_1_8", {this->zero_val}},
        {"afe_dat_2_0", {this->zero_val}},
        {"afe_dat_2_1", {this->zero_val}},
        {"afe_dat_2_2", {this->zero_val}},
        {"afe_dat_2_3", {this->zero_val}},
        {"afe_dat_2_4", {this->zero_val}},
        {"afe_dat_2_5", {this->zero_val}},
        {"afe_dat_2_6", {this->zero_val}},
        {"afe_dat_2_7", {this->zero_val}},
        {"afe_dat_2_8", {this->zero_val}},
        {"afe_dat_3_0", {this->zero_val}},
        {"afe_dat_3_1", {this->zero_val}},
        {"afe_dat_3_2", {this->zero_val}},
        {"afe_dat_3_3", {this->zero_val}},
        {"afe_dat_3_4", {this->zero_val}},
        {"afe_dat_3_5", {this->zero_val}},
        {"afe_dat_3_6", {this->zero_val}},
        {"afe_dat_3_7", {this->zero_val}},
        {"afe_dat_3_8", {this->zero_val}},
        {"afe_dat_4_0", {this->zero_val}},
        {"afe_dat_4_1", {this->zero_val}},
        {"afe_dat_4_2", {this->zero_val}},
        {"afe_dat_4_3", {this->zero_val}},
        {"afe_dat_4_4", {this->zero_val}},
        {"afe_dat_4_5", {this->zero_val}},
        {"afe_dat_4_6", {this->zero_val}},
        {"afe_dat_4_7", {this->zero_val}},
        {"afe_dat_4_8", {this->zero_val}},
        {"afe_dat_0_0_filtered", {this->zero_val}},
        {"afe_dat_0_1_filtered", {this->zero_val}},
        {"afe_dat_0_2_filtered", {this->zero_val}},
        {"afe_dat_0_3_filtered", {this->zero_val}},
        {"afe_dat_0_4_filtered", {this->zero_val}},
        {"afe_dat_0_5_filtered", {this->zero_val}},
        {"afe_dat_0_6_filtered", {this->zero_val}},
        {"afe_dat_0_7_filtered", {this->zero_val}},
        {"afe_dat_0_8_filtered", {this->zero_val}},
        {"afe_dat_1_0_filtered", {this->zero_val}},
        {"afe_dat_1_1_filtered", {this->zero_val}},
        {"afe_dat_1_2_filtered", {this->zero_val}},
        {"afe_dat_1_3_filtered", {this->zero_val}},
        {"afe_dat_1_4_filtered", {this->zero_val}},
        {"afe_dat_1_5_filtered", {this->zero_val}},
        {"afe_dat_1_6_filtered", {this->zero_val}},
        {"afe_dat_1_7_filtered", {this->zero_val}},
        {"afe_dat_1_8_filtered", {this->zero_val}},
        {"afe_dat_2_0_filtered", {this->zero_val}},
        {"afe_dat_2_1_filtered", {this->zero_val}},
        {"afe_dat_2_2_filtered", {this->zero_val}},
        {"afe_dat_2_3_filtered", {this->zero_val}},
        {"afe_dat_2_4_filtered", {this->zero_val}},
        {"afe_dat_2_5_filtered", {this->zero_val}},
        {"afe_dat_2_6_filtered", {this->zero_val}},
        {"afe_dat_2_7_filtered", {this->zero_val}},
        {"afe_dat_2_8_filtered", {this->zero_val}},
        {"afe_dat_3_0_filtered", {this->zero_val}},
        {"afe_dat_3_1_filtered", {this->zero_val}},
        {"afe_dat_3_2_filtered", {this->zero_val}},
        {"afe_dat_3_3_filtered", {this->zero_val}},
        {"afe_dat_3_4_filtered", {this->zero_val}},
        {"afe_dat_3_5_filtered", {this->zero_val}},
        {"afe_dat_3_6_filtered", {this->zero_val}},
        {"afe_dat_3_7_filtered", {this->zero_val}},
        {"afe_dat_3_8_filtered", {this->zero_val}},
        {"afe_dat_4_0_filtered", {this->zero_val}},
        {"afe_dat_4_1_filtered", {this->zero_val}},
        {"afe_dat_4_2_filtered", {this->zero_val}},
        {"afe_dat_4_3_filtered", {this->zero_val}},
        {"afe_dat_4_4_filtered", {this->zero_val}},
        {"afe_dat_4_5_filtered", {this->zero_val}},
        {"afe_dat_4_6_filtered", {this->zero_val}},
        {"afe_dat_4_7_filtered", {this->zero_val}},
        {"afe_dat_4_8_filtered", {this->zero_val}},
        {"oeiclk", {this->zero_val}},
        {"fclk", {this->zero_val}},
        {"dout", {this->zero_val}},
        {"kout", {this->zero_val}},
        {"Rcount_addr", {this->zero_val}},
        {"Rcount", {this->zero_val, this->zero_val}}
    };

    this->get_module_port_numbers();
    this->set_port_initial_values();
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::get_module_port_numbers(){
    for(auto& it: this->port_map){
        it.second.port_number = this->loader->get_port_number(it.first.c_str());
        if(it.second.port_number < 0) {
            std::cerr << "ERROR: " << it.first << " not found" << std::endl;
            exit(1);
        }
        std::cout << "Port name: " << it.first << " -- Port number: " << it.second.port_number << std::endl;
    }
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::set_port_initial_values(){
    for(auto& it : this->port_map){
        if(it.second.port_type == 0) {
            std::cout << "Setting port: " << it.first << " number: " << it.second.port_number <<" to value: " << logic_val_to_string(&this->port_values[it.first][0], this->port_map[it.first].port_size) << std::endl;
            this->loader->put_value(it.second.port_number, this->port_values[it.first].data());
        }else{
            continue;
        }
    }
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::set_port_value(const std::string &port_name){
    // this function is used to set the value of a port
    int port_num = this->port_map.find(port_name)->second.port_number;
    if(port_num < 0) {
        std::cerr << "ERROR: " << port_name << " not found" << std::endl;
        exit(1);
    }
    this->loader->put_value(port_num, this->port_values[port_name].data());
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::get_port_value(const std::string &port_name){
    // this function is used to get the value of a port
    int port_num = this->port_map.find(port_name)->second.port_number;
    if(port_num < 0) {
        std::cerr << "ERROR: " << port_name << " not found" << std::endl;
        exit(1);
    }
    this->loader->get_value(port_num, this->port_values[port_name].data());
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::cycle_clocks(){
    //this function is used to step bot clocks
    // aclk is 62.5 Mhz and fclk will be considered doubled to 125 Mhz
    // so we will step aclk every 16 ns and fclk every 8 ns
    // constants 
    this->loader->put_value(this->port_map["aclk"].port_number, &this->zero_val);
    this->loader->put_value(this->port_map["fclk"].port_number, &this->zero_val);
    this->loader->put_value(this->port_map["oeiclk"].port_number, &this->zero_val);
    this->loader->run(1);
    this->loader->put_value(this->port_map["aclk"].port_number, &this->zero_val);
    this->loader->put_value(this->port_map["fclk"].port_number, &this->one_val);
    this->loader->put_value(this->port_map["oeiclk"].port_number, &this->one_val);
    this->loader->run(1);
    this->loader->put_value(this->port_map["aclk"].port_number, &this->one_val);
    this->loader->put_value(this->port_map["fclk"].port_number, &this->zero_val);
    this->loader->put_value(this->port_map["oeiclk"].port_number, &this->zero_val);
    this->loader->run(1);
    this->loader->put_value(this->port_map["aclk"].port_number, &this->one_val);
    this->loader->put_value(this->port_map["fclk"].port_number, &this->one_val);
    this->loader->put_value(this->port_map["oeiclk"].port_number, &this->one_val);
    this->loader->run(1);
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::run_n_cycles(const int & n_cycles){
    // this function is used to run the simulation for n cycles
    for(int i = 0; i < n_cycles; i++){
        this->cycle_clocks();
    }
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::reset_design(){
    // this function is used to reset the design
    this->loader->put_value(this->port_map["reset_aclk"].port_number, &this->one_val);
    this->loader->put_value(this->port_map["reset_fclk"].port_number, &this->one_val);
    this->run_n_cycles(320);
    this->loader->put_value(this->port_map["reset_aclk"].port_number, &this->zero_val);
    this->loader->put_value(this->port_map["reset_fclk"].port_number, &this->zero_val);
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::set_configuration(const std::string &file){

}

std::vector<uint32_t> daphne_st_simulator::daphne_st_top_hdl_simulator::run_simulation(const std::vector<uint16_t> &input_data){
    // this function is used to run the simulation
    std::vector<uint32_t> simulation_stream;
    for(auto& it: input_data){
        this->port_values["afe_dat_0_0"][0].aVal = it;
        this->set_port_value("afe_dat_0_0");
        this->cycle_clocks();
        this->get_port_value("dout");
        simulation_stream.push_back(this->port_values["dout"][0].aVal);
    }
    return simulation_stream;
}

std::vector<dunedaq::fddetdataformats::DAPHNEFrame> daphne_st_simulator::daphne_st_top_hdl_simulator::decode_simulation_stream(const std::vector<uint32_t> &simulation_stream){
    std::vector<dunedaq::fddetdataformats::DAPHNEFrame> frames;
    for(auto& it: simulation_stream){
        dunedaq::fddetdataformats::DAPHNEFrame frame;
        frames.push_back(frame);
    }
    return frames;
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::append_logic_val_bit_to_string(std::string& retVal, int aVal, int bVal)
{
     if(aVal == 0) {
        if(bVal == 0) {
           retVal +="0";
        } else {
           retVal +="Z";
        }
     } else { // aVal == 1
        if(bVal == 0) {
           retVal +="1";
        } else {
           retVal +="X";
        }
     }
}


void daphne_st_simulator::daphne_st_top_hdl_simulator::append_logic_val_to_string(std::string& retVal, int aVal, int bVal, int max_bits)
{
   int bit_mask = 0X00000001;
   int aVal_bit, bVal_bit;
   for(int k=max_bits; k>=0; k--) {
      aVal_bit = (aVal >> k ) & bit_mask;
      bVal_bit = (bVal >> k ) & bit_mask;
      append_logic_val_bit_to_string(retVal, aVal_bit, bVal_bit);
   }
}

std::string daphne_st_simulator::daphne_st_top_hdl_simulator::logic_val_to_string(s_xsi_vlog_logicval* value, int size)
{
   std::string retVal;

   int num_words = size/32 + 1;
   int max_lastword_bit = size %32 - 1;

   // last word may have unfilled bits
   int  aVal = value[num_words -1].aVal;
   int  bVal = value[num_words -1].bVal;
   append_logic_val_to_string(retVal, aVal, bVal, max_lastword_bit);
   
   // this is for fully filled 32 bit aVal/bVal structs
   for(int k = num_words - 2; k>=0; k--) {
      aVal = value[k].aVal;
      bVal = value[k].bVal;
      append_logic_val_to_string(retVal, aVal, bVal, 31);
   }
   return retVal;
}

void daphne_st_simulator::daphne_st_top_hdl_simulator::close(){
    try {
        this->loader->close();
    } catch (const std::exception& e) {
        std::cerr << "Error closing the simulator: " << e.what() << std::endl;
    } catch (...) {
        std::cerr << "Unknown error occurred while closing the simulator." << std::endl;
    }
}
