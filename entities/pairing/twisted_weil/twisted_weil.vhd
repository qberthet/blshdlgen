--------------------------------------------------------------------------------
-- Constants used:
--   c_FP_ZERO
--   c_FPM_ONE
--   c_FPM_MIN_ONE
--   c_Z
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity twisted_weil is
    generic (
        N_LENGTH: natural := c_P'length
    );
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        ecP:   in  ec1_point;
        ecQ:   in  ec1_point;
        n:     in  std_logic_vector(N_LENGTH-1 downto 0);
        r:     out Fpm_element;
        done:  out std_logic
    );
end twisted_weil;

architecture rtl of twisted_weil is

    component fpm_multiplier is
        port (
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
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  Fpm_element;
            y:     in  Fpm_element;
            z:     out Fpm_element
        );
    end component;

    component miller is
        generic (
            N_LENGTH: natural := c_P'length
        );
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            ecP:   in  ec2_point;
            ecQ:   in  ec2_point;
            n:     in  std_logic_vector(N_LENGTH-1 downto 0);
            t:     out Fpm_element
        );
    end component;

    signal mul_start:    std_logic;
    signal mul_done:     std_logic;
    signal mul_x:        Fpm_element;
    signal mul_y:        Fpm_element;
    signal mul_z:        Fpm_element;

    signal div_start:    std_logic;
    signal div_done:     std_logic;
    signal div_z:        Fpm_element;

    signal miller_start: std_logic;
    signal miller_done:  std_logic;

    signal miller_P:     ec2_point;
    signal miller_Q:     ec2_point;
    signal miller_res:   Fpm_element;

    signal ec2P:         ec2_point;
    signal ec2Q:         ec2_point;

    signal r_reg:        Fpm_element;
    signal x_twist_reg:  Fpm_element;

    type states is (
        S_FINISH,
        S_IDLE,
        S_CHECK,
        S_TWIST_START,
        S_TWIST_WAIT,
        S_MILLER1_START,
        S_MILLER1_WAIT,
        S_MILLER2_START,
        S_MILLER2_WAIT,
        S_EXP_DIV_START,
        S_EXP_DIV_WAIT,
        S_MUL_START,
        S_MUL_WAIT
    );
    signal current_state: states;

begin

    ----------------------------------------------------------------------------
    -- convert point from E1 to E2

    ec2P.x  <= x_twist_reg;
    ec2P.y  <= ( 0 => ecP.y, others => c_FP_ZERO);
    ec2P.ii <= ecP.ii;

    ec2Q.x  <= ( 0 => ecQ.x, others => c_FP_ZERO);
    ec2Q.y  <= ( 0 => ecQ.y, others => c_FP_ZERO);
    ec2Q.ii <= ecQ.ii;

    ----------------------------------------------------------------------------

    fpm_multiplier_i: entity work.fpm_multiplier
        port map(
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
        if current_state = S_TWIST_START or current_state = S_TWIST_WAIT then
            mul_x <= ( 0 => ecP.x, others => c_FP_ZERO);
            mul_y <= c_Z;
        else
            mul_y <= div_z;
            if n(0) = '1' then
                mul_x <= c_FPM_MIN_ONE;
            else
                mul_x <= c_FPM_ONE;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------

    fpm_divider_i: entity work.fpm_divider
        port map (
            clk   => clk,
            reset => reset,
            start => div_start,
            done  => div_done,
            x     => r_reg,
            y     => miller_res,
            z     => div_z
        );

    ----------------------------------------------------------------------------

    miller_i : entity work.miller
        port map (
            clk   => clk,
            reset => reset,
            start => miller_start,
            done  => miller_done,
            ecP   => miller_P,
            ecQ   => miller_Q,
            n     => n,
            t     => miller_res
        );

    miller_line_routing: process(all)
    begin
        case current_state is
            when S_MILLER1_START to S_MILLER1_WAIT => miller_P <= ec2P; miller_Q <= ec2Q;
            when S_MILLER2_START to S_MILLER2_WAIT => miller_P <= ec2Q; miller_Q <= ec2P;
            when others                            => miller_P <= ec2P; miller_Q <= ec2Q;
        end case;
    end process miller_line_routing;

    ----------------------------------------------------------------------------

    seq_unit: process(all)
    begin
        case current_state is
            when S_FINISH to S_IDLE => mul_start <= '0'; div_start <= '0'; miller_start <= '0'; done <= '1'; -- Wait start
            when S_TWIST_START      => mul_start <= '1'; div_start <= '0'; miller_start <= '0'; done <= '0';
            when S_MILLER1_START    => mul_start <= '0'; div_start <= '0'; miller_start <= '1'; done <= '0';
            when S_MILLER2_START    => mul_start <= '0'; div_start <= '0'; miller_start <= '1'; done <= '0';
            when S_EXP_DIV_START    => mul_start <= '0'; div_start <= '1'; miller_start <= '0'; done <= '0';
            when S_MUL_START        => mul_start <= '1'; div_start <= '0'; miller_start <= '0'; done <= '0';
            when others             => mul_start <= '0'; div_start <= '0'; miller_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= S_FINISH;
        elsif rising_edge(clk) then
            case current_state is

                when S_FINISH => -- Wait start low
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                when S_IDLE => -- Wait start high
                    if start = '1' then
                        current_state <= S_CHECK;
                    end if;
                when S_CHECK =>
                    if ecP.ii = '1' or ecQ.ii = '1' or (ecP.x = ecQ.x and ecP.y = ecQ.y and ecP.ii = ecQ.ii) then
                        r_reg <= c_FPM_ONE;
                        current_state <= S_FINISH;
                    else
                        current_state <= S_TWIST_START;
                    end if;
                when S_TWIST_START =>
                    current_state <= S_TWIST_WAIT;
                when S_TWIST_WAIT =>
                    if mul_done = '1' then
                        x_twist_reg <= mul_z;
                        current_state <= S_MILLER1_START;
                    end if;
                when S_MILLER1_START =>
                    current_state <= S_MILLER1_WAIT;
                when S_MILLER1_WAIT =>
                    if miller_done = '1' then
                        r_reg <= miller_res;
                        current_state <= S_MILLER2_START;
                    end if;
                when S_MILLER2_START =>
                    current_state <= S_MILLER2_WAIT;
                when S_MILLER2_WAIT =>
                    if miller_done = '1' then
                        current_state <= S_EXP_DIV_START;
                    end if;
                when S_EXP_DIV_START =>
                    current_state <= S_EXP_DIV_WAIT;
                when S_EXP_DIV_WAIT =>
                    if div_done = '1' then
                        current_state <= S_MUL_START;
                    end if;
                when S_MUL_START =>
                    current_state <= S_MUL_WAIT;
                when S_MUL_WAIT =>
                    if mul_done = '1' then
                        r_reg <= mul_z;
                        current_state <= S_FINISH;
                    end if;

                when others =>
                    current_state <= S_FINISH;
            end case;
        end if;
    end process;

    r <= r_reg;

end rtl;