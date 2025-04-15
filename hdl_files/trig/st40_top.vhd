-- st40_top.vhd
-- DAPHNE core logic, top level, self triggered mode sender
-- all 40 AFE channels -> one output link to DAQ
-- 
-- Jamieson Olsen <jamieson@fnal.gov>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.daphne2_package.all;

entity st40_top is
generic( link_id: std_logic_vector(5 downto 0)  := "000000" ); -- this is the OUTPUT link ID that goes into the header
port(
    reset_aclk: in std_logic;
    reset_fclk: in std_logic;

    adhoc: in std_logic_vector(7 downto 0); -- user defined command for adhoc trigger
    st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
    signal_delay: in std_logic_vector(4 downto 0);
    threshold_xc: in std_logic_vector(41 downto 0); -- user defined threshold relative to avg baseline
    ti_trigger: in std_logic_vector(7 downto 0); -------------------------
    ti_trigger_stbr: in std_logic;  -------------------------
    reset_st_counters: in std_logic;
    slot_id: in std_logic_vector(3 downto 0);
    crate_id: in std_logic_vector(9 downto 0);
    detector_id: in std_logic_vector(5 downto 0);
    version_id: in std_logic_vector(5 downto 0);
    enable: in std_logic_vector(39 downto 0);
    afe_comp_enable: in std_logic_vector(39 downto 0);
    invert_enable: in std_logic_vector(39 downto 0);
    st_40_signals_enable_reg: in std_logic_vector(5 downto 0);
    st_40_selftrigger_4_spybuffer: out std_logic;
    filter_output_selector: in std_logic_vector(1 downto 0);
    aclk: in std_logic; -- AFE clock 62.500 MHz
    timestamp: in std_logic_vector(63 downto 0);
	afe_dat_0_0: in std_logic_vector(13 downto 0);
    afe_dat_0_1: in std_logic_vector(13 downto 0);
    afe_dat_0_2: in std_logic_vector(13 downto 0);
    afe_dat_0_3: in std_logic_vector(13 downto 0);
    afe_dat_0_4: in std_logic_vector(13 downto 0);
    afe_dat_0_5: in std_logic_vector(13 downto 0);
    afe_dat_0_6: in std_logic_vector(13 downto 0);
    afe_dat_0_7: in std_logic_vector(13 downto 0);
    afe_dat_0_8: in std_logic_vector(13 downto 0);

    afe_dat_1_0: in std_logic_vector(13 downto 0);
    afe_dat_1_1: in std_logic_vector(13 downto 0);
    afe_dat_1_2: in std_logic_vector(13 downto 0);
    afe_dat_1_3: in std_logic_vector(13 downto 0);
    afe_dat_1_4: in std_logic_vector(13 downto 0);
    afe_dat_1_5: in std_logic_vector(13 downto 0);
    afe_dat_1_6: in std_logic_vector(13 downto 0);
    afe_dat_1_7: in std_logic_vector(13 downto 0);
    afe_dat_1_8: in std_logic_vector(13 downto 0);

    afe_dat_2_0: in std_logic_vector(13 downto 0);
    afe_dat_2_1: in std_logic_vector(13 downto 0);
    afe_dat_2_2: in std_logic_vector(13 downto 0);
    afe_dat_2_3: in std_logic_vector(13 downto 0);
    afe_dat_2_4: in std_logic_vector(13 downto 0);
    afe_dat_2_5: in std_logic_vector(13 downto 0);
    afe_dat_2_6: in std_logic_vector(13 downto 0);
    afe_dat_2_7: in std_logic_vector(13 downto 0);
    afe_dat_2_8: in std_logic_vector(13 downto 0);

    afe_dat_3_0: in std_logic_vector(13 downto 0);
    afe_dat_3_1: in std_logic_vector(13 downto 0);
    afe_dat_3_2: in std_logic_vector(13 downto 0);
    afe_dat_3_3: in std_logic_vector(13 downto 0);
    afe_dat_3_4: in std_logic_vector(13 downto 0);
    afe_dat_3_5: in std_logic_vector(13 downto 0);
    afe_dat_3_6: in std_logic_vector(13 downto 0);
    afe_dat_3_7: in std_logic_vector(13 downto 0);
    afe_dat_3_8: in std_logic_vector(13 downto 0);

    afe_dat_4_0: in std_logic_vector(13 downto 0);
    afe_dat_4_1: in std_logic_vector(13 downto 0);
    afe_dat_4_2: in std_logic_vector(13 downto 0);
    afe_dat_4_3: in std_logic_vector(13 downto 0);
    afe_dat_4_4: in std_logic_vector(13 downto 0);
    afe_dat_4_5: in std_logic_vector(13 downto 0);
    afe_dat_4_6: in std_logic_vector(13 downto 0);
    afe_dat_4_7: in std_logic_vector(13 downto 0);
    afe_dat_4_8: in std_logic_vector(13 downto 0);

    afe_dat_0_0_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_1_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_2_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_3_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_4_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_5_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_6_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_7_filtered: out std_logic_vector(13 downto 0);
    afe_dat_0_8_filtered: out std_logic_vector(13 downto 0);

    afe_dat_1_0_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_1_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_2_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_3_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_4_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_5_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_6_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_7_filtered: out std_logic_vector(13 downto 0);
    afe_dat_1_8_filtered: out std_logic_vector(13 downto 0);

    afe_dat_2_0_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_1_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_2_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_3_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_4_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_5_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_6_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_7_filtered: out std_logic_vector(13 downto 0);
    afe_dat_2_8_filtered: out std_logic_vector(13 downto 0);

    afe_dat_3_0_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_1_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_2_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_3_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_4_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_5_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_6_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_7_filtered: out std_logic_vector(13 downto 0);
    afe_dat_3_8_filtered: out std_logic_vector(13 downto 0);

    afe_dat_4_0_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_1_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_2_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_3_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_4_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_5_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_6_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_7_filtered: out std_logic_vector(13 downto 0);
    afe_dat_4_8_filtered: out std_logic_vector(13 downto 0);
    oeiclk: in std_logic;
    fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
    dout: out std_logic_vector(31 downto 0);
    kout: out std_logic_vector(3 downto 0);
    Rcount_addr: in std_logic_vector(31 downto 0);
    Rcount: out std_logic_vector(63 downto 0)
    
);
end st40_top;

architecture st40_top_arch of st40_top is
 
    type state_type is (rst, scan, dump);
    signal state: state_type;

    signal sela: integer range 0 to 4;
    signal selc: integer range 0 to 7;
    signal sela_rden: integer range 0 to 4;
    signal selc_rden: integer range 0 to 7;
    signal fifo_ae: array_5x8_type;
    signal fifo_rden: array_5x8_type;
    signal fifo_ready: std_logic;
    signal fifo_do: array_5x8x32_type;
    signal fifo_ko: array_5x8x4_type;
    signal trigger_signal: std_logic_vector(39 downto 0);
    signal d, dout_reg: std_logic_vector(31 downto 0);
    signal k, kout_reg: std_logic_vector( 3 downto 0);
    --signal packet_size_counter: integer range 0 to 467;
    signal trigcount: array_5x8x64_type;
    signal packcount: array_5x8x64_type;
    signal sendCount: unsigned(63 downto 0) := (others => '0');
    signal reset_st_counters_fclk0, reset_st_counters_fclk1, reset_st_counters_fclk2, reset_st_counters_fclk_total: std_logic := '0';
    signal reset_st_counters_aclk0, reset_st_counters_aclk1, reset_st_counters_aclk2, reset_st_counters_aclk_total: std_logic := '0';
    signal afe_dat: array_5x9x14_type;
    signal afe_dat_filtered: array_5x9x14_type;

    component stc is
    generic( link_id: std_logic_vector(5 downto 0) := "000000"; ch_id: std_logic_vector(5 downto 0) := "000000" );
    port(
        reset: in std_logic;
        st_config: in std_logic_vector(13 downto 0); -- Config param for Self-Trigger and Local Primitive Calculation, CIEMAT (Nacho)
        signal_delay: in std_logic_vector(4 downto 0);
        adhoc: in std_logic_vector(7 downto 0);
        threshold_xc: std_logic_vector(41 downto 0);
        slot_id: std_logic_vector(3 downto 0);
        crate_id: std_logic_vector(9 downto 0);
        detector_id: std_logic_vector(5 downto 0);
        version_id: std_logic_vector(5 downto 0);
        enable: std_logic;
        afe_comp_enable: in std_logic;
        invert_enable: in std_logic;
        trigger_signal: out std_logic;
        filter_output_selector: in std_logic_vector(1 downto 0);
        aclk: in std_logic; -- AFE clock 62.500 MHz
        timestamp: in std_logic_vector(63 downto 0);
    	ti_trigger: in std_logic_vector(7 downto 0); -------------------------
        ti_trigger_stbr: in std_logic;  -------------------------
        reset_st_counters: in std_logic;
        afe_dat: in std_logic_vector(13 downto 0);
        st_afe_dat_filtered: out std_logic_vector(13 downto 0);
        fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
        fifo_rden: in std_logic;
        fifo_ae: out std_logic;
        fifo_do: out std_logic_vector(31 downto 0);
        fifo_ko: out std_logic_vector( 3 downto 0);
        Tcount: out std_logic_vector(63 downto 0);
        Pcount: out std_logic_vector(63 downto 0)
      );
    end component;

begin

    -- make 40 STC machines to monitor 40 AFE channels
    afe_dat(0)(0) <= afe_dat_0_0;
    afe_dat(0)(1) <= afe_dat_0_1;
    afe_dat(0)(2) <= afe_dat_0_2;
    afe_dat(0)(3) <= afe_dat_0_3;
    afe_dat(0)(4) <= afe_dat_0_4;
    afe_dat(0)(5) <= afe_dat_0_5;
    afe_dat(0)(6) <= afe_dat_0_6;
    afe_dat(0)(7) <= afe_dat_0_7;
    afe_dat(0)(8) <= afe_dat_0_8;

    afe_dat(1)(0) <= afe_dat_1_0;
    afe_dat(1)(1) <= afe_dat_1_1;
    afe_dat(1)(2) <= afe_dat_1_2;
    afe_dat(1)(3) <= afe_dat_1_3;
    afe_dat(1)(4) <= afe_dat_1_4;
    afe_dat(1)(5) <= afe_dat_1_5;
    afe_dat(1)(6) <= afe_dat_1_6;
    afe_dat(1)(7) <= afe_dat_1_7;
    afe_dat(1)(8) <= afe_dat_1_8;

    afe_dat(2)(0) <= afe_dat_2_0;
    afe_dat(2)(1) <= afe_dat_2_1;
    afe_dat(2)(2) <= afe_dat_2_2;
    afe_dat(2)(3) <= afe_dat_2_3;
    afe_dat(2)(4) <= afe_dat_2_4;
    afe_dat(2)(5) <= afe_dat_2_5;
    afe_dat(2)(6) <= afe_dat_2_6;
    afe_dat(2)(7) <= afe_dat_2_7;
    afe_dat(2)(8) <= afe_dat_2_8;

    afe_dat(3)(0) <= afe_dat_3_0;
    afe_dat(3)(1) <= afe_dat_3_1;
    afe_dat(3)(2) <= afe_dat_3_2;
    afe_dat(3)(3) <= afe_dat_3_3;
    afe_dat(3)(4) <= afe_dat_3_4;
    afe_dat(3)(5) <= afe_dat_3_5;
    afe_dat(3)(6) <= afe_dat_3_6;
    afe_dat(3)(7) <= afe_dat_3_7;
    afe_dat(3)(8) <= afe_dat_3_8;

    afe_dat(4)(0) <= afe_dat_4_0;
    afe_dat(4)(1) <= afe_dat_4_1;
    afe_dat(4)(2) <= afe_dat_4_2;
    afe_dat(4)(3) <= afe_dat_4_3;
    afe_dat(4)(4) <= afe_dat_4_4;
    afe_dat(4)(5) <= afe_dat_4_5;
    afe_dat(4)(6) <= afe_dat_4_6;
    afe_dat(4)(7) <= afe_dat_4_7;
    afe_dat(4)(8) <= afe_dat_4_8;

    afe_dat_0_0_filtered <= afe_dat_filtered(0)(0);
    afe_dat_0_1_filtered <= afe_dat_filtered(0)(1);
    afe_dat_0_2_filtered <= afe_dat_filtered(0)(2);
    afe_dat_0_3_filtered <= afe_dat_filtered(0)(3);
    afe_dat_0_4_filtered <= afe_dat_filtered(0)(4);
    afe_dat_0_5_filtered <= afe_dat_filtered(0)(5);
    afe_dat_0_6_filtered <= afe_dat_filtered(0)(6);
    afe_dat_0_7_filtered <= afe_dat_filtered(0)(7);
    afe_dat_0_8_filtered <= afe_dat_filtered(0)(8);

    afe_dat_1_0_filtered <= afe_dat_filtered(1)(0);
    afe_dat_1_1_filtered <= afe_dat_filtered(1)(1);
    afe_dat_1_2_filtered <= afe_dat_filtered(1)(2);
    afe_dat_1_3_filtered <= afe_dat_filtered(1)(3);
    afe_dat_1_4_filtered <= afe_dat_filtered(1)(4);
    afe_dat_1_5_filtered <= afe_dat_filtered(1)(5);
    afe_dat_1_6_filtered <= afe_dat_filtered(1)(6);
    afe_dat_1_7_filtered <= afe_dat_filtered(1)(7);
    afe_dat_1_8_filtered <= afe_dat_filtered(1)(8);

    afe_dat_2_0_filtered <= afe_dat_filtered(2)(0);
    afe_dat_2_1_filtered <= afe_dat_filtered(2)(1);
    afe_dat_2_2_filtered <= afe_dat_filtered(2)(2);
    afe_dat_2_3_filtered <= afe_dat_filtered(2)(3);
    afe_dat_2_4_filtered <= afe_dat_filtered(2)(4);
    afe_dat_2_5_filtered <= afe_dat_filtered(2)(5);
    afe_dat_2_6_filtered <= afe_dat_filtered(2)(6);
    afe_dat_2_7_filtered <= afe_dat_filtered(2)(7);
    afe_dat_2_8_filtered <= afe_dat_filtered(2)(8);

    afe_dat_3_0_filtered <= afe_dat_filtered(3)(0);
    afe_dat_3_1_filtered <= afe_dat_filtered(3)(1);
    afe_dat_3_2_filtered <= afe_dat_filtered(3)(2);
    afe_dat_3_3_filtered <= afe_dat_filtered(3)(3);
    afe_dat_3_4_filtered <= afe_dat_filtered(3)(4);
    afe_dat_3_5_filtered <= afe_dat_filtered(3)(5);
    afe_dat_3_6_filtered <= afe_dat_filtered(3)(6);
    afe_dat_3_7_filtered <= afe_dat_filtered(3)(7);
    afe_dat_3_8_filtered <= afe_dat_filtered(3)(8);

    afe_dat_4_0_filtered <= afe_dat_filtered(4)(0);
    afe_dat_4_1_filtered <= afe_dat_filtered(4)(1);
    afe_dat_4_2_filtered <= afe_dat_filtered(4)(2);
    afe_dat_4_3_filtered <= afe_dat_filtered(4)(3);
    afe_dat_4_4_filtered <= afe_dat_filtered(4)(4);
    afe_dat_4_5_filtered <= afe_dat_filtered(4)(5);
    afe_dat_4_6_filtered <= afe_dat_filtered(4)(6);
    afe_dat_4_7_filtered <= afe_dat_filtered(4)(7);
    afe_dat_4_8_filtered <= afe_dat_filtered(4)(8);

    gen_stc_a: for a in 4 downto 0 generate
        gen_stc_c: for c in 7 downto 0 generate

            stc_inst: stc 
            generic map( link_id => link_id, ch_id => std_logic_vector(to_unsigned(10*a+c,6)) ) 
            port map(
                reset => reset_aclk,
                adhoc => adhoc,
                threshold_xc => threshold_xc,
                ti_trigger => ti_trigger, -------------------------
                ti_trigger_stbr => ti_trigger_stbr,  -------------------------
                reset_st_counters => reset_st_counters_aclk_total,
                slot_id => slot_id,
                crate_id => crate_id,
                detector_id => detector_id,
                version_id => version_id,
                enable => enable(8*a+c),
                afe_comp_enable => afe_comp_enable(8*a+c),
                invert_enable => invert_enable(8*a+c),
                trigger_signal => trigger_signal(8*a+c),
                st_config => st_config, -- CIEMAT (Nacho)
                signal_delay => signal_delay,
                filter_output_selector => filter_output_selector,
                aclk => aclk,
                timestamp => timestamp,
            	afe_dat => afe_dat(a)(c),
                st_afe_dat_filtered => afe_dat_filtered(a)(c),
                fclk => fclk,
                fifo_rden => fifo_rden(a)(c),
                fifo_ae => fifo_ae(a)(c),
                fifo_do => fifo_do(a)(c),
                fifo_ko => fifo_ko(a)(c),
                Tcount => trigcount(a)(c),
                Pcount => packcount(a)(c)
              );

    end generate gen_stc_c;
    end generate gen_stc_a;

    gen_afe_signal_a: for a in 4 downto 0 generate
        
        afe_dat_filtered(a)(8) <= afe_dat(a)(8);
    end generate gen_afe_signal_a;

    -- fifo read enable and fifo flag selection

--    fifo_ready <= '1' when (sel_reg="000000" and fifo_ae(0)='1') else 
--                  '1' when (sel_reg="000001" and fifo_ae(1)='1') else 
--                  '1' when (sel_reg="000010" and fifo_ae(2)='1') else 
--                  '1' when (sel_reg="000011" and fifo_ae(3)='1') else 
--                  '1' when (sel_reg="000100" and fifo_ae(4)='1') else 
--                  '1' when (sel_reg="000101" and fifo_ae(5)='1') else 
--                  '1' when (sel_reg="000110" and fifo_ae(6)='1') else 
--                  '1' when (sel_reg="000111" and fifo_ae(7)='1') else 
--                  '1' when (sel_reg="001000" and fifo_ae(8)='1') else 
--                  '1' when (sel_reg="001001" and fifo_ae(9)='1') else 
--                  '0';

    -- sel_reg is a straight 6 bit register, but it is encoded with values 0-7, 10-17, 20-27, 30-37, 40-47
    -- there are gaps, so be careful when incrementing and looping...

    fifo_ready_proc: process(sela, selc, fifo_ae)
    begin
        fifo_ready <= '0'; -- default
        loop_a: for a in 4 downto 0 loop
            loop_c: for c in 7 downto 0 loop
                if (sela=a and selc=c and fifo_ae(a)(c)='1') then
                    fifo_ready <= '1';
                end if;
            end loop loop_c;
        end loop loop_a;
    end process fifo_ready_proc;

    gen_rden_a: for a in 4 downto 0 generate
        gen_rden_c: for c in 7 downto 0 generate
            fifo_rden(a)(c) <= '1' when (sela_rden=a and selc_rden=c and state=dump) else '0';
        end generate gen_rden_c;
    end generate gen_rden_a;

    -- FSM scans all STC machines in round robin manner, looking for a FIFO almost empty "fifo_ae" flag set. when it finds
    -- this, it reads one complete frame from that machine, then sends a few idles, then returns to scanning again.

    sync_st_counters_reset_fclk: process(fclk)
    begin
        if rising_edge(fclk) then
            reset_st_counters_fclk0 <= reset_st_counters;
            reset_st_counters_fclk1 <= reset_st_counters_fclk0;
            reset_st_counters_fclk2 <= reset_st_counters_fclk1;
        end if;
    end process sync_st_counters_reset_fclk;

    reset_st_counters_fclk_total <= reset_st_counters_fclk0 or reset_st_counters_fclk1 or reset_st_counters_fclk2;

    sync_st_counters_reset_aclk: process(aclk)
    begin
        if rising_edge(aclk) then
            reset_st_counters_aclk0 <= reset_st_counters;
            reset_st_counters_aclk1 <= reset_st_counters_aclk0;
            reset_st_counters_aclk2 <= reset_st_counters_aclk1;
        end if;
    end process sync_st_counters_reset_aclk;

    reset_st_counters_aclk_total <= reset_st_counters_aclk0 or reset_st_counters_aclk1 or reset_st_counters_aclk2;

    fsm_proc: process(fclk, reset_fclk, reset_st_counters_fclk_total)
    begin
        if rising_edge(fclk) then
            if (reset_fclk='1' or reset_st_counters_fclk_total ='1') then 
                state <= rst;
                sendCount <= (others => '0');
            else
                case(state) is

                    when rst =>
                        sela <= 0;
                        selc <= 0;
                        state <= scan;

                    when scan => 
                        if (fifo_ready='1') then
                            state <= dump;
                            sela_rden <= sela; 
                            selc_rden <= selc; 
                        else
                            state <= scan;
                        end if;
                        if (selc=7) then
                            if (sela=4) then -- loop around when sel = 4 7
                                sela <= 0;
                                selc <= 0;
                            else
                                sela <= sela + 1;
                                selc <= 0;
                            end if;
                        else
                            selc <= selc + 1;
                        end if;
                        --packet_size_counter <= 0;
                    when dump =>
                        --if ((k="0001" and d(7 downto 0)=X"DC") or packet_size_counter=467) then -- this the EOF word, done reading from this STC
                        if (k="0001" and d(7 downto 0)=X"DC") then -- this the EOF word, done reading from this STC 
                            state <= scan;
                            sendCount <= sendCount + 1;
                        else
                            state <= dump; -- in this state I can continue to search for the next fifo_ready_flag
                            --packet_size_counter <= packet_size_counter + 1;
                            if (fifo_ready='0') then
                                if (selc=7) then
                                    if (sela=4) then -- loop around when sel = 4 7
                                        sela <= 0;
                                        selc <= 0;
                                    else
                                        sela <= sela + 1;
                                        selc <= 0;
                                    end if;
                                else
                                    selc <= selc + 1;
                                end if;   
                            end if;
                        end if;
                    when others => 
                        state <= rst;
                end case;
            end if;
        end if;
    end process fsm_proc;

    -- output muxes
     
--    d <= fifo_do(0) when (sel_reg="000000" and state=dump) else
--         fifo_do(1) when (sel_reg="000001" and state=dump) else
--         fifo_do(2) when (sel_reg="000010" and state=dump) else
--         fifo_do(3) when (sel_reg="000011" and state=dump) else
--         fifo_do(4) when (sel_reg="000100" and state=dump) else
--         fifo_do(5) when (sel_reg="000101" and state=dump) else
--         fifo_do(6) when (sel_reg="000110" and state=dump) else
--         fifo_do(7) when (sel_reg="000111" and state=dump) else
--         fifo_do(8) when (sel_reg="001000" and state=dump) else
--         fifo_do(9) when (sel_reg="001001" and state=dump) else
--         X"000000BC"; -- idle word
--
--    k <= fifo_ko(0) when (sel_reg="000000" and state=dump) else
--         fifo_ko(1) when (sel_reg="000001" and state=dump) else
--         fifo_ko(2) when (sel_reg="000010" and state=dump) else
--         fifo_ko(3) when (sel_reg="000011" and state=dump) else
--         fifo_ko(4) when (sel_reg="000100" and state=dump) else
--         fifo_ko(5) when (sel_reg="000101" and state=dump) else
--         fifo_ko(6) when (sel_reg="000110" and state=dump) else
--         fifo_ko(7) when (sel_reg="000111" and state=dump) else
--         fifo_ko(8) when (sel_reg="001000" and state=dump) else
--         fifo_ko(9) when (sel_reg="001001" and state=dump) else
--         "0001"; -- idle word

    --outmux_proc: process(fifo_do, fifo_ko, sela_rden, selc_rden, state, packet_size_counter)
    outmux_proc: process(fifo_do, fifo_ko, sela_rden, selc_rden, state)
    begin
        d <= X"000000BC"; -- default
        k <= "0001"; -- default
        loop_a: for a in 4 downto 0 loop
        loop_c: for c in 7 downto 0 loop
            if ( sela_rden=a and selc_rden=c and state=dump ) then
                --if (packet_size_counter=467 and fifo_ko(a)(c) /= "0001" and fifo_do(a)(c) /= X"DC") then
                --    d <= X"011223DC";     
                --    k <= "0001";
                --else
                    d <= fifo_do(a)(c);
                    k <= fifo_ko(a)(c);
                --end if;
            end if;
        end loop loop_c;
        end loop loop_a;
    end process outmux_proc;

    -- register the outputs

    outreg_proc: process(fclk)
    begin
        if rising_edge(fclk) then
            dout_reg <= d;
            kout_reg <= k;
        end if;
    end process outreg_proc;

    dout <= dout_reg;
    kout <= kout_reg;
    
    rcount_mux_proc: process(oeiclk)
    begin 
        if rising_edge(oeiclk) then
            case Rcount_addr is
                when X"40800000" =>
                    Rcount <= trigcount(0)(0);
                when X"40800008" =>
                    Rcount <= trigcount(0)(1);
                when X"40800010" =>
                    Rcount <= trigcount(0)(2);
                when X"40800018" =>
                    Rcount <= trigcount(0)(3);
                when X"40800020" =>
                    Rcount <= trigcount(0)(4);
                when X"40800028" =>
                    Rcount <= trigcount(0)(5);
                when X"40800030" =>
                    Rcount <= trigcount(0)(6);
                when X"40800038" =>
                    Rcount <= trigcount(0)(7);
                when X"40800040" =>
                    Rcount <= trigcount(1)(0);
                when X"40800048" =>
                    Rcount <= trigcount(1)(1);
                when X"40800050" =>
                    Rcount <= trigcount(1)(2);
                when X"40800058" =>
                    Rcount <= trigcount(1)(3);
                when X"40800060" =>
                    Rcount <= trigcount(1)(4);
                when X"40800068" =>
                    Rcount <= trigcount(1)(5);
                when X"40800070" =>
                    Rcount <= trigcount(1)(6);
                when X"40800078" =>
                    Rcount <= trigcount(1)(7);
                when X"40800080" =>
                    Rcount <= trigcount(2)(0);
                when X"40800088" =>
                    Rcount <= trigcount(2)(1);
                when X"40800090" =>
                    Rcount <= trigcount(2)(2);
                when X"40800098" =>
                    Rcount <= trigcount(2)(3);
                when X"408000A0" =>
                    Rcount <= trigcount(2)(4);
                when X"408000A8" =>
                    Rcount <= trigcount(2)(5);
                when X"408000B0" =>
                    Rcount <= trigcount(2)(6);
                when X"408000B8" =>
                    Rcount <= trigcount(2)(7);
                when X"408000C0" =>
                    Rcount <= trigcount(3)(0);
                when X"408000C8" =>
                    Rcount <= trigcount(3)(1);
                when X"408000D0" =>
                    Rcount <= trigcount(3)(2);
                when X"408000D8" =>
                    Rcount <= trigcount(3)(3);
                when X"408000E0" =>
                    Rcount <= trigcount(3)(4);
                when X"408000E8" =>
                    Rcount <= trigcount(3)(5);
                when X"408000F0" =>
                    Rcount <= trigcount(3)(6);
                when X"408000F8" =>
                    Rcount <= trigcount(3)(7);
                when X"40800100" =>
                    Rcount <= trigcount(4)(0);
                when X"40800108" =>
                    Rcount <= trigcount(4)(1);
                when X"40800110" =>
                    Rcount <= trigcount(4)(2);
                when X"40800118" =>
                    Rcount <= trigcount(4)(3);
                when X"40800120" =>
                    Rcount <= trigcount(4)(4);
                when X"40800128" =>
                    Rcount <= trigcount(4)(5);
                when X"40800130" =>
                    Rcount <= trigcount(4)(6);
                when X"40800138" =>
                    Rcount <= trigcount(4)(7);
                when X"40800140" =>
                    Rcount <= packcount(0)(0);
                when X"40800148" =>
                    Rcount <= packcount(0)(1);
                when X"40800150" =>
                    Rcount <= packcount(0)(2);
                when X"40800158" =>
                    Rcount <= packcount(0)(3);
                when X"40800160" =>
                    Rcount <= packcount(0)(4);
                when X"40800168" =>
                    Rcount <= packcount(0)(5);
                when X"40800170" =>
                    Rcount <= packcount(0)(6);
                when X"40800178" =>
                    Rcount <= packcount(0)(7);
                when X"40800180" =>
                    Rcount <= packcount(1)(0);
                when X"40800188" =>
                    Rcount <= packcount(1)(1);
                when X"40800190" =>
                    Rcount <= packcount(1)(2);
                when X"40800198" =>
                    Rcount <= packcount(1)(3);
                when X"408001A0" =>
                    Rcount <= packcount(1)(4);
                when X"408001A8" =>
                    Rcount <= packcount(1)(5);
                when X"408001B0" =>
                    Rcount <= packcount(1)(6);
                when X"408001B8" =>
                    Rcount <= packcount(1)(7);
                when X"408001C0" =>
                    Rcount <= packcount(2)(0);
                when X"408001C8" =>
                    Rcount <= packcount(2)(1);
                when X"408001D0" =>
                    Rcount <= packcount(2)(2);
                when X"408001D8" =>
                    Rcount <= packcount(2)(3);
                when X"408001E0" =>
                    Rcount <= packcount(2)(4);
                when X"408001E8" =>
                    Rcount <= packcount(2)(5);
                when X"408001F0" =>
                    Rcount <= packcount(2)(6);
                when X"408001F8" =>
                    Rcount <= packcount(2)(7);
                when X"40800200" =>
                    Rcount <= packcount(3)(0);
                when X"40800208" =>
                    Rcount <= packcount(3)(1);
                when X"40800210" =>
                    Rcount <= packcount(3)(2);
                when X"40800218" =>
                    Rcount <= packcount(3)(3);
                when X"40800220" =>
                    Rcount <= packcount(3)(4);
                when X"40800228" =>
                    Rcount <= packcount(3)(5);
                when X"40800230" =>
                    Rcount <= packcount(3)(6);
                when X"40800238" =>
                    Rcount <= packcount(3)(7);
                when X"40800240" =>
                    Rcount <= packcount(4)(0);
                when X"40800248" =>
                    Rcount <= packcount(4)(1);
                when X"40800250" =>
                    Rcount <= packcount(4)(2);
                when X"40800258" =>
                    Rcount <= packcount(4)(3);
                when X"40800260" =>
                    Rcount <= packcount(4)(4);
                when X"40800268" =>
                    Rcount <= packcount(4)(5);
                when X"40800270" =>
                    Rcount <= packcount(4)(6);
                when X"40800278" =>
                    Rcount <= packcount(4)(7);
                when X"40800280" =>
                    Rcount <= std_logic_vector(sendCount);
                when others => 
                    Rcount <= (others => '1');
            end case;
        end if;
    end process rcount_mux_proc;

    SpyBuffer_proc: process(aclk)
    variable index : integer range 0 to 39;
    begin
        if rising_edge(aclk) then
            if st_40_signals_enable_reg < std_logic_vector(to_unsigned(40, 6)) then
                index := to_integer(unsigned(st_40_signals_enable_reg));
                st_40_selftrigger_4_spybuffer <= trigger_signal(index);
            else
                st_40_selftrigger_4_spybuffer <= '0';
            end if;
        end if;
    end process SpyBuffer_proc;

end st40_top_arch;
