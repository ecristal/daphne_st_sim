-- st_xc.vhd
-- self trigger using matching filter for single-double-triple PE detection
--
-- This module implements a cross correlation matching filter that uses the 
-- data coming from one channel in order to generate a self trigger signal output
-- whenever simple events occur. This matching filter is capable of detecting
-- Single PhotonElectrons, Double PhotonElectrons, Triple PhotonElectrons 
--
-- Daniel Avila Gomez <daniel.avila@eia.edu.co> & Edgar Rincon Gil <edgar.rincon.g@gmail.com>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_signed.all;

library unisim;
use unisim.vcomponents.all;

entity st_xc is
port(
    reset: in std_logic;
    clock: in std_logic; -- AFE clock 62.500 MHz
    enable: in std_logic;
    din: in std_logic_vector(13 downto 0); -- filtered AFE data (no baseline)
    threshold: in std_logic_vector(41 downto 0); -- matching filter trigger threshold values
    triggered: out std_logic;
    xcorr_calc: out std_logic_vector(27 downto 0)
);
end st_xc;

architecture st_xc_arch of st_xc is

    -- self trigger input data and finite state machine signals 
    signal din_xcorr: std_logic_vector(13 downto 0) := (others => '0');
    
    -- finite state machine states
    type state_type is (reset_st, stand_by, self_triggered); 
    signal current_state, next_state : state_type;
    
    -- cross correlator inner signals
    type type_r_st_xc_dat is array (0 to 30) of std_logic_vector(13 downto 0);
    type type_s_r_st_xc_dat is array (0 to 30) of signed(13 downto 0); 
    type type_r_st_xc_mult_dsp is array (0 to 16) of signed(27 downto 0); --31, this initially was 32 registers, complemented by the next signal
    type type_r_st_xc_mult_log is array (0 to 14) of signed(27 downto 0); -- this complements the other signal, until the amount of registers in total is 32
    type type_r_st_xc_add is array (0 to 4) of signed(27 downto 0); 

    signal r_st_xc_dat: type_r_st_xc_dat := (others => (others => '0'));
    signal s_r_st_xc_dat: type_s_r_st_xc_dat := (others => (others => '0'));     
    signal r_st_xc_mult_dsp: type_r_st_xc_mult_dsp := (others => (others => '0')); -- r_st_xc_mult_dsp is new, r_st_xc_mult was the only signal here  
    signal r_st_xc_mult_log: type_r_st_xc_mult_log := (others => (others => '0')); -- r_st_xc_mult_log is new, r_st_xc_mult was the only signal here  
    signal r_st_xc_add: type_r_st_xc_add := (others => (others => '0'));
    constant offset_reg: signed(27 downto 0) := to_signed(integer(-159),28);
    attribute use_dsp : string;
    attribute use_dsp of r_st_xc_mult_dsp : signal is "yes";
    
    -- signals to enable the trigger
    signal trig_en: std_logic := '1'; 
    signal din_reg0, din_reg1, din_reg2: std_logic_vector(13 downto 0) := (others => '0');
    signal s_din, s_din_reg0, s_din_reg1, s_din_reg2: signed(13 downto 0) := (others => '0');
    
    -- final calculation buffer delays
    signal xcorr_o_reg0, xcorr_o_reg1: signed(27 downto 0) := (others => '0');

    -- threshold signals (threshold window)
    signal s_threshold: signed(27 downto 0);
    signal en_threshold: signed(13 downto 0);
    signal trig_ignore_count: std_logic_vector(7 downto 0) := (others => '0');
    signal was_triggered: std_logic := '0';

    -- matching filter template
    type template is array (0 to 31) of signed(13 downto 0);
    constant sig_templ: template := (
        to_signed(integer(1),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(0),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-1),14),
        to_signed(integer(-2),14),
        to_signed(integer(-2),14),
        to_signed(integer(-3),14),
        to_signed(integer(-4),14),
        to_signed(integer(-4),14),
        to_signed(integer(-5),14),
        to_signed(integer(-5),14),
        to_signed(integer(-6),14),
        to_signed(integer(-7),14),
        to_signed(integer(-6),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-7),14),
        to_signed(integer(-6),14),
        to_signed(integer(-5),14),
        to_signed(integer(-4),14),
        to_signed(integer(-3),14),
        to_signed(integer(-2),14),
        to_signed(integer(-1),14),
        to_signed(integer(0),14)
    );

begin

    -- define the configuration of the trigger
-------------------------------------------------------------------------------------------------------------------
    -- trigger threshold to ignore larger events
    en_threshold <= signed(threshold(41 downto 28));

    -- trigger modification to compare the cross correlation output
    s_threshold <= signed(threshold(27 downto 0));
    
    -- disable the trigger feature
-------------------------------------------------------------------------------------------------------------------
    -- generate some delays to see how the signal is behaving 
    din_reg_proc: process(clock, reset, enable, s_din_reg0, s_din_reg1)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                din_reg0 <= (others => '0');
                din_reg1 <= (others => '0');
                din_reg2 <= (others => '0');
            elsif (enable = '1') then
                din_reg0 <= din;
                din_reg1 <= din_reg0;
                din_reg2 <= din_reg1;
            end if;
        end if;
    end process din_reg_proc;

    -- find the signed value of the registers
    s_din      <= signed(din);
    s_din_reg0 <= signed(din_reg0);
    s_din_reg1 <= signed(din_reg1);
    s_din_reg2 <= signed(din_reg2);

    -- compare the registers with the enabling threshold
    -- if the signal is smaller than the threshold, it means there is a big event therefore the trigger should be disabled
    en_trig_proc: process(clock, reset, enable, trig_en, trig_ignore_count, s_din_reg0, s_din_reg1, s_din_reg2, en_threshold)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                trig_en <= '1';
            elsif (enable = '1') then
                -- disable the trigger
                if ( trig_en='1' and ( s_din_reg2>en_threshold and ( s_din_reg1<en_threshold or s_din_reg1=en_threshold ) and s_din_reg0<en_threshold and s_din<en_threshold ) ) then
                    -- three ticks ago we were above the threshold, two ticks we were at the same level or passed below it
                    -- one tick ago we were below it and now we are also below it, we are going down
                    -- therefore we are experiencing a big event
                    trig_en <= '0';
                end if;

                -- re enable the trigger
                if ( trig_en='0' ) then
                    -- since the event is considered as a large event, disable the trigger for a considerable amount of
                    -- clock ticks, in this case, up to the double of the trigger window (1.024us ... 2.048us)
                    if (trig_ignore_count=X"80") then
                        -- re start the countdown and re enable the trigger
                        trig_ignore_count <= (others => '0');
                        trig_en <= '1';
                    else
                        -- keep counting and keep the trigger disabled
                        trig_ignore_count <= std_logic_vector(trig_ignore_count + 1);
                    end if;
                end if;
            end if;
        end if;
    end process en_trig_proc;
    
    -- input data 
-------------------------------------------------------------------------------------------------------------------
    din_xcorr <= din;
    
    -- use "for generates" in order to create a pipeline with a desired amount of registers
    -- fill all of the registers by using 4 clock ticks delays
    st_xc_buff_gen: for i in 0 to 30 generate 
        undersampling_ticks_gen: for j in 13 downto 0 generate
            -- generate 4 ticks in between samples to generate a proper undersampling (4 clock ticks)

            -- first register, which is the original data from the AFEs
            gendelay_reg0: if (i=0) generate
                srl16e_inst_0 : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0001" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '0',
                        a2 => '0',
                        a3 => '0',  
                        d => din_xcorr(j), -- input AFE data bit to the register
                        q => r_st_xc_dat(i)(j) -- delayed output data bit of the signal
                    );
            end generate gendelay_reg0;

            -- next registers, which are "cascaded"
            gendelay_regn: if (i>0) generate
                srl16e_inst_bit : srl16e
                    port map(
                        -- must set input a3a2a1a0 as "0001" so that it has 2 bits of depth (which means 4 clock ticks)
                        clk => clock,
                        ce => '1',
                        a0 => '1',
                        a1 => '0',
                        a2 => '0',
                        a3 => '0',  
                        d => r_st_xc_dat(i-1)(j), -- input data bit to the register
                        q => r_st_xc_dat(i)(j) -- delayed output data bit of the signal
                    );
            end generate gendelay_regn;
        end generate undersampling_ticks_gen;

        -- since the registers are std_logic_vector, we must turn them into signed signals
        s_r_st_xc_dat(i) <= signed(r_st_xc_dat(i));
    end generate st_xc_buff_gen;

    -- multiply the data registers with the template
    st_xc_mult_gen: for i in 0 to 31 generate       
        -- initial multiplication
        st_xc_mult_0: if (i=0) generate
            st_xc_mult_proc: process(clock, reset, enable, din_xcorr)
            begin
                if rising_edge(clock) then
                    if (reset='1') then
                        r_st_xc_mult_dsp(i) <= (others => '0');
                    elsif (enable = '1') then
                        r_st_xc_mult_dsp(i) <= signed(din_xcorr)*sig_templ(i);
                    end if;
                end if;
            end process st_xc_mult_proc;
        end generate st_xc_mult_0;
        
        -- consecutive multiplication with DSPs until the maximum register is reached
        st_xc_mult_n_dsp: if (i>0 and i<17) generate
            st_xc_mult_proc: process(clock, reset, enable, s_r_st_xc_dat)
            begin
                if rising_edge(clock) then
                    if (reset='1') then
                        r_st_xc_mult_dsp(i) <= (others => '0');
                    elsif (enable = '1') then
                        r_st_xc_mult_dsp(i) <= s_r_st_xc_dat(i-1)*sig_templ(i);
                    end if;
                end if;
            end process st_xc_mult_proc;
        end generate st_xc_mult_n_dsp;
        
        -- consecutive multiplication with DSPs until the maximum register is reached
        st_xc_mult_n_log: if (i>16) generate
            st_xc_mult_proc: process(clock, reset, enable, s_r_st_xc_dat)
            begin
                if rising_edge(clock) then
                    if (reset='1') then
                        r_st_xc_mult_log(i-17) <= (others => '0');
                    elsif (enable = '1') then
                        r_st_xc_mult_log(i-17) <= s_r_st_xc_dat(i-1)*sig_templ(i);
                    end if;
                end if;
            end process st_xc_mult_proc;
        end generate st_xc_mult_n_log;
    end generate st_xc_mult_gen;

    -- addition of the multiplications
    add_proc: process(clock, reset, enable, r_st_xc_mult_dsp, r_st_xc_mult_log, r_st_xc_add, xcorr_o_reg0)
    begin
        if rising_edge(clock) then
            if ( ( reset='1' ) ) then 
                r_st_xc_add <= (others => (others => '0'));
                xcorr_o_reg0 <= (others => '0');
                xcorr_o_reg1 <= (others => '0');
            elsif (enable = '1') then
                -- first pipeline stage
                r_st_xc_add(0) <= r_st_xc_mult_dsp(0) + r_st_xc_mult_dsp(1) + r_st_xc_mult_dsp(2) + r_st_xc_mult_dsp(3) +
                                  r_st_xc_mult_dsp(4) + r_st_xc_mult_dsp(5) + r_st_xc_mult_dsp(6) + r_st_xc_mult_dsp(7);
                -- second pipeline stage
                r_st_xc_add(1) <= r_st_xc_mult_dsp(8) + r_st_xc_mult_dsp(9) + r_st_xc_mult_dsp(10) + r_st_xc_mult_dsp(11) +
                                  r_st_xc_mult_dsp(12) + r_st_xc_mult_dsp(13) + r_st_xc_mult_dsp(14) + r_st_xc_mult_dsp(15);
                -- third pipeline stage
                r_st_xc_add(2) <= r_st_xc_mult_dsp(16) + r_st_xc_mult_log(0) + r_st_xc_mult_log(1) + r_st_xc_mult_log(2) + -- started from 16 and so on
                                  r_st_xc_mult_log(3) + r_st_xc_mult_log(4) + r_st_xc_mult_log(5) + r_st_xc_mult_log(6);
                -- fourth pipeline stage
                r_st_xc_add(3) <= r_st_xc_mult_log(7) + r_st_xc_mult_log(8) + r_st_xc_mult_log(9) + r_st_xc_mult_log(10) +
                                  r_st_xc_mult_log(11) + r_st_xc_mult_log(12) + r_st_xc_mult_log(13) + r_st_xc_mult_log(14); -- until 31 was reached

                -- final addition
                r_st_xc_add(4) <= r_st_xc_add(0) + r_st_xc_add(1) + r_st_xc_add(2) + r_st_xc_add(3) + offset_reg;

                -- register the old values to keep track of how the calculation is behaving
                xcorr_o_reg0 <= r_st_xc_add(4); 
                xcorr_o_reg1 <= xcorr_o_reg0;
            end if;
        end if;
    end process add_proc;
    
    -- trigger and peak detector Finite State Machine 
-------------------------------------------------------------------------------------------------------------------
    -- this Finite State Machine uses the cross correlation output to determine when a
    -- self trigger must be asserted. If this condition is met, it then changes the data input
    -- input and starts searching for local peaks. whenever the baseline is recovered, 
    -- it starts again to look for a trigger
    -- State 0: reset
    -- State 1: trigger finder (searchs for a main self trigger signal)
    -- State 2: self triggered (once inside spends 1 clk cycle and informs of the trigger)
    
    -- process to sync change the states of the FSM
    reg_states: process(clock, reset, enable, next_state)
    begin
        if rising_edge(clock) then
            if (reset='1') then
                current_state <= reset_st;
            elsif (enable = '1') then
                current_state <= next_state;
            end if;
        end if;
    end process reg_states;
    
    -- process to define why the states change
    mod_states: process(current_state, r_st_xc_add, xcorr_o_reg0, xcorr_o_reg1, s_threshold, trig_en) 
    begin
        next_state <= current_state; -- Declare default state for current_state to avoid latches, default is to stay in current state
        case (current_state) is
            when reset_st =>
                next_state <= stand_by;
            when stand_by =>
                if ( ( r_st_xc_add(r_st_xc_add'HIGH)>s_threshold ) and ( xcorr_o_reg0>s_threshold ) 
                       and ( xcorr_o_reg1<s_threshold or xcorr_o_reg1=s_threshold ) and ( trig_en='1' )  ) then 
                    next_state <= self_triggered;
                end if;
            when self_triggered =>
                next_state <= stand_by;
            when others =>
                -- do nothing
        end case;
    end process mod_states;
    
    -- finite state machine outputs (conditions to trigger and select the input data)
    do_states: process(current_state)
    begin
        case (current_state) is
            when self_triggered =>
                triggered <= '1';
            when others =>
                -- includes reset_st and stand_by states
                triggered <= '0';
        end case;
    end process; 
    
    xcorr_calc <= std_logic_vector(r_st_xc_add(4)); 

end st_xc_arch;