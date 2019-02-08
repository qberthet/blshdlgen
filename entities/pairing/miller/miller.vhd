--------------------------------------------------------------------------------
-- Constants used:
--   c_FPM_ONE
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity miller is
    generic (
        N_LENGTH: natural := c_P'length
    );
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        ecP:   in  ec2_point;
        ecQ:   in  ec2_point;
        n:     in  std_logic_vector(N_LENGTH-1 downto 0);
        t:     out Fpm_element;
        done:  out std_logic
    );
end miller;

architecture rtl of miller is

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

    component fpm_divider is
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

    component efpm_point_inverter is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            ecP:   in  ec2_point;
            ecR:   out ec2_point
        );
    end component;

    component efpm_point_adder_doubler is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            ecP:   in  ec2_point;
            ecQ:   in  ec2_point;
            ecR:   out ec2_point;
            an_d:  in  std_logic
        );
    end component;

    component miller_line is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            ecP:   in  ec2_point;
            ecR:   in  ec2_point;
            ecQ:   in  ec2_point;
            l:     out Fpm_element
        );
    end component;

    signal mul_start:        std_logic;
    signal mul_done:         std_logic;
    signal mul_x:            Fpm_element;
    signal mul_y:            Fpm_element;
    signal mul_z:            Fpm_element;

    signal div_start:        std_logic;
    signal div_done:         std_logic;
    signal div_z:            Fpm_element;

    signal inv_start:        std_logic;
    signal inv_done:         std_logic;
    signal inv_R:            ec2_point;

    signal add_double_start: std_logic;
    signal add_double_done:  std_logic;
    signal an_d:             std_logic;
    signal add_double_P:     ec2_point;
    signal add_double_Q:     ec2_point;
    signal add_double_R:     ec2_point;

    signal line_start:       std_logic;
    signal line_done:        std_logic;
    signal line_P:           ec2_point;
    signal line_R:           ec2_point;
    signal line_Q:           ec2_point;
    signal line_l:           Fpm_element;

    signal t_reg:            Fpm_element;
    signal ell_reg:          Fpm_element;
    signal V_reg:            ec2_point;
    signal nbin_reg:         std_logic_vector(n'range);

    constant LOG_N_LENGTH:   natural := natural(ceil(log2(real(N_LENGTH))));
    signal i_reg:            signed(LOG_N_LENGTH downto 0);
    signal i_minus_one:      signed(LOG_N_LENGTH downto 0);

    type states is (
        S_FINISH,
        S_IDLE,
        S_LOAD,
        S_TEST_LOOP,
        S_DOUBLE_START,
        S_DOUBLE_WAIT,
        S_LINE1_START,
        S_LINE1_WAIT,
        S_LINE2_START,
        S_LINE2_WAIT,
        S_DIV1_START,
        S_DIV1_WAIT,
        S_MUL1_START,
        S_MUL1_WAIT,
        S_TEST_BIT,
        S_ADD_START,
        S_ADD_WAIT,
        S_LINE3_START,
        S_LINE3_WAIT,
        S_LINE4_START,
        S_LINE4_WAIT,
        S_DIV2_START,
        S_DIV2_WAIT,
        S_MUL2_START,
        S_MUL2_WAIT,
        S_UPDATE
    );
    signal current_state: states;

begin

    fpm_multiplier_i: entity work.fpm_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => mul_start,
        done  => mul_done,
        x     => mul_x,
        y     => mul_y,
        z     => mul_z
    );

    fpm_multiplier_routing: process(all)
    begin
        case current_state is
            when S_LINE1_START to S_LINE1_WAIT => mul_x <= t_reg; mul_y <= t_reg;
            when S_MUL1_START  to S_MUL1_WAIT  => mul_x <= mul_z; mul_y <= div_z;
            when S_MUL2_START  to S_MUL2_WAIT  => mul_x <= t_reg; mul_y <= div_z;
            when others                        => mul_x <= t_reg; mul_y <= t_reg;
        end case;
    end process fpm_multiplier_routing;

    ----------------------------------------------------------------------------

    fpm_divider_i: entity work.fpm_divider
    port map (
        clk   => clk,
        reset => reset,
        start => div_start,
        done  => div_done,
        x     => ell_reg,
        y     => line_l,
        z     => div_z
    );

    ----------------------------------------------------------------------------

    efpm_point_inverter_i: entity work.efpm_point_inverter
    port map (
        clk   => clk,
        reset => reset,
        start => inv_start,
        done  => inv_done,
        ecP   => add_double_R,
        ecR   => inv_R
    );
    ----------------------------------------------------------------------------

    efpm_point_adder_doubler_i: entity work.efpm_point_adder_doubler
    port map (
        clk   => clk,
        reset => reset,
        start => add_double_start,
        done  => add_double_done,
        ecP   => add_double_P,
        ecQ   => add_double_Q,
        ecR   => add_double_R,
        an_d  => an_d
    );

    add_double_P <= V_reg;

    point_adder_doubler_routing: process(all)
    begin
        case current_state is
            when S_DOUBLE_START to S_DOUBLE_WAIT => add_double_Q <= V_reg;
            when S_ADD_START    to S_ADD_WAIT    => add_double_Q <= ecP;
            when others                          => add_double_Q <= V_reg;
        end case;
    end process point_adder_doubler_routing;

    ----------------------------------------------------------------------------

    miller_line_i: entity work.miller_line
    port map (
        clk   => clk,
        reset => reset,
        start => line_start,
        done  => line_done,
        ecP   => line_P,
        ecR   => line_R,
        ecQ   => line_Q,
        l     => line_l
    );

    line_Q <= ecQ;

    miller_line_routing: process(all)
    begin
        case current_state is
            when S_LINE1_START to S_LINE1_WAIT => line_P <= V_reg;        line_R <= V_reg;
            when S_LINE2_START to S_LINE2_WAIT => line_P <= add_double_R; line_R <= inv_R;
            when S_LINE3_START to S_LINE3_WAIT => line_P <= V_reg;        line_R <= ecP;
            when S_LINE4_START to S_LINE4_WAIT => line_P <= add_double_R; line_R <= inv_R;
            when others                        => line_P <= add_double_R; line_R <= inv_R;
        end case;
    end process miller_line_routing;

    ----------------------------------------------------------------------------

    i_minus_one <= i_reg - 1;

    seq_unit: process(all)
    begin
        case current_state is
            when S_FINISH to S_IDLE  => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '1'; -- Wait start
            when S_DOUBLE_START      => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '1'; an_d <= '1'; line_start <= '0'; done <= '0';
            when S_DOUBLE_WAIT       => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '1'; line_start <= '0'; done <= '0';
            when S_LINE1_START       => mul_start <= '1'; div_start <= '0'; inv_start <= '1'; add_double_start <= '0'; an_d <= '0'; line_start <= '1'; done <= '0';
            when S_LINE2_START       => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '1'; done <= '0';
            when S_DIV1_START        => mul_start <= '0'; div_start <= '1'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '0';
            when S_MUL1_START        => mul_start <= '1'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '0';
            when S_ADD_START         => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '1'; an_d <= '0'; line_start <= '0'; done <= '0';
            when S_LINE3_START       => mul_start <= '0'; div_start <= '0'; inv_start <= '1'; add_double_start <= '0'; an_d <= '0'; line_start <= '1'; done <= '0';
            when S_LINE4_START       => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '1'; done <= '0';
            when S_DIV2_START        => mul_start <= '0'; div_start <= '1'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '0';
            when S_MUL2_START        => mul_start <= '1'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '0';
            when others              => mul_start <= '0'; div_start <= '0'; inv_start <= '0'; add_double_start <= '0'; an_d <= '0'; line_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= S_FINISH;
            t_reg         <= c_FPM_ONE;
            V_reg         <= EC2_POINT_I;
            nbin_reg      <= (others=>'0');
            i_reg         <= (others=>'0');
        elsif rising_edge(clk) then
            case current_state is

                when S_FINISH => -- Wait start low
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                when S_IDLE => -- Wait start high
                    if start = '1' then
                        current_state <= S_LOAD;
                        t_reg    <= c_FPM_ONE;
                        V_reg    <= ecP;
                        nbin_reg <= n;
                        i_reg    <= to_signed(n'length - 1, i_reg'length);
                    end if;

                when S_LOAD => -- Find first MSB set in n
                    if i_reg = 0 then
                        current_state <= S_LOAD;
                    else
                        i_reg <= i_minus_one;
                        if nbin_reg(to_integer(i_reg)) = '0' then
                            current_state <= S_LOAD;
                        else
                            current_state <= S_TEST_LOOP;
                        end if;
                    end if;

                when S_TEST_LOOP =>
                    if i_reg > to_signed(-1, natural(i_reg'length)) then
                        current_state <= S_DOUBLE_START;
                    else
                        current_state <= S_FINISH;
                    end if;

                when S_DOUBLE_START =>
                    current_state <= S_DOUBLE_WAIT;

                when S_DOUBLE_WAIT =>
                    if add_double_done = '1' then
                        current_state <= S_LINE1_START;
                    end if;

                when S_LINE1_START =>
                    current_state <= S_LINE1_WAIT;

                when S_LINE1_WAIT =>
                    if mul_done = '1' and inv_done = '1' and line_done = '1' then
                        current_state <= S_LINE2_START;
                        ell_reg <= line_l;
                    end if;

                when S_LINE2_START =>
                    current_state <= S_LINE2_WAIT;

                when S_LINE2_WAIT =>
                    if line_done = '1' then
                        current_state <= S_DIV1_START;
                    end if;

                when S_DIV1_START =>
                    current_state <= S_DIV1_WAIT;

                when S_DIV1_WAIT =>
                    if div_done = '1' then
                        current_state <= S_MUL1_START;
                    end if;

                when S_MUL1_START =>
                    current_state <= S_MUL1_WAIT;

                when S_MUL1_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_TEST_BIT;
                        V_reg <= add_double_R;
                        t_reg <= mul_z;
                    end if;

                when S_TEST_BIT =>
                    if nbin_reg(to_integer(i_reg)) = '1' then
                        current_state <= S_ADD_START;
                    else
                        current_state <= S_UPDATE;
                    end if;

                when S_ADD_START =>
                    current_state <= S_ADD_WAIT;

                when S_ADD_WAIT =>
                    if add_double_done = '1' then
                        current_state <= S_LINE3_START;
                    end if;

                when S_LINE3_START =>
                    current_state <= S_LINE3_WAIT;

                when S_LINE3_WAIT =>
                    if inv_done = '1' and line_done = '1' then
                        current_state <= S_LINE4_START;
                        ell_reg <= line_l;
                    end if;

                when S_LINE4_START =>
                    current_state <= S_LINE4_WAIT;

                when S_LINE4_WAIT =>
                    if line_done = '1' then
                        current_state <= S_DIV2_START;
                    end if;

                when S_DIV2_START =>
                    current_state <= S_DIV2_WAIT;

                when S_DIV2_WAIT =>
                    if div_done = '1' then
                        current_state <= S_MUL2_START;
                    end if;

                when S_MUL2_START =>
                    current_state <= S_MUL2_WAIT;

                when S_MUL2_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_UPDATE;
                        t_reg <= mul_z;
                        V_reg <= add_double_R;
                    end if;

                when S_UPDATE =>
                    i_reg <= i_minus_one;
                    current_state <= S_TEST_LOOP;

                when others =>
                    current_state <= S_FINISH;
            end case;
        end if;
    end process;

    t <= t_reg;

end rtl;
