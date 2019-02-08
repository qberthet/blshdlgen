----------------------------------------------------------------------------
-- Binary (square and multiply) exponentiation (fpm_exponentiator.vhd)
--
-- LSB first
--
-- Computes the x^e mod f in GF(2**m)
-- Implements a sequential cincuit instantiang a multiplier and a squarer (combinational)
--
-- Constants used:
--   c_P
--   c_M
--   c_F
--   c_FP_ZERO
--   c_FPM_ZERO
--   c_FPM_ONE
--
----------------------------------------------------------------------------

-----------------------------------
-- Bynary exponentiation for GF(P^M)
-----------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity fpm_exponentiator is
    generic (
        c_LENGTH: natural := c_N
    );
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fpm_element;
        y:     in  std_logic_vector(c_LENGTH-1 downto 0);
        z:     out Fpm_element
    );
end fpm_exponentiator;

architecture rtl of fpm_exponentiator is

    constant LOGN:       natural := natural(ceil(log2(real(y'length))));

    component fpm_multiplier is
        port(
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  Fpm_element;
            y:     in  Fpm_element;
            z:     out Fpm_element
        );
    end component;

    signal inic:       std_logic;
    signal shift_r:    std_logic;
    signal ce_c:       std_logic;
    --signal count:      natural range 0 to N;
    signal count:      std_logic_vector(LOGN-1 downto 0);
    signal cc:         Fpm_element;
    signal bb:         Fpm_element;
    signal new_b:      Fpm_element;
    signal new_c:      Fpm_element;
    signal ee:         std_logic_vector (y'range);
    signal start_mult: std_logic;
    signal start_sq:   std_logic;
    signal done_mult:  std_logic;
    signal done_sq:    std_logic;

    type states is range 0 to 5;
    signal current_state: states;

begin

    inst_mult: fpm_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => start_mult,
        done  => done_mult,
        z     => new_B,
        x     => cc,
        y     => bb
    );

    inst_square: fpm_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => start_sq,
        done  => done_sq,
        x     => cc,
        y     => cc,
        z     => new_c
    );

    counter: process(reset, clk)
    begin
        if reset = '1' then
            count <= (others => '0');
        elsif rising_edge(clk) then
            if inic = '1' then
                count <= (others=>'0');
            elsif shift_r = '1' then
                count <= std_logic_vector( unsigned(count) + 1);
            end if;
        end if;
    end process counter;

    sh_reg_e: process(reset, clk)
    begin
        if reset = '1' then
            ee <= (others => '0');
        elsif rising_edge(clk) then
            if inic = '1' then
                ee <= y;
            elsif shift_r = '1' then
                ee <= '0' & ee(y'length-1 downto 1);
            end if;
        end if;
    end process sh_reg_e;

    register_c: process(reset, clk)
    begin
        if reset = '1' then
            cc <= c_FPM_ZERO;
        elsif rising_edge(clk) then
            if inic = '1' then
                cc <= x;
            elsif shift_r = '1' then
                cc <= new_c;
            end if;
        end if;
    end process register_c;

    register_b: process(reset, clk)
    begin
        if reset = '1' then
            bb <= c_FPM_ZERO ;
        elsif rising_edge(clk) then
            if inic = '1' then
                bb <= c_FPM_ONE;
            elsif shift_r = '1' and ee(0) = '1' then
                bb <= new_b;
            end if;
        end if;
    end process register_b;

    z <= bb;

    control_unit: process(clk, reset, current_state, ee(0))
    begin
        case current_state is
            when 0 to 1 => inic <= '0'; shift_r <= '0'; done <= '1'; ce_c <= '0'; start_sq <= '0'; start_mult <= '0';
            when 2      => inic <= '1'; shift_r <= '0'; done <= '0'; ce_c <= '0'; start_sq <= '0'; start_mult <= '0';
            when 3      => inic <= '0'; shift_r <= '0'; done <= '0'; ce_c <= '1'; start_sq <= '1'; start_mult <= ee(0);
            when 4      => inic <= '0'; shift_r <= '0'; done <= '0'; ce_c <= '1'; start_sq <= '0'; start_mult <= '0';
            when 5      => inic <= '0'; shift_r <= '1'; done <= '0'; ce_c <= '1'; start_sq <= '0'; start_mult <= '0';
        end case;

        if reset = '1' then
            current_state <= 0;
        elsif rising_edge(clk) then
            case current_state is
                when 0 =>
                    if start = '0' then
                        current_state <= 1;
                    end if;
                when 1 =>
                    if start = '1' then
                        current_state <= 2;
                    end if;
                when 2 =>
                    current_state <= 3; --capture operands
                when 3 =>
                    current_state <= 4; --start operations
                when 4 =>
                    if (done_sq = '1' and (ee(0) = '0' or done_mult = '1')) then
                        current_state <= 5;
                    end if;
                when 5 =>
                    if count = std_logic_vector(to_unsigned(y'length-1, count'length)) then
                        current_state <= 0;
                    else
                        current_state <= 3;
                    end if;
            end case;
        end if;
    end process control_unit;

end rtl;
