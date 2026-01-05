# DAPHNE V2 Self‑Trigger Simulation

This repository contains a standalone environment to exercise the DAPHNE V2 self‑trigger (ST) HDL with realistic waveforms. The HDL is compiled with Xilinx Vivado/XSim into a shared object and then driven from a C++ wrapper through the Xilinx Simulation Interface (XSI). A small testbench (`src/testbench.cpp`) shows how to feed detector waveforms and extract the serialized DAPHNE frames that the ST logic would emit inside the DAQ.

The project is meant for algorithm developers who want to validate the ST behavior without a full FPGA build or hardware access.

---

## Repository layout

- `hdl_files/`, `selftrigger_project.prj` – VHDL/Verilog sources for the ST pipeline (`st40_top_wrapper` is the elaboration top).
- `elaborate.csh` – wraps `xelab` to elaborate the HDL into `xsim.dir/st40_sim/xsimk.so`.
- `src/daphne_st_top_hdl_simulator.cpp` – C++ wrapper that mirrors every HDL port, provides resets/clocks, and streams data through XSI.
- `src/testbench.cpp` – example driver: loads per‑channel CSV waveforms, applies configuration, runs the simulation, and prints timing info.
- `include/` – public headers, the DAQ data format helpers (`fddetdataformats`), and third‑party deps (`nlohmann/json`, `xsi_loader.h`).
- `config/conf.json` – DAQ‑style configuration consumed by the wrapper to populate thresholds, enable masks, and the list/order of simulated channels.
- `data/` – sample waveform CSVs (`ch0.csv`, `ch17.csv`, `ch20.csv`, `ch34.csv`, `ch37.csv`) aligned with the enabled channel list. These files now model five independent detector channels captured in protoDUNE‑NP02.
- `lib/` – staging area for the shared library (`libdaphne_st_sim_lib.so`) produced by `compile.csh`.
- `compile.csh` – builds the wrapper, links against the XSI runtime, and runs the `selftrigger_simulation` executable.

---

## Prerequisites

1. **Vivado 2024.1** (or a compatible release with XSim/XSI). Both scripts assume the tools live under `/opt/Xilinx/Vivado/2024.1`; edit `XILINX_VIVADO` if needed.
2. **g++** with C++17 support (scripts default to `/usr/bin/g++`).
3. **C shell** (`/bin/csh`) to run the helper scripts.
4. A Unix‑like environment with permission to create shared objects (the scripts update `LD_LIBRARY_PATH` accordingly).

> 📝 Xilinx’ shared XSI libraries must remain discoverable at runtime. If you relocate the repository or use a different Vivado version, mirror the edits inside both `.csh` scripts.

---

## Quick start

```bash
./elaborate.csh          # builds xsim.dir/st40_sim/xsimk.so via xelab
./compile.csh            # compiles the C++ wrapper and executes ./selftrigger_simulation
```

The second step produces:

- `lib/libdaphne_st_sim_lib.so` – shared wrapper around `daphne_st_top_hdl_simulator`.
- `selftrigger_simulation` – executable testbench that drives the HDL, prints elapsed time, and leaves the serialized DAPHNE frames in memory (`simulation_stream`).

During the run you will see verbose port logs the first time the wrapper initializes every HDL signal. The testbench now concatenates multiple waveforms—one per enabled channel—and streams them simultaneously through the HDL so that realistic multi‑channel correlations can be inspected.

---

## Simulation flow

1. **Configuration**  
   `daphne_st_top_hdl_simulator::set_configuration()` parses `config/conf.json`, which follows the DAQ JSON schema (`devices[0].self_trigger`). The wrapper extracts:
   - Enabled channels / compensators / inverters (converted into bit masks for the HDL ports).
   - Scalar parameters such as `threshold`, `slope_mode`, `slope_threshold`, `pedestal_length`, and the spybuffer channel.
   - Spy buffer selector (`st_40_signals_enable_reg`) and filter mode (`filter_output_selector`).

2. **Waveform ingestion**  
   The helper `read_csv_to_u16_vector()` in `testbench.cpp` converts comma‑separated ADC samples into `uint16_t` values. The reference driver loads five CSVs (`data/ch0.csv`, `ch17.csv`, `ch20.csv`, `ch34.csv`, `ch37.csv`) and appends them in the same order defined inside `config/conf.json -> devices[0].channels.indices`. The wrapper expects `input_data` to contain one contiguous block per channel (all samples from channel 0, then channel 17, etc.); it extracts per‑sample tuples internally when clocking the HDL. To simulate a different detector subset, drop new CSVs into `data/`, update the channel indices, and adjust the list loaded in the testbench.

3. **Clocking and streaming**  
   `daphne_st_top_hdl_simulator` hides the XSI ceremony: it resets the design, toggles the 62.5 MHz `aclk` and 125 MHz `fclk`, and writes each sample into the proper `afe_dat_*` ports for every enabled channel. Two `fclk` edges are run per sample to match the HDL requirements. Once the payload is loaded it keeps stepping the design until the serialized packet stream ends (`0xDC` end marker or timeout). The raw `dout` words are appended to `simulation_stream`.

4. **Decoding** (optional)  
   A stub for `decode_simulation_stream()` exists in `daphne_st_sim.h`. Link against `fddetdataformats` and populate this function if you want automatic conversion into `dunedaq::fddetdataformats::DAPHNEFrame` objects.

---

## Customization tips

- **Different Vivado snapshot:** change `OUT_SIM_SNAPSHOT` inside both scripts if you elaborate a different top entity.
- **Alternate waveforms:** drop new CSV files under `data/` (one per enabled channel) and tweak the loading list near the top of `src/testbench.cpp`, keeping the order synchronized with `config/conf.json`.
- **Headless library use:** `compile.csh` emits the shared library even if you skip running `selftrigger_simulation`. You can link your own C++ application against `lib/libdaphne_st_sim_lib.so`; include `include/daphne_st_sim.h` and drive the class directly.
- **Configuration sweeps:** script the JSON edits (thresholds, slope mode, channel masks) and rerun `compile.csh`. The HDL only needs to be re‑elaborated (`elaborate.csh`) when the RTL changes.
- **Performance tuning:** adjust `clk_sim_step` in `testbench.cpp` to trade off simulation speed vs. stability (default is 4000 ps per call, i.e., 4 ns).

---

## Troubleshooting

- **`ERROR: <port> not found` during initialization** – ensure `xsim.dir/st40_sim/xsimk.so` exists and matches the HDL provided in `selftrigger_project.prj`. Re‑run `elaborate.csh`.
- **`cannot open shared object file: librdi_simulator_kernel.so`** – confirm that `LD_LIBRARY_PATH` includes `$XILINX_VIVADO/lib/lnx64.o` (the scripts add it temporarily; mirror the logic if you run the binaries manually).
- **Empty `simulation_stream`** – verify that the CSV contains data, the JSON enables the desired channels, and the thresholds are reachable by your waveforms. The wrapper stops after `ncycles_stop_condition` (2 500) idle cycles if no packets appear.
- **Linker errors about `xsi_loader`** – the default compile script pulls the Xilinx example source from `$XILINX_VIVADO/examples/xsim/verilog/xsi/counter`; update `XSI_LOADER_INCLUDE_DIR` if your Vivado layout differs.

---

## Next steps

- Implement `decode_simulation_stream()` to translate the raw 32‑bit words into DAQ frames programmatically.
- Extend `testbench.cpp` so it writes the captured frames to disk or to ROOT files for downstream analysis.
- Add CI scripts that regenerate the HDL snapshot and run regression suites against multiple JSON configurations.

Feel free to adapt this README as you evolve the simulator—external collaborators will appreciate an updated description of any new scripts or data products.
