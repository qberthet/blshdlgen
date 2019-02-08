----------------------------------------------------------------------------
-- LSE first Mod f multiplier (fpm_multiplier.vhd)
--
-- The hardware is genenerate for a specific P = 239.
-- And for an especified F
-- use Least Significant Element (LSE) First algorithm
--
-- Constants used:
--   c_P
--   c_M
--   c_F
--   c_FP_ZERO
--   c_FPM_ZERO
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------------------------------------
-- mod f multiplier
------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity fpm_multiplier is
    port(
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fpm_element;
        y:     in  Fpm_element;
        z:     out Fpm_element
    );
end fpm_multiplier;

architecture circuit of fpm_multiplier is

    type polynomial_2K is array(c_M-1 downto 0) of std_logic_vector(2*c_P'length-1 downto 0);

    constant LOGM:       natural := natural(ceil(log2(real(c_M))));

    component fp_subtractor is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
    end component;

    component fp_reducer is
    generic (
        c_LENGTH: natural := c_N
    );
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  std_logic_vector(c_LENGTH-1 downto 0);
        y:     in  Fp_element;
        z:     out Fp_element
    );
    end component;

    signal int_x:            Fpm_element;
    signal int_y:            Fpm_element;
    signal next_x:           Fpm_element;
    signal next_y:           Fpm_element;
    signal c:                Fpm_element;
    signal mult_sub:         Fpm_element;
    signal mult_add:         polynomial_2K;
    signal mult_f_x_x:       polynomial_2K;

    signal load:             std_logic;
    signal update:           std_logic;
    signal reduct_start:     std_logic;
    signal reduct_done:      std_logic;
    signal reduct_done1:     std_logic;
    signal reduct_done1_vec: std_logic_vector(0 to c_M-1);
    signal reduct_done2:     std_logic;
    signal reduct_done2_vec: std_logic_vector(1 to c_M-1);
    signal reduct_done3:     std_logic;
    signal count_equal_zero: std_logic;

    signal sub_start:        std_logic;
    signal sub_done:         std_logic;
    signal sub_done1:        std_logic;
    signal sub_done1_vec:    std_logic_vector(1 to c_M-1);
    signal sub_done2:        std_logic;

    signal count:            std_logic_vector(logM-1 downto 0);

    type states is range 0 to 7;
    signal current_state:    states;

begin

    next_y_calc: for i in 0 to c_M-1 generate
        mult_add(i) <= std_logic_vector( ( unsigned(int_y(0)) * unsigned(int_x(i)) ) + unsigned(c(i)) );

        comp1: fp_reducer
        port map (
            clk   => clk,
            reset => reset,
            start => reduct_start,
            done  => reduct_done1_vec(i),
            x     => mult_add(i),
            y     => c_P,
            z     => next_y(i)
        );
    end generate;

    next_x_calc: for i in 1 to c_M-1 generate
        mult_f_x_x(i) <= std_logic_vector( unsigned(c_F(i)) * unsigned(int_x(c_M-1)));

        comp1: fp_reducer
        port map (
            clk   => clk,
            reset => reset,
            start => reduct_start,
            done  => reduct_done2_vec(i),
            x     => mult_f_x_x(i),
            y     => c_P,
            z     => mult_sub(i)
        );
        comp2: fp_subtractor
        port map (
            clk   => clk,
            reset => reset,
            start => sub_start,
            done  => sub_done1_vec(i),
            x     => int_x(i-1),
            y     => mult_sub(i),
            z     => next_x(i)
        );
    end generate;

    mult_f_x_x(0) <= std_logic_vector( unsigned(c_F(0)) * unsigned(int_x(c_M-1)) );

    comp1: fp_reducer
    port map (
        clk   => clk,
        reset => reset,
        start => reduct_start,
        done  => reduct_done3,
        x     => mult_f_x_x(0),
        y     => c_P,
        z     => mult_sub(0)
    );
    comp2: fp_subtractor
    port map(
        clk   => clk,
        reset => reset,
        start => sub_start,
        done  => sub_done2,
        x     => (others=>'0'),
        y     => mult_sub(0),
        z     => next_x(0)
    );

    registers_abc: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                c     <= c_FPM_ZERO;
                int_y <= y;
                int_x <= x;
            elsif update = '1' then
                c     <= next_y;
                int_y <= c_FP_ZERO & int_y(c_M-1 downto 1);
                int_x <= next_x;
            end if;
        end if;
    end process registers_abc;

    z <= c;

    counter: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                count <= std_logic_vector( to_unsigned(c_M-1, LOGM) );
            elsif update = '1' then
                count <= std_logic_vector( unsigned(count) - 1 );
            end if;
        end if;
    end process counter;

    count_equal_zero <= '1' when count = std_logic_vector( to_unsigned(0, count'length) ) else '0';

    reduct_done1 <= and reduct_done1_vec;
    reduct_done2 <= and reduct_done2_vec;
    reduct_done <= reduct_done1 and reduct_done2 and reduct_done3;

    sub_done1 <= and sub_done1_vec;
    sub_done <= sub_done1 and sub_done2;

    seq_unit: process(all)
    begin
        case current_state is
            when 0 to 1 => load <= '0'; reduct_start <= '0'; sub_start <= '0'; update <= '0'; done <= '1';
            when 2      => load <= '1'; reduct_start <= '0'; sub_start <= '0'; update <= '0'; done <= '0';
            when 3      => load <= '0'; reduct_start <= '1'; sub_start <= '0'; update <= '0'; done <= '0';
            when 4      => load <= '0'; reduct_start <= '0'; sub_start <= '0'; update <= '0'; done <= '0';
            when 5      => load <= '0'; reduct_start <= '0'; sub_start <= '1'; update <= '0'; done <= '0';
            when 6      => load <= '0'; reduct_start <= '0'; sub_start <= '0'; update <= '0'; done <= '0';
            when 7      => load <= '0'; reduct_start <= '0'; sub_start <= '0'; update <= '1'; done <= '0';
        end case;
    end process;

    control_unit: process(clk,reset)
    begin
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
                    current_state <= 3;
                when 3 =>
                    current_state <= 4;
                when 4 =>
                    if reduct_done = '1' then
                        current_state <= 5;
                    end if;
                when 5 =>
                    current_state <= 6;
                when 6 =>
                    if sub_done = '1' then
                        current_state <= 7;
                    end if;
                when 7 =>
                    if count_equal_zero = '1' then
                        current_state <= 0;
                    else
                        current_state <= 3;
                    end if;
            end case;
        end if;
    end process control_unit;

end circuit;
