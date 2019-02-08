----------------------------------------------------------------------------
-- LSB Montgomery Exponentiator (fp_exponentiator.vhd)
--
-- Calculate y**x mod P
-- Least Significant Bit first
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity fp_exponentiator is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element; -- Exponent
        y:     in  Fp_element; -- Number to exponentiate
        z:     out Fp_element  -- Result
    );
end fp_exponentiator;

architecture rtl of fp_exponentiator is

    constant K: natural := c_P'length;

    constant LOGK: natural := natural(ceil(log2(real(K))));

    -- Pre-compute minus_p = 2**K - P
    function f_minus_p (
        module : in std_logic_vector
    )
    return std_logic_vector is
        variable power     : unsigned(module'length downto 0);
        variable result    : unsigned(module'length downto 0);
    begin
        power := (others => '0');
        power(power'left) := '1';
        result := power - unsigned(module);
        return std_logic_vector(result(module'length downto 0));
    end;

    constant minus_p: std_logic_vector(K downto 0) := f_minus_p(c_P);

    -- Pre-compute minus_p = 2**K mod P
    function f_exp_K (
        module : in std_logic_vector
    )
    return std_logic_vector is
        variable power     : unsigned(module'length downto 0);
        variable result    : unsigned(module'length downto 0);
    begin
        power := (others => '0');
        power(K) := '1';
        result := power mod RESIZE(unsigned(module), module'length + 1);
        return std_logic_vector(result(module'range));
    end;

    constant exp_K: Fp_element := f_exp_K(c_P);

    -- Pre-compute minus_p = 2**(2*K) mod P
    function f_exp_2K (
        module : in std_logic_vector
    )
    return std_logic_vector is
        variable power     : unsigned( 2 * module'length downto 0);
        variable result    : unsigned( 2 * module'length downto 0);
    begin
        power := (others => '0');
        power(2*K) := '1';
        result := power mod RESIZE(unsigned(module), 2 * module'length + 1);
        return std_logic_vector(result(module'range));
    end;

    constant exp_2K: Fp_element := f_exp_2K(c_P);

    signal second:     Fp_element;
    signal operand1:   Fp_element;
    signal operand2:   Fp_element;
    signal next_e:     Fp_element;
    signal next_y:     Fp_element;
    signal e:          Fp_element;
    signal ty:         Fp_element;
    signal int_x:      Fp_element;
    signal start_pp1:  std_logic;
    signal start_pp2:  std_logic;
    signal pp1_done:   std_logic;
    signal pp2_done:   std_logic;
    signal pp_done:    std_logic;
    signal ce_e:       std_logic;
    signal ce_ty:      std_logic;
    signal load:       std_logic;
    signal update:     std_logic;
    signal xi:         std_logic;
    signal equal_zero: std_logic;
    signal first:      std_logic;
    signal last:       std_logic;

    type states is range 0 to 15;
    signal current_state: states;

    signal count: std_logic_vector(LOGK-1 downto 0);

    component montgomery_product is
        port (
            x:     in  std_logic_vector;
            y:     in  std_logic_vector;
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            z:     out std_logic_vector;
            done:  out std_logic
        );
    end component;

begin

    with last  select second   <= ty     when '0', c_FP_ONE when others;
    with first select operand1 <= y      when '1', ty       when others;
    with first select operand2 <= exp_2k when '1', ty       when others;

    montgomery_product1_i: entity work.fp_montgomery_product
    port map(
        x     => e,
        y     => second,
        clk   => clk,
        reset => reset,
        start => start_pp1,
        z     => next_e,
        done  => pp1_done
    );

    montgomery_product2_i: entity work.fp_montgomery_product
    port map(
        x     => operand1,
        y     => operand2,
        clk   => clk,
        reset => reset,
        start => start_pp2,
        z     => next_y,
        done  => pp2_done
    );

    pp_done <= pp1_done and pp2_done;
    z       <= next_e;

    register_e: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                e <= exp_k;
            elsif ce_e = '1' then
                e <= next_e;
            end if;
        end if;
    end process register_e;

    register_ty: process(clk)
    begin
        if rising_edge(clk) then
            if ce_ty = '1' then
                ty <= next_y;
            end if;
        end if;
    end process register_ty;

    shift_register: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                int_x <= x;
            elsif update = '1' then
                int_x <= '0'&int_x(K-1 downto 1);
            end if;
        end if;
    end process shift_register;

    xi <= int_x(0);

    counter: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                count <= std_logic_vector(to_unsigned(K, LOGK));
            elsif update= '1' then
                count <= std_logic_vector(unsigned(count) - 1);
            end if;
        end if;
    end process;

    equal_zero <= '1' when unsigned(count) = 0 else '0';

    control_unit: process(clk, reset, current_state)
    begin
        case current_state is
            when 0 to 1 => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '1';
            when 2      => ce_e <= '0'; ce_ty <= '0'; load <= '1'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0'; -- '1' ?
            when 3      => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '1'; first <= '1'; last <= '0'; done <= '0';
            when 4      => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '1'; last <= '0'; done <= '0';
            when 5      => ce_e <= '0'; ce_ty <= '1'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '1'; last <= '0'; done <= '0';
            when 6      => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '1'; first <= '0'; last <= '0'; done <= '0';
            when 7      => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 8      => ce_e <= '0'; ce_ty <= '1'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 9      => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '1'; start_pp2 <= '1'; first <= '0'; last <= '0'; done <= '0';
            when 10     => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 11     => ce_e <= '1'; ce_ty <= '1'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 12     => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '1'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 13     => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '0'; done <= '0';
            when 14     => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '1'; start_pp2 <= '0'; first <= '0'; last <= '1'; done <= '0';
            when 15     => ce_e <= '0'; ce_ty <= '0'; load <= '0'; update <= '0'; start_pp1 <= '0'; start_pp2 <= '0'; first <= '0'; last <= '1'; done <= '0';
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
                current_state <= 3;
            when 3 =>
                current_state <= 4;
            when 4 =>
                if pp2_done= '1' then
                    current_state <= 5;
                end if;
            when 5 =>
                if xi = '0' then
                    current_state <= 6;
                else
                    current_state <= 9;
                end if;
            when 6 =>
                current_state <= 7;
            when 7 =>
                if pp2_done = '1' then
                    current_state <= 8;
                end if;
            when 8 =>
                current_state <= 12;
            when 9 =>
                current_state <= 10;
            when 10 =>
                if pp_done= '1' then
                    current_state <= 11;
                end if;
            when 11 =>
                current_state <= 12;
            when 12 =>
                current_state <= 13;
            when 13 =>
                if equal_zero = '1' then
                    current_state <= 14;
                elsif xi = '0' then
                    current_state <= 6;
                else
                    current_state <= 9;
                end if;
            when 14 =>
                current_state <= 15;
            when 15 =>
                if pp_done= '1' then
                    current_state <= 0;
                end if;
        end case;

    end if;

  end process;

end rtl;
