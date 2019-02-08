--------------------------------------------------------------------------------
-- Montgomery ladder
-- R0 ← 0
-- R1 ← P
-- for i from m downto 0 do
--     if di = 0 then
--         R1 ← point_add(R0, R1)
--         R0 ← point_double(R0)
--     else
--         R0 ← point_add(R0, R1)
--         R1 ← point_double(R1)
-- return R0
--------------------------------------------------------------------------------
-- Constants used:
--   c_P
--   c_FP_ZERO
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity efp_point_multiplier is
    generic (
        N_LENGTH: natural := c_P'length
    );
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        ecP:   in  ec1_point;
        n:     in  std_logic_vector(N_LENGTH-1 downto 0);
        ecR:   out ec1_point;
        done:  out std_logic
    );
end efp_point_multiplier;

architecture rtl of efp_point_multiplier is

    constant LOG_N_LENGTH: natural := natural(ceil(log2(real(N_LENGTH))));

    component efp_point_adder_doubler is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            ecP:   in  ec1_point;
            ecQ:   in  ec1_point;
            ecR:   out ec1_point;
            an_d:  in  std_logic
        );
    end component;

    signal i_reg:        unsigned(LOG_N_LENGTH-1 downto 0);
    signal i_minus_one:  unsigned(LOG_N_LENGTH-1 downto 0);

    signal reg0:         ec1_point;
    signal reg1:         ec1_point;

    signal add_start:    std_logic;
    signal add_done:     std_logic;
    signal add1:         ec1_point;
    signal add2:         ec1_point;
    signal add3:         ec1_point;

    signal double_start: std_logic;
    signal double_done:  std_logic;
    signal double1:      ec1_point;
    signal double3:      ec1_point;

    type states is range 0 to 4;
    signal current_state: states;

begin

    pf_point_adder_i: entity work.efp_point_adder_doubler
    port map (
        clk   => clk,
        reset => reset,
        start => add_start,
        done  => add_done,
        ecP   => reg0,
        ecQ   => reg1,
        ecR   => add3,
        an_d  => '0' -- addition
    );

    pf_point_doubler_i: entity work.efp_point_adder_doubler
    port map (
        clk   => clk,
        reset => reset,
        start => add_start,
        done  => double_done,
        ecP   => double1,
        ecQ   => double1,
        ecR   => double3,
        an_d  => '1' -- doubling
    );

    with n(to_integer(i_reg)) select double1 <= reg0 when '0',
                                                reg1 when others;

    i_minus_one <= i_reg - 1;

    seq_unit: process(all)
    begin
        case current_state is
            when 0 to 1 => add_start <= '0'; double_start <= '0'; done <= '1'; -- Wait start
            when 3      => add_start <= '1'; double_start <= '1'; done <= '0'; -- Step
            when others => add_start <= '0'; double_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= 0;
        elsif rising_edge(clk) then
            case current_state is
                when 0 => -- Wait start low
                    if start = '0' then
                        current_state <= 1;
                    end if;
                when 1 => -- Wait start high
                    if start = '1' then
                        -- FIXME handle case n = 0
                        current_state <= 2;
                        i_reg <= to_unsigned(c_P'length - 1, i_reg'length);
                        reg0 <= EC1_POINT_I;
                        reg1 <= ecP;
                    end if;
                when 2 => -- Find first MSB set in n
                    if i_reg = 0 then
                        current_state <= 3;
                    else
                        if n(to_integer(i_reg)) = '0' then
                            i_reg <= i_minus_one;
                            current_state <= 2;
                        else
                            current_state <= 3;
                        end if;
                    end if;
                when 3 => -- start point addition and doubling
                    current_state <= 4;
                when 4 => -- Wait for results and register them
                    if add_done = '1' and double_done = '1' then
                        -- Register results depending on n(i_reg)
                        -- (Take result of point doubling or point addition)
                        if n(to_integer(i_reg)) = '0' then
                            reg0 <= double3;
                            reg1 <= add3;
                        else
                            reg0 <= add3;
                            reg1 <= double3;
                        end if;
                        -- Check if we need to continue
                        if i_reg = 0 then
                            current_state <= 0; -- No, go to idle
                        else
                            i_reg <= i_minus_one; -- yes, decrement i
                            current_state <= 3;   -- and start again
                        end if;
                    end if;
                when others =>
                    current_state <= 0;
            end case;
        end if;
    end process;

    ecR <= reg0;

end rtl;