-- stc.vhd
-- self triggered channel machine for ONE DAPHNE channel
-- 
-- This module watches one channel data bus and computes the average signal level 
-- (baseline.vhd) based on the last 256 samples. When it detects a trigger condition
-- (defined in trig.vhd) it then begins assemblying the output frame in a FIFO. 
-- It stores 64 pre trigger samples plus + post trigger samples, densely packed. 
-- a single 32x1024 FIFO can store nearly 9 output records.
-- 
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity stc is
generic( link_id: std_logic_vector(5 downto 0) := "000000"; ch_id: std_logic_vector(5 downto 0) := "000000" );
port(
    reset: in std_logic;    
    slot_id: std_logic_vector(3 downto 0);
    crate_id: std_logic_vector(9 downto 0);
    detector_id: std_logic_vector(5 downto 0);
    version_id: std_logic_vector(5 downto 0);
    adhoc: std_logic_vector(7 downto 0); -- command for adhoc trigger
    st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay: in std_logic_vector(4 downto 0);
    threshold_xc: in std_logic_vector(41 downto 0); -- trig threshold relative to calculated baseline
    filter_output_selector: in std_logic_vector(1 downto 0); --Esteban 
    ti_trigger: in std_logic_vector(7 downto 0); -------------------------
    ti_trigger_stbr: in std_logic;  -------------------------
    reset_st_counters: in std_logic;
    aclk: in std_logic; -- AFE clock 62.500 MHz
    timestamp: in std_logic_vector(63 downto 0);
	afe_dat: in std_logic_vector(13 downto 0); -- aligned AFE data
    st_afe_dat_filtered: out std_logic_vector(13 downto 0); -- aligned AFE data filtered
    enable: in std_logic;
    afe_comp_enable: in std_logic;
    invert_enable: in std_logic;
    trigger_signal: out std_logic;
    fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
    fifo_rden: in std_logic;
    fifo_ae: out std_logic;
    fifo_do: out std_logic_vector(31 downto 0);
    fifo_ko: out std_logic_vector( 3 downto 0);
    TCount: out std_logic_vector(63 downto 0);
    Pcount: out std_logic_vector(63 downto 0)
  );
end stc;

architecture stc_arch of stc is

    signal afe_dly32_i, afe_dly64_i, afe_dly96_i, afe_dly128_i, afe_dly160_i, afe_dly192_i, afe_dly224_i, afe_dly: std_logic_vector(13 downto 0);
    signal afe_dly0, afe_dly1, afe_dly2: std_logic_vector(13 downto 0);
    signal block_count: std_logic_vector(5 downto 0);

    type state_type is (rst, wait4trig, 
                        sof, hdr0, hdr1, hdr2, hdr3, hdr4, 
                        dat0, dat1, dat2, dat3, dat4, dat5, dat6, dat7, dat8, dat9, dat10, dat11, dat12, dat13, dat14, dat15, 
                        trailer1, trailer2, trailer3, trailer4, trailer5, trailer6, 
                        trailer7, trailer8, trailer9, trailer10, trailer11, trailer12, trailer13, eof);

    type trigger_counter_state_type is (rst_trggr, wait4trig_trggr, rising_triggered);

    signal state: state_type;
    signal trigger_counter_state: trigger_counter_state_type;

    signal d: std_logic_vector(31 downto 0);
    signal ts_reg: std_logic_vector(63 downto 0);
    signal k: std_logic_vector(3 downto 0);
    signal fifo_wren: std_logic;
    signal almostempty: std_logic_vector(3 downto 0);
    signal almostfull: std_logic_vector(3 downto 0);
    signal fifo_af: std_logic;
    signal reset_ciemat, triggered_bicocca_reg_1, triggered_bicocca_reg_2: std_logic;
    signal trigCount: unsigned(63 downto 0) := (others => '0');
    signal packCount: unsigned(63 downto 0) := (others => '0');

    type array_4x64_type is array(3 downto 0) of std_logic_vector(63 downto 0);
    signal DI, DO: array_4x64_type;

    type array_4x8_type is array(3 downto 0) of std_logic_vector(7 downto 0);
    signal DIP, DOP: array_4x8_type;

    signal baseline, trigsample: std_logic_vector(13 downto 0);
    signal afe_dat_filtered: std_logic_vector(13 downto 0);
    signal afe_dat_filtered_TP: std_logic_vector(13 downto 0);

    --signal    Self_trigger_aux:                    std_logic;                                              -- Self-Trigger signal comming from the Self-Trigger block
    signal    Data_Available_aux:                  std_logic;                                              -- ACTIVE HIGH when LOCAL primitives are calculated
    signal    Time_Peak_aux:                       std_logic_vector(8 downto 0);                           -- Time in Samples to achieve de Max peak
    signal    Time_Pulse_UB_aux:                   std_logic_vector(8 downto 0);                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
    signal    Time_Pulse_OB_aux:                   std_logic_vector(9 downto 0);                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
    signal    Max_Peak_aux:                        std_logic_vector(13 downto 0);                          -- Amplitude in ADC counts od the peak
    signal    Charge_aux:                          std_logic_vector(22 downto 0);                          -- Charge of the light pulse (without undershoot) in ADC*samples
    signal    Number_Peaks_UB_aux:                 std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
    signal    Number_Peaks_OB_aux:                 std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is OVER BASELINE (undershoot).  
    --signal    filtered_dout_aux:                   std_logic_vector (13 downto 0);                         -- HIGH PASS Filtered signal
    --signal    Baseline_aux:                        std_logic_vector(14 downto 0);                          -- Real Time calculated BASELINE
    signal    Amplitude_aux:                       std_logic_vector(14 downto 0);                          -- Real Time calculated AMPLITUDE
    signal    Peak_Current_aux:                    std_logic;                                              -- ACTIVE HIGH when a peak is detected
    signal    Slope_Current_aux:                   std_logic_vector(13 downto 0);                          -- Real Time calculated SLOPE
    signal    Slope_Threshold_aux:                 std_logic_vector(6 downto 0);                           -- Threshold over the slope to detect Peaks
    signal    Detection_aux:                       std_logic;                                              -- ACTIVE HIGH when primitives are being calculated (during light pulse)
    signal    Sending_aux:                         std_logic;                                              -- ACTIVE HIGH when colecting data for self-trigger frame
    signal    Info_Previous_aux:                   std_logic;                                              -- ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
    signal    Data_Available_Trailer_aux:          std_logic;                                              -- ACTIVE HIGH when metadata is ready
    signal    Trailer_Word_0_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_1_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_2_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_3_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_4_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_5_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_6_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_7_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_8_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_9_aux:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_10_aux:                 std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
    signal    Trailer_Word_11_aux:                 std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)

    signal    Trailer_Word_0_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_1_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_2_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_3_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_4_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_5_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_6_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_7_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_8_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_9_reg:                  std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_10_reg:                 std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER
    signal    Trailer_Word_11_reg:                 std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives) REGISTER

    component Self_Trigger_Primitive_Calculation is -- establish average signal level
    port(
        clock:                          in  std_logic;                                              -- AFE clock
        reset:                          in  std_logic;                                              -- Reset signal. ACTIVE HIGH
        din:                            in  std_logic_vector(13 downto 0);                          -- Data coming from the Filter Block / Raw data from AFEs
        Config_Param:                   in  std_logic_vector(13 downto 0);                          -- Configure parameters for filtering & self-trigger bloks
        Ext_Self_Trigger:               in  std_logic;                                              -- External Self-Trigger coming from another block
        Self_trigger:                   out std_logic;                                              -- Self-Trigger signal comming from the Self-Trigger block
        Data_Available:                 out std_logic;                                              -- ACTIVE HIGH when LOCAL primitives are calculated
        Time_Peak:                      out std_logic_vector(8 downto 0);                           -- Time in Samples to achieve de Max peak
        Time_Over_Baseline:             out std_logic_vector(8 downto 0);                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
        Time_Start:                     out std_logic_vector(9 downto 0);                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
        ADC_Peak:                       out std_logic_vector(13 downto 0);                          -- Amplitude in ADC counts od the peak
        ADC_Integral:                   out std_logic_vector(22 downto 0);                          -- Charge of the light pulse (without undershoot) in ADC*samples
        Number_Peaks:                   out std_logic_vector(3 downto 0);                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
        --filtered_dout:                  out std_logic_vector (13 downto 0);                         -- HIGH PASS Filtered signal
        Baseline:                       in std_logic_vector(13 downto 0);                          -- Real Time calculated BASELINE
        Amplitude:                      out std_logic_vector(14 downto 0);                          -- Real Time calculated AMPLITUDE
        Peak_Current:                   out std_logic;                                              -- ACTIVE HIGH when a peak is detected
        Slope_Current:                  out std_logic_vector(13 downto 0);                          -- Real Time calculated SLOPE
        Slope_Threshold:                out std_logic_vector(6 downto 0);                           -- Threshold over the slope to detect Peaks
        Detection:                      out std_logic;                                              -- ACTIVE HIGH when primitives are being calculated (during light pulse)
        Sending:                        out std_logic;                                              -- ACTIVE HIGH when colecting data for self-trigger frame
        Info_Previous:                  out std_logic;                                              -- ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
        Data_Available_Trailer:         out std_logic;                                              -- ACTIVE HIGH when metadata is ready
        Trailer_Word_0:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_1:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_2:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_3:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_4:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_5:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_6:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_7:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_8:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_9:                 out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_10:                out std_logic_vector(31 downto 0);                          -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_11:                out std_logic_vector(31 downto 0));                         -- TRAILER WORD with metada (Local Trigger Primitives)
    end component;
    
    component trig is -- example trigger algorithm broken out separately, latency = 64 clocks
    port(
        clock: in std_logic;
        reset: in std_logic;
        enable: in std_logic;
        afe_comp_enable: in std_logic;
        invert_enable: in std_logic;
        din: in std_logic_vector(13 downto 0);
        dout1: out std_logic_vector(13 downto 0);
        dout2: out std_logic_vector(13 downto 0);
        baseline: out std_logic_vector(13 downto 0);
        adhoc: in std_logic_vector(7 downto 0);
        threshold_xc: in std_logic_vector(41 downto 0);
        filter_output_selector: in std_logic_vector(1 downto 0);
        triggered: out std_logic;        
        trigsample: out std_logic_vector(13 downto 0);
        ti_trigger: in std_logic_vector(7 downto 0); -------------------------
        ti_trigger_stbr: in std_logic);  -------------------------
    end component;

    component CRC_OL is
    generic( Nbits: positive := 32; CRC_Width: positive := 20;
             G_Poly: std_logic_vector := X"8359f"; G_InitVal: std_logic_vector := X"fffff" );
    port(
        CRC: out std_logic_vector(CRC_Width-1 downto 0);
        Calc: in std_logic;
        Clk: in std_logic;
        DIn: in std_logic_vector(Nbits-1 downto 0);
        Reset: in std_logic);
    end component;

    signal crc_calc, crc_reset, triggered, triggered_bicocca, triggered_ciemat: std_logic;
    signal crc20: std_logic_vector(19 downto 0);

begin

    -- delay input data by 128 clocks to compensate for 64 clock trigger latency 
    -- and also for capturing 64 pre-trigger samples

    gendelay: for i in 13 downto 0 generate

        srlc32e_0_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dat_filtered(i), -- real time AFE data
            q => open,
            q31 => afe_dly32_i(i)
        );
    
        srlc32e_1_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly32_i(i),
            q => open,
            q31 => afe_dly64_i(i)
        );

        srlc32e_2_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly64_i(i),
            q => open,
            q31 => afe_dly96_i(i)
        );

        srlc32e_3_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly96_i(i),
            q => open,
            q31 => afe_dly128_i(i)
        );

        -- add around 150 delays

        srlc32e_4_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly128_i(i),
            q => open,
            q31 => afe_dly160_i(i)
        );

        srlc32e_5_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly160_i(i),
            q => open,
            q31 => afe_dly192_i(i)
        );

        srlc32e_6_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly192_i(i),
            q => open,
            q31 => afe_dly224_i(i)
        );

        srlc32e_7_inst : srlc32e
        port map(
            clk => aclk,
            ce => '1',
            a => signal_delay,
            d => afe_dly224_i(i),
            q => afe_dly(i),
            q31 => open
        );

        
    -- add around 116 delays



    end generate gendelay;

    -- compute the average signal baseline level over the last 256 samples

    --baseline_inst: baseline256
    --port map(
    --    clock => aclk,
    --    reset => reset,
    --    din => afe_dat, -- watching live AFE data
    --    baseline => baseline
    --);

    -- now for dense data packing, we need to access up to last 4 samples at once...

    pack_proc: process(aclk)
    begin
        if rising_edge(aclk) then
            afe_dly0 <= afe_dly;
            afe_dly1 <= afe_dly0;
            afe_dly2 <= afe_dly1;
            -- selftrigger delay for Nacho's module
            triggered_bicocca_reg_1 <= triggered_bicocca;
            triggered_bicocca_reg_2 <= triggered_bicocca_reg_1;
        end if;
    end process pack_proc;       

    -- trigger algorithm in a separate module. this latency is assumed to be 64 cycles

    bicocca_trig_inst: trig
    port map(
        clock => aclk,
        reset => reset,
        enable => enable,
        afe_comp_enable => afe_comp_enable,
        invert_enable => invert_enable,
        din => afe_dat, -- watching live AFE data
        dout1 => afe_dat_filtered,
        dout2 => afe_dat_filtered_TP,
        adhoc => adhoc,
        baseline => baseline,
        threshold_xc => threshold_xc,
        filter_output_selector => filter_output_selector,
        triggered => triggered_bicocca,
        trigsample => trigsample, -- the ADC sample that caused the trigger 
        ti_trigger => ti_trigger,
        ti_trigger_stbr => ti_trigger_stbr
    );

        ------------------- SELF-TRIGGER AND LOCAL PRIMITIVE CALCULATION DEVELOPED AT CIEMAT ---------
    reset_ciemat <= '1' when (reset='1' or state=wait4trig) else '0';
    ciemat_trig_inst: Self_Trigger_Primitive_Calculation
    port map(
        clock                       => aclk,                           -- AFE clock
        reset                       => reset_ciemat,                          -- Reset signal. ACTIVE HIGH
        din                         => afe_dat_filtered_TP,               -- Data coming from the Filter Block / Raw data from AFEs
        Config_Param                => st_config,                      -- Configure parameters for filtering & self-trigger bloks
        Ext_Self_Trigger            => triggered_bicocca_reg_2,              --External Self-Trigger coming from another block
        Self_trigger                => open,                           -- Self-Trigger signal comming from the Self-Trigger block
        Data_Available              => open,                           -- ACTIVE HIGH when LOCAL primitives are calculated
        Time_Peak                   => open,                           -- Time in Samples to achieve de Max peak
        Time_Over_Baseline          => open,                           -- Time in Samples of the light pulse signal is UNDER BASELINE (without undershoot)
        Time_Start                  => open,                           -- Time in Samples of the light pulse signal is OVER BASELINE (undershoot)
        ADC_Peak                    => open,                           -- Amplitude in ADC counts od the peak
        ADC_Integral                => open,                           -- Charge of the light pulse (without undershoot) in ADC*samples
        Number_Peaks                => open,                           -- Number of peaks detected when signal is UNDER BASELINE (without undershoot).  
        --filtered_dout               => open,                           -- HIGH PASS Filtered signal
        Baseline                    => baseline,                           
        Amplitude                   => open,                           -- Real Time calculated AMPLITUDE
        Peak_Current                => open,                           -- ACTIVE HIGH when a peak is detected
        Slope_Current               => open,                           -- Real Time calculated SLOPE
        Slope_Threshold             => open,                           -- Threshold over the slope to detect Peaks
        Detection                   => open,                           -- ACTIVE HIGH when primitives are being calculated (during light pulse)
        Sending                     => open,                           -- ACTIVE HIGH when colecting data for self-trigger frame
        Info_Previous               => Info_Previous_aux,              -- ACTIVE HIGH when self-trigger is produced by a waveform between two frames 
        Data_Available_Trailer      => Data_Available_Trailer_aux,     -- ACTIVE HIGH when metadata is ready
        Trailer_Word_0              => Trailer_Word_0_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_1              => Trailer_Word_1_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_2              => Trailer_Word_2_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_3              => Trailer_Word_3_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_4              => Trailer_Word_4_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_5              => Trailer_Word_5_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_6              => Trailer_Word_6_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_7              => Trailer_Word_7_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_8              => Trailer_Word_8_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_9              => Trailer_Word_9_aux,             -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_10             => Trailer_Word_10_aux,            -- TRAILER WORD with metada (Local Trigger Primitives)
        Trailer_Word_11             => Trailer_Word_11_aux             -- TRAILER WORD with metada (Local Trigger Primitives)
    ); 
    -- Prepare data for the data format 
    Local_primitives_frame: process(aclk,Data_Available_Trailer_aux)
    begin
        if (rising_edge(aclk)) then
            if (reset_ciemat ='1') then
               Trailer_Word_0_reg <= (others => '0');
               Trailer_Word_1_reg <= (others => '0');
               Trailer_Word_2_reg <= (others => '0');
               Trailer_Word_3_reg <= (others => '0');
               Trailer_Word_4_reg <= (others => '0');
               Trailer_Word_5_reg <= (others => '0');
               Trailer_Word_6_reg <= (others => '0');
               Trailer_Word_7_reg <= (others => '0');
               Trailer_Word_8_reg <= (others => '0');
               Trailer_Word_9_reg <= (others => '0');
               Trailer_Word_10_reg <= (others => '0');
               Trailer_Word_11_reg <= (others => '0');
            elsif (Data_Available_Trailer_aux ='1') then
               Trailer_Word_0_reg <= Trailer_Word_0_aux;
               Trailer_Word_1_reg <= Trailer_Word_1_aux;
               Trailer_Word_2_reg <= Trailer_Word_2_aux;
               Trailer_Word_3_reg <= Trailer_Word_3_aux;
               Trailer_Word_4_reg <= Trailer_Word_4_aux;
               Trailer_Word_5_reg <= Trailer_Word_5_aux;
               Trailer_Word_6_reg <= Trailer_Word_6_aux;
               Trailer_Word_7_reg <= Trailer_Word_7_aux;
               Trailer_Word_8_reg <= Trailer_Word_8_aux;
               Trailer_Word_9_reg <= Trailer_Word_9_aux;
               Trailer_Word_10_reg <= Trailer_Word_10_aux;
               Trailer_Word_11_reg <= Trailer_Word_11_aux;
            end if;
        end if;
    end process Local_primitives_frame;      

    -- FSM waits for trigger condition then assembles output frame and stores into FIFO

    count_proc: process(aclk, reset, enable, triggered, reset_st_counters)
    begin
        if rising_edge(aclk) then
            if ( reset='1' or reset_st_counters='1' or enable='0') then
                trigCount <= (others => '0');
                trigger_counter_state <= rst_trggr;
            else
                case(trigger_counter_state) is
                    when rst_trggr =>
                        trigger_counter_state <= wait4trig_trggr;
                    when wait4trig_trggr =>
                        if ( triggered='1') then
                            trigCount <= trigCount + 1;
                            trigger_counter_state <= rising_triggered;
                        else
                            trigger_counter_state <= wait4trig_trggr;
                        end if;
                    when rising_triggered =>
                        if ( triggered='1') then
                            trigger_counter_state <= rising_triggered;
                        else
                            trigger_counter_state <= wait4trig_trggr;
                        end if;
                    when others =>
                        trigger_counter_state <= rst_trggr;
                    end case; 
            end if;
        end if;
    end process count_proc;

    builder_fsm_proc: process(aclk, reset, enable, triggered, fifo_af, reset_st_counters)
    begin
        if rising_edge(aclk) then
            if (reset='1' or reset_st_counters='1') then ---------------////
                state <= rst;
                packCount <= (others => '0');
            else
                case(state) is
                    when rst =>
                        state <= wait4trig;
                    when wait4trig => 
                        if (triggered='1' and enable='1' and fifo_af='1') then -- start assembling the output frame
                            block_count <= (others => '0');
                            packCount <= packCount + 1;
                            ts_reg <= std_logic_vector( unsigned(timestamp) - 124 );
                            state <= sof; 
                        else
                            state <= wait4trig; --962 760 410 El de las naranjas
                        end if;
                    when sof =>
                        state <= hdr0;
                    when hdr0 =>
                        state <= hdr1;
                    when hdr1 =>
                        state <= hdr2;
                    when hdr2 =>
                        state <= hdr3;
                    when hdr3 =>
                        state <= hdr4;
                    when hdr4 =>
                        state <= dat0;
                    when dat0 =>
                        state <= dat1;
                    when dat1 =>
                        state <= dat2;
                    when dat2 =>
                        state <= dat3;
                    when dat3 =>
                        state <= dat4;
                    when dat4 =>
                        state <= dat5;
                    when dat5 =>
                        state <= dat6;
                    when dat6 =>
                        state <= dat7;
                    when dat7 =>
                        state <= dat8;
                    when dat8 =>
                        state <= dat9;
                    when dat9 =>
                        state <= dat10;
                    when dat10 =>
                        state <= dat11;
                    when dat11 =>
                        state <= dat12;
                    when dat12 =>
                        state <= dat13;
                    when dat13 =>
                        state <= dat14;
                    when dat14 =>
                        state <= dat15;
                    when dat15 =>
                        if (block_count="111111") then -- we have cycled through the data block (16 samples per block) 64 times, done
                            state <= trailer1;
                        else
                            block_count <= std_logic_vector(unsigned(block_count) + 1);
                            state <= dat0;
                        end if;
                    when trailer1 =>
                        state <= trailer2;
                    when trailer2 =>
                        state <= trailer3;
                    when trailer3 =>
                        state <= trailer4;
                    when trailer4 =>
                        state <= trailer5;
                    when trailer5 =>
                        state <= trailer6;
                    when trailer6 =>
                        state <= trailer7;
                    when trailer7 =>
                        state <= trailer8;
                    when trailer8 =>
                        state <= trailer9;
                    when trailer9 =>
                        state <= trailer10;
                    when trailer10 =>
                        state <= trailer11;
                    when trailer11 =>
                        state <= trailer12;
                    when trailer12 =>
                        state <= trailer13;
                    when trailer13 =>
                        state <= eof;
                    when eof =>
                        state <= wait4trig;
                    when others => 
                        state <= rst;
                end case;
            end if;
        end if;
    end process builder_fsm_proc;

    -- now based on the FSM state, form the output stream
    -- 1024 samples densely packed into (1024/16*7) = 448 words
    -- total frame lenth = SOF + 5 header + 448 data + trailer + EOF = 456 words 

    d <= X"0000003C" when (state=sof) else -- sof of frame word = D0.0 & D0.0 & D0.0 & K28.1
         link_id & slot_id & crate_id & detector_id & version_id when (state=hdr0) else
         ts_reg(31 downto 0)  when (state=hdr1) else
         ts_reg(63 downto 32) when (state=hdr2) else
         (X"0000" & Info_Previous_aux & "00000" & "0001" & ch_id(5 downto 0)) when (state=hdr3) else  -- trigger sample and channel ID
         ("00" & baseline & "00" & threshold_xc(41 downto 28)) when (state=hdr4) else -- average baseline and user-threshold
         (afe_dly0( 3 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  0))                          when (state=dat0) else  -- sample2(3..0) & sample1(13..0) & sample0(13..0) 
         (afe_dly0( 7 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  4))                          when (state=dat2) else  -- sample4(7..0) & sample3(13..0) & sample2(13..4) 
         (afe_dly0(11 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  8))                          when (state=dat4) else  -- sample6(11..0) & sample5(13..0) & sample4(13..8) 
         ( afe_dly( 1 downto 0) & afe_dly0(13 downto 0) & afe_dly1(13 downto  0) & afe_dly2(13 downto 12)) when (state=dat6) else  -- sample9(1..0) & sample8(13..0) & sample7(13..0) & sample6(13..12) 
         (afe_dly0( 5 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  2))                          when (state=dat9) else  -- sample11(5..0) & sample10(13..0) & sample9(13..2)
         (afe_dly0( 9 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto  6))                          when (state=dat11) else -- sample13(9..0) & sample12(13..0) & sample11(13..6)
         (afe_dly0(13 downto 0) & afe_dly1(13 downto 0) & afe_dly2(13 downto 10))                          when (state=dat13) else -- sample15(13..0) & sample14(13..0) & sample13(13..10)
         Trailer_Word_0_reg(31 downto 0) when (state=trailer1) else -- X"00000000"
         Trailer_Word_1_reg(31 downto 0) when (state=trailer2) else -- X"00000000"
         Trailer_Word_2_reg(31 downto 0) when (state=trailer3) else -- X"00000000"
         Trailer_Word_3_reg(31 downto 0) when (state=trailer4) else -- X"00000000"
         Trailer_Word_4_reg(31 downto 0) when (state=trailer5) else -- X"00000000"
         Trailer_Word_5_reg(31 downto 0) when (state=trailer6) else -- X"00000000"
         Trailer_Word_6_reg(31 downto 0) when (state=trailer7) else -- X"00000000"
         Trailer_Word_7_reg(31 downto 0) when (state=trailer8) else -- X"00000000"
         Trailer_Word_8_reg(31 downto 0) when (state=trailer9) else -- X"00000000"
         Trailer_Word_9_reg(31 downto 0) when (state=trailer10) else -- X"00000000"
         Trailer_Word_10_reg(31 downto 0) when (state=trailer11) else -- X"00000000"
         Trailer_Word_11_reg(31 downto 0) when (state=trailer12) else -- X"00000000"
         X"FFFFFFFF" when (state=trailer13) else
         "0000" & crc20 & X"DC" when (state=eof) else -- "0000" & CRC[19..0] & K28.6
         X"00000000"; 

    k <= "0001" when (state=sof) else
         "0001" when (state=eof) else 
         "0000";

    fifo_wren <= '1' when (state=sof) else
                 '1' when (state=hdr0) else
                 '1' when (state=hdr1) else
                 '1' when (state=hdr2) else
                 '1' when (state=hdr3) else
                 '1' when (state=hdr4) else
                 '1' when (state=dat0) else
                 '1' when (state=dat2) else
                 '1' when (state=dat4) else
                 '1' when (state=dat6) else
                 '1' when (state=dat9) else
                 '1' when (state=dat11) else
                 '1' when (state=dat13) else
                 '1' when (state=trailer1) else
                 '1' when (state=trailer2) else
                 '1' when (state=trailer3) else
                 '1' when (state=trailer4) else
                 '1' when (state=trailer5) else
                 '1' when (state=trailer6) else
                 '1' when (state=trailer7) else
                 '1' when (state=trailer8) else
                 '1' when (state=trailer9) else
                 '1' when (state=trailer10) else
                 '1' when (state=trailer11) else
                 '1' when (state=trailer12) else
                 '1' when (state=trailer13) else
                 '1' when (state=eof) else
                 '0';

    -- CRC generator is calculated over the DAPHNE frame, do not include the SOF and EOF words

    crc_calc <=  '1' when (state=hdr0) else
                 '1' when (state=hdr1) else
                 '1' when (state=hdr2) else
                 '1' when (state=hdr3) else
                 '1' when (state=hdr4) else
                 '1' when (state=dat0) else
                 '1' when (state=dat2) else
                 '1' when (state=dat4) else
                 '1' when (state=dat6) else
                 '1' when (state=dat9) else
                 '1' when (state=dat11) else
                 '1' when (state=dat13) else
                 '1' when (state=trailer1) else
                 '1' when (state=trailer2) else
                 '1' when (state=trailer3) else
                 '1' when (state=trailer4) else
                 '1' when (state=trailer5) else
                 '1' when (state=trailer6) else
                 '1' when (state=trailer7) else
                 '1' when (state=trailer8) else
                 '1' when (state=trailer9) else
                 '1' when (state=trailer10) else
                 '1' when (state=trailer11) else
                 '1' when (state=trailer12) else
                 '1' when (state=trailer13) else
                 '0';

    crc_reset <= '1' when (state=wait4trig) else '0'; -- change from SOF to idle/wait4trig to be consistant with streaming output (which works!)

    crc_inst: CRC_OL
       generic map (Nbits => 32, CRC_Width => 20, G_Poly => X"8359f", G_InitVal => X"FFFFF")
       port map(
         reset => crc_reset,
         clk => aclk,
         calc => crc_calc,
         din => d,
         crc => crc20);

     -- output FIFO is 4096 deep, so we can store up to ~8.78 output frames before overflow occurs
     -- now check the FIFO filling and draining rates so we avoid under-run...
     --
     -- BUT BE CAREFUL HERE... while it is true one complete frame is 466 words long, it takes LONGER
     -- than 466 ACLKs to write it into the FIFO because 7 data words written requires 16 clocks to receive
     -- That means that it takes: SOF + (5 Header) + (1024 data) + (13 trailer) + EOF = 1044 clocks. 
     -- At 62.5MHz this is ~16.5us. Once selected for readout, however, the event will be read from the FIFO
     -- in 466 FCLK cycles, or 3.88us. So once triggered this FIFO will fill relatively slowly, but once 

    genfifo: for i in 3 downto 0 generate

        DI(i)  <=  X"00000000000000" & d( ((8*i)+7) downto (8*i) );
        DIP(i) <=  "0000000" & k(i);

        fifo_inst: FIFO36E1 -- 9 bit wide x 4096 deep
        generic map(
            ALMOST_EMPTY_OFFSET => X"0180", -- this requires the careful tuning
            ALMOST_FULL_OFFSET => X"01D4", -- ORIGINAL X'0080' 
            DATA_WIDTH => 9,                 
            DO_REG => 1,
            EN_SYN => FALSE,                  
            EN_ECC_READ => FALSE,
            EN_ECC_WRITE => FALSE,
            FIFO_MODE => "FIFO36",         
            FIRST_WORD_FALL_THROUGH => TRUE, 
            INIT => X"000000000000000000",             
            SIM_DEVICE => "7SERIES",          
            SRVAL => X"000000000000000000"
        )
        port map(
            RST    => reset,
            RSTREG => '0',
            REGCE  => '1',
            INJECTDBITERR => '0',
            INJECTSBITERR => '0',
            WRCLK  => aclk, 
            WREN   => fifo_wren,
            DI     => DI(i), -- must be 64 bit vector, only lower byte is used
            DIP    => DIP(i), -- must be 8 bit vector, only lower bit is used
            RDCLK  => fclk,
            RDEN   => fifo_rden,
            DO     => DO(i), -- must be 64 bit vector, only lower byte is used
            DOP    => DOP(i), -- must be 8 bit vector, only lower bit is used
            ALMOSTEMPTY => almostempty(i),
            ALMOSTFULL => almostfull(i)
        );

    end generate genfifo;

    triggered <= triggered_bicocca;
    trigger_signal <= triggered;
    st_afe_dat_filtered <= afe_dly;

    fifo_ae <= '1' when (almostempty="0000") else '0';
    fifo_af <= '1' when (almostfull="0000") else '0';

    fifo_do(31 downto 0) <= DO(3)(7 downto 0) & DO(2)(7 downto 0) & DO(1)(7 downto 0) & DO(0)(7 downto 0);
    fifo_ko( 3 downto 0) <= DOP(3)(0) & DOP(2)(0) & DOP(1)(0) & DOP(0)(0);
    TCount <= std_logic_vector(trigCount); 
    Pcount <= std_logic_vector(packCount); 


end stc_arch;
