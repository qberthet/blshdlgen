--------------------------------------------------------------------------------
-- Constants used:
--   c_P
--   c_E2_A1
--   c_E2_A2
--   c_E2_A3
--   c_E2_A4
--   c_FPM_ZERO
--   c_FPM_ONE
--   c_FPM_TWO
--   c_FPM_TREE
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity miller_line is
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
end miller_line;

architecture rtl of miller_line is

    component fpm_adder_subtractor is
        port(
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fpm_element;
            y:        in  Fpm_element;
            z:        out Fpm_element;
            addn_sub: in  std_logic
        );
    end component;

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

    signal regl:          Fpm_element;

    signal P_eq_R:        std_logic;

    signal addsub1_start: std_logic;
    signal addsub1_done:  std_logic;
    signal addn_sub1:     std_logic;
    signal addsub1_x:     Fpm_element;
    signal addsub1_y:     Fpm_element;
    signal addsub1_z:     Fpm_element;
    signal addsub2_start: std_logic;
    signal addsub2_done:  std_logic;
    signal addn_sub2:     std_logic;
    signal addsub2_x:     Fpm_element;
    signal addsub2_y:     Fpm_element;
    signal addsub2_z:     Fpm_element;
    signal mul_start:     std_logic;
    signal mul_done:      std_logic;
    signal mul_x:         Fpm_element;
    signal mul_y:         Fpm_element;
    signal mul_z:         Fpm_element;
    signal div_start:     std_logic;
    signal div_done:      std_logic;
    signal div_x:         Fpm_element;
    signal div_y:         Fpm_element;
    signal div_z:         Fpm_element;

    type states is (
        S_FINISH, S_IDLE, S_TEST,
        S_QX_MIN_RX_START, S_QX_MIN_RX_WAIT,
        S_QX_MIN_PX_START, S_QX_MIN_PX_WAIT,
        S_P_NOT_R_1_START, S_P_NOT_R_1_WAIT, S_P_NOT_R_2_START, S_P_NOT_R_2_WAIT,
        S_P_NOT_R_3_START, S_P_NOT_R_3_WAIT, S_P_NOT_R_4_START, S_P_NOT_R_4_WAIT,
        S_P_NOT_R_5_START, S_P_NOT_R_5_WAIT,
        S_DENOM_1_START,   S_DENOM_1_WAIT,   S_DENOM_2_START,   S_DENOM_2_WAIT,
        S_DENOM_3_START,   S_DENOM_3_WAIT,   S_DENOM_4_START,   S_DENOM_4_WAIT,
        S_NUM_1_START,     S_NUM_1_WAIT,     S_NUM_2_START,     S_NUM_2_WAIT,
        S_NUM_3_START,     S_NUM_3_WAIT,     S_NUM_4_START,     S_NUM_4_WAIT,
        S_NUM_5_START,     S_NUM_5_WAIT,     S_NUM_6_START,     S_NUM_6_WAIT,
        S_NUM_7_START,     S_NUM_7_WAIT,
        S_RES_1_START,     S_RES_1_WAIT,     S_RES_2_START,     S_RES_2_WAIT,
        S_RES_3_START,     S_RES_3_WAIT,     S_RES_4_START,     S_RES_4_WAIT
    );
    signal current_state: states;

begin

    ----------------------------------------------------------------------------
    -- 1st modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------
    fpm_adder_subtractor1_i: entity work.fpm_adder_subtractor
    port map (
        clk      => clk,
        reset    => reset,
        start    => addsub1_start,
        done     => addsub1_done,
        addn_sub => addn_sub1,
        x        => addsub1_x,
        y        => addsub1_y,
        z        => addsub1_z
    );

    fpm_adder_subtractor1_routing: process(all)
    begin
        case current_state is
            when S_QX_MIN_RX_START to S_QX_MIN_RX_WAIT => addn_sub1 <= '1'; addsub1_x <= ecQ.x;     addsub1_y <= ecR.x;
            when S_QX_MIN_PX_START to S_QX_MIN_PX_WAIT => addn_sub1 <= '1'; addsub1_x <= ecQ.x;     addsub1_y <= ecP.x;
            when S_P_NOT_R_1_START to S_P_NOT_R_1_WAIT => addn_sub1 <= '1'; addsub1_x <= ecR.y;     addsub1_y <= ecP.y;
            when S_P_NOT_R_3_START to S_P_NOT_R_3_WAIT => addn_sub1 <= '1'; addsub1_x <= ecQ.y;     addsub1_y <= ecP.y;
            when S_P_NOT_R_5_START to S_P_NOT_R_5_WAIT => addn_sub1 <= '1'; addsub1_x <= addsub1_z; addsub1_y <= mul_z;
            when S_DENOM_3_START   to S_DENOM_3_WAIT   => addn_sub1 <= '0'; addsub1_x <= regl;      addsub1_y <= mul_z;
            when S_DENOM_4_START   to S_DENOM_4_WAIT   => addn_sub1 <= '0'; addsub1_x <= addsub1_z; addsub1_y <= c_E2_A3;
            when S_RES_2_START     to S_RES_2_WAIT     => addn_sub1 <= '1'; addsub1_x <= ecQ.y;     addsub1_y <= ecP.y;
            when others                                => addn_sub1 <= '0'; addsub1_x <= ecQ.x;     addsub1_y <= ecR.x;
        end case;
    end process fpm_adder_subtractor1_routing;

    ----------------------------------------------------------------------------
    -- 2nd modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------
    fpm_adder_subtractor2_i: entity work.fpm_adder_subtractor
    port map (
        clk      => clk,
        reset    => reset,
        start    => addsub2_start,
        done     => addsub2_done,
        addn_sub => addn_sub2,
        x        => addsub2_x,
        y        => addsub2_y,
        z        => addsub2_z
    );

    fpm_adder_subtractor2_routing: process(all)
    begin
        case current_state is
            when S_P_NOT_R_1_START to S_P_NOT_R_1_WAIT => addn_sub2 <= '1'; addsub2_x <= ecR.x;     addsub2_y <= ecP.x;
            when S_P_NOT_R_3_START to S_P_NOT_R_3_WAIT => addn_sub2 <= '1'; addsub2_x <= ecQ.x;     addsub2_y <= ecP.x;
            when S_NUM_5_START     to S_NUM_5_WAIT     => addn_sub2 <= '0'; addsub2_x <= regl;      addsub2_y <= mul_z;
            when S_NUM_6_START     to S_NUM_6_WAIT     => addn_sub2 <= '0'; addsub2_x <= addsub2_z; addsub2_y <= c_E2_A4;
            when S_NUM_7_START     to S_NUM_7_WAIT     => addn_sub2 <= '1'; addsub2_x <= addsub2_z; addsub2_y <= mul_z;
            when S_RES_2_START     to S_RES_2_WAIT     => addn_sub2 <= '1'; addsub2_x <= ecQ.x;     addsub2_y <= ecP.x;
            when S_RES_4_START     to S_RES_4_WAIT     => addn_sub2 <= '1'; addsub2_x <= addsub1_z; addsub2_y <= mul_z;
            when others                                => addn_sub2 <= '0'; addsub2_x <= ecR.x;     addsub2_y <= ecP.x;
        end case;
    end process fpm_adder_subtractor2_routing;

    ----------------------------------------------------------------------------
    -- Modular multiplier entity and input routing
    ----------------------------------------------------------------------------
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
            when S_P_NOT_R_3_START to S_P_NOT_R_3_WAIT => mul_x <= div_z;     mul_y <= addsub2_z;
            when S_DENOM_1_START   to S_DENOM_1_WAIT   => mul_x <= c_FPM_TWO; mul_y <= ecP.y;
            when S_DENOM_2_START   to S_DENOM_2_WAIT   => mul_x <= c_E2_A1;   mul_y <= ecP.x;
            when S_NUM_1_START     to S_NUM_1_WAIT     => mul_x <= ecP.x;     mul_y <= ecP.x;
            when S_NUM_2_START     to S_NUM_2_WAIT     => mul_x <= mul_z;     mul_y <= c_FPM_TREE;
            when S_NUM_3_START     to S_NUM_3_WAIT     => mul_x <= c_E2_A2;   mul_y <= c_FPM_TWO;
            when S_NUM_4_START     to S_NUM_4_WAIT     => mul_x <= mul_z;     mul_y <= ecP.x;
            when S_NUM_5_START     to S_NUM_5_WAIT     => mul_x <= div_z;     mul_y <= addsub2_z;
            when S_NUM_6_START     to S_NUM_6_WAIT     => mul_x <= c_E2_A1;   mul_y <= ecP.y;
            when S_RES_3_START     to S_RES_3_WAIT     => mul_x <= div_z;     mul_y <= addsub2_z;
            when others                                => mul_x <= div_z;     mul_y <= addsub2_z;
        end case;
    end process fpm_multiplier_routing;

    ----------------------------------------------------------------------------
    -- Modular division entity (no input routing needed)
    ----------------------------------------------------------------------------
    fpm_divider_i: entity work.fpm_divider
    port map (
        clk   => clk,
        reset => reset,
        start => div_start,
        done  => div_done,
        x     => div_x,
        y     => div_y,
        z     => div_z
    );

    fp_divider_routing: process(all)
    begin
        case current_state is
            when S_P_NOT_R_2_START to S_P_NOT_R_2_WAIT => div_x <= addsub1_z; div_y <= addsub2_z;
            when S_RES_1_START     to S_RES_1_WAIT     => div_x <= addsub2_z; div_y <= addsub1_z;
            when others                                => div_x <= addsub1_z; div_y <= addsub2_z;
        end case;
    end process fp_divider_routing;

    ----------------------------------------------------------------------------

    P_eq_R <= '1' when ecP = ecR else '0';

    seq_unit: process(all)
    begin
        case current_state is
            when S_FINISH to S_IDLE => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '1';
            when S_QX_MIN_RX_START  => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_QX_MIN_PX_START  => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_P_NOT_R_1_START  => addsub1_start <= '1'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_P_NOT_R_2_START  => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '1'; done <= '0';
            when S_P_NOT_R_3_START  => addsub1_start <= '1'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_P_NOT_R_4_START  => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_P_NOT_R_5_START  => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DENOM_1_START    => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_DENOM_2_START    => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_DENOM_3_START    => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DENOM_4_START    => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_NUM_1_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_NUM_2_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_NUM_3_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_NUM_4_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_NUM_5_START      => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_NUM_6_START      => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_NUM_7_START      => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_RES_1_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '1'; done <= '0';
            when S_RES_2_START      => addsub1_start <= '1'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_RES_3_START      => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_RES_4_START      => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when others             => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk,reset)
    begin
        if reset = '1' then
            current_state <= S_FINISH;
            regl          <= c_FPM_ONE;
        elsif rising_edge(clk) then
            case current_state is
                when S_FINISH => -- Wait start low
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                when S_IDLE => -- Wait start high
                    if start = '1' then
                        current_state <= S_TEST;
                    end if;
                when S_TEST =>
                    if ecQ.ii = '1' then
                        -- Q must be non zero by definition, but check for it
                        -- and return 0 to make it obvious
                        regl <= c_FPM_ZERO;
                    elsif ecP.ii = '1' or ecR.ii = '1' then
                        if ecP.ii = '1' and ecR.ii = '1' then
                            regl <= c_FPM_ONE;
                            current_state <= S_FINISH;
                        elsif ecP.ii = '1' then
                            current_state <= S_QX_MIN_RX_START;
                        elsif ecR.ii = '1' then
                            current_state <= S_QX_MIN_PX_START;
                        end if;
                    elsif P_eq_R = '0' then
                        if ecP.x = ecR.x then
                            current_state <= S_QX_MIN_PX_START;
                        else
                            current_state <= S_P_NOT_R_1_START;
                        end if;
                    else
                        current_state <= S_DENOM_1_START;
                    end if;
                ----------------------------------------------------------------
                when S_QX_MIN_RX_START =>
                    current_state <= S_QX_MIN_RX_WAIT;
                when S_QX_MIN_RX_WAIT =>
                    -- FIXME this state could be merged with S_WAIT_QX_MIN_PX
                    if addsub1_done = '1' then
                        regl <= addsub1_z;
                        current_state <= S_FINISH;
                    end if;
                ----------------------------------------------------------------
                when S_QX_MIN_PX_START =>
                    current_state <= S_QX_MIN_PX_WAIT;
                when S_QX_MIN_PX_WAIT =>
                    if addsub1_done = '1' then
                        regl <= addsub1_z;
                        current_state <= S_FINISH;
                    end if;
                ----------------------------------------------------------------
                when S_P_NOT_R_1_START =>
                    current_state <= S_P_NOT_R_1_WAIT;
                when S_P_NOT_R_1_WAIT =>
                    if addsub1_done = '1' and addsub2_done = '1' then
                        current_state <= S_P_NOT_R_2_START;
                    end if;
                when S_P_NOT_R_2_START =>
                    current_state <= S_P_NOT_R_2_WAIT;
                when S_P_NOT_R_2_WAIT =>
                    if div_done = '1' then
                        current_state <= S_P_NOT_R_3_START;
                    end if;
                when S_P_NOT_R_3_START =>
                    current_state <= S_P_NOT_R_3_WAIT;
                when S_P_NOT_R_3_WAIT =>
                    if addsub1_done = '1' and addsub2_done = '1' then
                        current_state <= S_P_NOT_R_4_START;
                    end if;
                when S_P_NOT_R_4_START =>
                    current_state <= S_P_NOT_R_4_WAIT;
                when S_P_NOT_R_4_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_P_NOT_R_5_START;
                    end if;
                when S_P_NOT_R_5_START =>
                    current_state <= S_P_NOT_R_5_WAIT;
                when S_P_NOT_R_5_WAIT =>
                    if addsub1_done = '1' then
                        regl <= addsub1_z;
                        current_state <= S_FINISH;
                    end if;
                ----------------------------------------------------------------
                when S_DENOM_1_START =>
                    current_state <= S_DENOM_1_WAIT;
                when S_DENOM_1_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_DENOM_2_START;
                        regl <= mul_z;
                    end if;
                when S_DENOM_2_START =>
                    current_state <= S_DENOM_2_WAIT;
                when S_DENOM_2_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_DENOM_3_START;
                    end if;
                when S_DENOM_3_START =>
                    current_state <= S_DENOM_3_WAIT;
                when S_DENOM_3_WAIT =>
                    if addsub1_done = '1' then
                        current_state <= S_DENOM_4_START;
                    end if;
                when S_DENOM_4_START =>
                    current_state <= S_DENOM_4_WAIT;
                when S_DENOM_4_WAIT =>
                    if addsub1_done = '1' then
                        if addsub1_z = c_FPM_ZERO then
                            current_state <= S_QX_MIN_PX_START;
                        else
                            current_state <= S_NUM_1_START;
                        end if;
                    end if;
                ----------------------------------------------------------------
                when S_NUM_1_START =>
                    current_state <= S_NUM_1_WAIT;
                when S_NUM_1_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_NUM_2_START;
                    end if;
                when S_NUM_2_START =>
                    current_state <= S_NUM_2_WAIT;
                when S_NUM_2_WAIT =>
                    if mul_done = '1' then
                        regl <= mul_z;
                        current_state <= S_NUM_3_START;
                    end if;
                when S_NUM_3_START =>
                    current_state <= S_NUM_3_WAIT;
                when S_NUM_3_WAIT =>
                    if addsub1_done = '1' then
                        current_state <= S_NUM_4_START;
                    end if;
                when S_NUM_4_START =>
                    current_state <= S_NUM_4_WAIT;
                when S_NUM_4_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_NUM_5_START;
                    end if;
                when S_NUM_5_START =>
                    current_state <= S_NUM_5_WAIT;
                when S_NUM_5_WAIT =>
                    if addsub2_done = '1' and mul_done = '1' then
                        current_state <= S_NUM_6_START;
                    end if;
                when S_NUM_6_START =>
                    current_state <= S_NUM_6_WAIT;
                when S_NUM_6_WAIT =>
                    if addsub2_done = '1' and mul_done = '1' then
                        current_state <= S_NUM_7_START;
                    end if;
                when S_NUM_7_START =>
                    current_state <= S_NUM_7_WAIT;
                when S_NUM_7_WAIT =>
                    if addsub2_done = '1' then
                        current_state <= S_RES_1_START;
                    end if;
                ----------------------------------------------------------------
                when S_RES_1_START =>
                    current_state <= S_RES_1_WAIT;
                when S_RES_1_WAIT =>
                    if div_done = '1' then
                        current_state <= S_RES_2_START;
                    end if;
                when S_RES_2_START =>
                    current_state <= S_RES_2_WAIT;
                when S_RES_2_WAIT =>
                    if addsub2_done = '1' and addsub2_done = '1' then
                        current_state <= S_RES_3_START;
                    end if;
                when S_RES_3_START =>
                    current_state <= S_RES_3_WAIT;
                when S_RES_3_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_RES_4_START;
                    end if;
                when S_RES_4_START =>
                    current_state <= S_RES_4_WAIT;
                when S_RES_4_WAIT =>
                    if addsub2_done = '1' then
                        regl <= addsub2_z;
                        current_state <= S_FINISH;
                    end if;
                when others =>
                    current_state <= S_FINISH;
            end case;
        end if;
    end process;

    -- Assign output
    l <= regl;

end rtl;