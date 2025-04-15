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

entity st_top is
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
    enable: in std_logic;
    afe_comp_enable: in std_logic;
    invert_enable: in std_logic;
    filter_output_selector: in std_logic_vector(1 downto 0);
    aclk: in std_logic; -- AFE clock 62.500 MHz
    timestamp: in std_logic_vector(63 downto 0);
	afe_dat: in std_logic_vector(13 downto 0);
    afe_dat_filtered: out std_logic_vector(13 downto 0);
    oeiclk: in std_logic;
    fclk: in std_logic; -- transmit clock to FELIX 120.237 MHz 
    dout: out std_logic_vector(31 downto 0);
    kout: out std_logic_vector(3 downto 0);
    Tcount: out std_logic_vector(63 downto 0);
    Pcount: out std_logic_vector(63 downto 0);
    SendCount: out std_logic_vector(63 downto 0)
);
end st_top;

architecture st_top_arch of st_top is
 
    type state_type is (rst, scan, dump);
    signal state: state_type;

    signal fifo_ae: std_logic;
    signal fifo_rden: std_logic;
    signal fifo_ready: std_logic;
    signal fifo_do: std_logic_vector(31 downto 0);
    signal fifo_ko: std_logic_vector(3 downto 0);
    signal trigger_signal: std_logic;
    signal d, dout_reg: std_logic_vector(31 downto 0);
    signal k, kout_reg: std_logic_vector(3 downto 0);
    signal sendCount_internal: unsigned(63 downto 0) := (others => '0');
    signal reset_st_counters_fclk0, reset_st_counters_fclk1, reset_st_counters_fclk2, reset_st_counters_fclk_total: std_logic := '0';
    signal reset_st_counters_aclk0, reset_st_counters_aclk1, reset_st_counters_aclk2, reset_st_counters_aclk_total: std_logic := '0';

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

    stc_inst: stc 
    generic map( link_id => link_id, ch_id => std_logic_vector(to_unsigned(0,6)) ) 
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
        enable => enable,
        afe_comp_enable => afe_comp_enable,
        invert_enable => invert_enable,
        trigger_signal => trigger_signal,
        st_config => st_config,
        signal_delay => signal_delay,
        filter_output_selector => filter_output_selector,
        aclk => aclk,
        timestamp => timestamp,
        afe_dat => afe_dat,
        st_afe_dat_filtered => afe_dat_filtered,
        fclk => fclk,
        fifo_rden => fifo_rden,
        fifo_ae => fifo_ae,
        fifo_do => fifo_do,
        fifo_ko => fifo_ko,
        Tcount => Tcount,
        Pcount => Pcount
        );

    fifo_ready_proc: process(fifo_ae)
    begin
        if (fifo_ae='1') then
            fifo_ready <= '1';
        else
            fifo_ready <= '0';
        end if;
    end process fifo_ready_proc;

    fifo_rden <= '1' when (state=dump) else '0';


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
                sendCount_internal <= (others => '0');
            else
                case(state) is
                    when rst =>
                        state <= scan;
                    when scan => 
                        if (fifo_ready='1') then
                            state <= dump;
                        else
                            state <= scan;
                        end if;
                    when dump =>
                        if (k="0001" and d(7 downto 0)=X"DC") then
                            state <= scan;
                            sendCount_internal <= sendCount_internal + 1;
                        else
                            state <= dump;
                        end if;
                    when others => 
                        state <= rst;
                end case;
            end if;
        end if;
    end process fsm_proc;

    outmux_proc: process(fifo_do, fifo_ko, state)
    begin
        if (state=dump) then
            d <= fifo_do;
            k <= fifo_ko;
        else
            d <= X"000000BC"; -- default
            k <= "0001"; -- default
        end if;
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
    SendCount <= std_logic_vector(sendCount_internal);

end st_top_arch;
