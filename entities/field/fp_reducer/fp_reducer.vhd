----------------------------------------------------------------------------
-- SRT Reducer (fp_reducer.vhd)
--
-- Computes the remainder (x mod y) using the
-- SRT division algorithm
--
-- Constants used:
--   none
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity fp_reducer is
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
end fp_reducer;

architecture rtl of fp_reducer is

    constant K: natural := y'length;

    -- TODO: if y'length == x'length, this won't work:
    -- implement a function that compute this constante and check for this
    -- condition to add some bits
    constant COUNTER_SIZE: natural := natural(ceil(log2(real(x'length-K-1))));

    signal ss:         std_logic_vector(x'length+1 downto 0);
    signal sc:         std_logic_vector(x'length+1 downto x'length-K);
    signal rs:         std_logic_vector(x'length downto 0);
    signal rc:         std_logic_vector(x'length downto x'length-K+1);
    signal r:          std_logic_vector(K downto 0);
    signal minus_m:    std_logic_vector(K downto 0);
    signal w:          std_logic_vector(K downto 0);
    signal not_m:      Fp_element;
    signal load:       std_logic;
    signal update:     std_logic;
    signal equal_zero: std_logic;
    signal t:          std_logic_vector(2 downto 0);
    signal quotient:   std_logic_vector(1 downto 0);
    signal count:      std_logic_vector(COUNTER_SIZE -1 downto 0);

    type states is range 0 to 3;
    signal current_state: states;

begin

    csa: for i in x'length-K to x'length-1 generate
        rs(i)   <= ss(i) xor sc(i) xor w(i-x'length+K);
        rc(i+1) <= (ss(i) and sc(i)) or (ss(i) and w(i-x'length+K)) or (sc(i) and w(i-x'length+K));
    end generate;

    rs(x'length) <= ss(x'length) xor sc(x'length) xor w(K);
    rs(x'length-K-1 downto 0) <= ss(x'length-K-1 downto 0);

    r(0) <= rs(x'length-K);
    r(K downto 1) <= std_logic_vector( signed(rs(x'length downto x'length-K+1)) + signed(rc(x'length downto x'length-K+1)) );

    with r(K) select z <= r(K-1 downto 0)     when '0',
                          std_logic_vector( signed(r(K-1 downto 0)) + signed(y) ) when others;

    registers: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                ss <= '0' & '0' & x; -- Was originally extended to x(n) for sign extension, but we only use unsigned input
                sc <= (others => '0');
            elsif update = '1' then
                ss(0) <= '0';
                for i in 1 to x'length+1 loop
                    ss(i) <= rs(i-1);
                end loop;
                sc(x'length-k)   <= '0';
                sc(x'length-k+1) <= '0';
                for i in x'length-k+2 to x'length+1 loop
                    sc(i) <= rc(i-1);
                end loop;
            end if;
        end if;
    end process registers;

    counter: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                count <= std_logic_vector( to_signed(x'length-K-1, COUNTER_SIZE));
            elsif update = '1' then
                count <= std_logic_vector(signed(count) - 1);
            end if;
        end if;
    end process counter;

    with count select equal_zero <= '1' when std_logic_vector(to_signed(0,count'length)),
                                    '0' when others;

    t           <= std_logic_vector( signed(ss(x'length+1 downto x'length-1)) + signed(sc(x'length+1 downto x'length-1)));
    quotient(1) <= t(2) xor (t(1) and t(0));
    quotient(0) <= not(t(2) and t(1) and t(0));

    not_gates: for i in 0 to k-1 generate
        not_m(i) <= not(y(i));
    end generate;

    minus_m <= std_logic_vector(signed('1' & not_m) + 1);
    with quotient select w <= minus_m         when "01",
                              ('0' & y)       when "11",
                              (others => '0') when others;

    seq_unit: process(all)
    begin
        case current_state is
            when 0 to 1 => load <= '0'; update <= '0'; done <= '1';
            when 2      => load <= '1'; update <= '0'; done <= '0';
            when 3      => load <= '0'; update <= '1'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
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
                    if equal_zero = '1' then
                        current_state <= 0;
                    end if;
            end case;
        end if;
    end process;

end rtl;
