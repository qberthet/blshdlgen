----------------------------------------------------------------------------
-- Modified Montgomery Multiplier (Montgomery_multiplier_modif.vhd)
--
-- Constants used:
--   c_P
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

entity fp_montgomery_product is
    port (
        x:     in  Fp_element;
        y:     in  Fp_element;
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        z:     out Fp_element;
        done:  out std_logic
    );
end fp_montgomery_product;

architecture rtl of fp_montgomery_product is

    constant K: natural := c_P'length;

    constant LOGK:      natural := natural(ceil(log2(real(K)))) + 1;

    -- Pre-compute minus_m = 2**(N)-P
    -- (N = P'length)
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

    constant MINUS_P:  std_logic_vector(K downto 0)      := f_minus_p(c_P);

    constant ZERO:     std_logic_vector(LOGK-1 downto 0) := (others => '0');
    constant DELAY:    std_logic_vector(LOGK-1 downto 0) := std_logic_vector(to_unsigned(K/2, LOGK));

    signal p:          std_logic_vector(K downto 0);
    signal pc:         std_logic_vector(K downto 0);
    signal ps:         std_logic_vector(K downto 0);
    signal y_by_xi:    std_logic_vector(K downto 0);
    signal next_pc:    std_logic_vector(K downto 0);
    signal next_ps:    std_logic_vector(K downto 0);
    signal half_ac:    std_logic_vector(K downto 0);
    signal half_as:    std_logic_vector(K downto 0);
    signal half_bc:    std_logic_vector(K downto 0);
    signal half_bs:    std_logic_vector(K downto 0);
    signal p_minus_p:  std_logic_vector(K downto 0);
    signal ac:         std_logic_vector(K+1 downto 0);
    signal as:         std_logic_vector(K+1 downto 0);
    signal bc:         std_logic_vector(K+1 downto 0);
    signal bs:         std_logic_vector(K+1 downto 0);
    signal long_p:     std_logic_vector(K+1 downto 0);
    signal int_x:      std_logic_vector(K-1 downto 0);
    signal xi:         std_logic;
    signal load:       std_logic;
    signal ce_p:       std_logic;
    signal equal_zero: std_logic;
    signal load_timer: std_logic;
    signal time_out:   std_logic;

    type states is range 0 to 4;
    signal current_state: states;

    signal count:       std_logic_vector(LOGK-1 downto 0);
    signal timer_state: std_logic_vector(LOGK-1 downto 0);

begin

    and_gates: for i in 0 to K-1 generate
        y_by_xi(i) <= y(i) and xi;
    end generate;

    y_by_xi(K) <= '0';

    first_csa: for i in 0 to K generate
        as(i) <= pc(i) xor ps(i) xor y_by_xi(i);
        ac(i+1) <= (pc(i) and ps(i)) or (pc(i) and y_by_xi(i)) or (ps(i) and y_by_xi(i));
    end generate;

    ac(0)   <= '0';
    as(K+1) <= '0';
    long_p  <= "00" & c_P;

    second_csa: for i in 0 to K generate
        bs(i) <= ac(i) xor as(i) xor long_p(i);
        bc(i+1) <= (ac(i) and as(i)) or (ac(i) and long_p(i)) or (as(i) and long_p(i));
    end generate;

    bc(0) <= '0';
    bs(K+1) <= ac(K+1);
    half_as <= as(K+1 downto 1);
    half_ac <= ac(K+1 downto 1);
    half_bs <= bs(K+1 downto 1);
    half_bc <= bc(K+1 downto 1);

    with as(0) select next_pc <= half_ac when '0',
                                 half_bc when others;

    with as(0) select next_ps <= half_as when '0',
                                 half_bs when others;

    parallel_register: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                pc <= (others => '0');
                ps <= (others => '0');
            elsif ce_p = '1' then
                pc <= next_pc;
                ps <= next_ps;
            end if;
        end if;
    end process parallel_register;

    equal_zero <= '1' when count = zero else '0';

    p         <= std_logic_vector(unsigned(ps) + unsigned(pc));
    p_minus_p <= std_logic_vector(unsigned(p)  + unsigned(MINUS_P));

    with p_minus_p(k) select z <= p(k-1 downto 0) when '0',
                          p_minus_p(k-1 downto 0) when others;

    shift_register: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                int_x <= x;
            elsif ce_p = '1' then
                for i in 0 to k-2 loop
                    int_x(i) <= int_x(i+1);
                end loop;
                int_x(K-1) <= '0';
            end if;
        end if;
    end process shift_register;

    xi <= int_x(0);

    counter: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                count <= std_logic_vector(to_unsigned(K-1, LOGK));
            elsif ce_p= '1' then
                count <= std_logic_vector(unsigned(count) - 1);
            end if;
        end if;
    end process;

    control_unit: process(clk, reset, current_state)
    begin
        case current_state is
            when 0 to 1 => ce_p <= '0'; load <= '0'; load_timer <= '1'; done <= '1';
            when 2      => ce_p <= '0'; load <= '1'; load_timer <= '1'; done <= '0';
            when 3      => ce_p <= '1'; load <= '0'; load_timer <= '1'; done <= '0';
            when 4      => ce_p <= '0'; load <= '0'; load_timer <= '0'; done <= '0';
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
                    if equal_zero = '1' then
                        current_state <= 4;
                    end if;
                when 4 =>
                    if time_out = '1' then
                        current_state <= 0;
                    end if;
            end case;
        end if;
    end process;

    timer:process(clk)
    begin
        if rising_edge(clk) then
            if load_timer = '1' then
                timer_state <= delay;
            else
                timer_state <= std_logic_vector(unsigned(timer_state) - 1);
            end if;
        end if;
    end process timer;

    time_out <= '1' when timer_state = zero else '0';

end rtl;
