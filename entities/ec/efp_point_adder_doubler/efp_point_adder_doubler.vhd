-- Adder / doubler algo:
--------------------------------------------------------------------------------
-- if action = add(P,Q) then
--     if P = point_at_infinity then R := Q;
--     elsif Q = point_at_infinity then R:= P;
--     elsif P = -Q then R := point_at_infinity;
--     elsif P = Q then R := doubling(P);
--     else R := adding(P,Q);
--     end if;
-- else -- action = double(P), Q -> don't care
--     if P = point_at_infinity then R := point_at_infinity;
--     else doubling(P);
-- end if;
--
-- Constants used:
--   c_FP_ZERO
--   c_E1_A4
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity efp_point_adder_doubler is
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
end efp_point_adder_doubler;

architecture rtl of efp_point_adder_doubler is

    component fp_adder_subtractor is
        port (
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fp_element;
            y:        in  Fp_element;
            z:        out Fp_element;
            addn_sub: in std_logic
        );
    end component;

    component fp_divider is
        port(
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  Fp_element;
            y:     in  Fp_element;
            z:     out Fp_element
        );
    end component;

    component fp_multiplier is
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

    signal addsub1_start: std_logic;
    signal addsub1_done:  std_logic;
    signal addn_sub1:     std_logic;
    signal addsub1_x:     Fp_element;
    signal addsub1_y:     Fp_element;
    signal addsub1_z:     Fp_element;

    signal addsub2_start: std_logic;
    signal addsub2_done:  std_logic;
    signal addn_sub2:     std_logic;
    signal addsub2_x:     Fp_element;
    signal addsub2_y:     Fp_element;
    signal addsub2_z:     Fp_element;

    signal mul_start:     std_logic;
    signal mul_done:      std_logic;
    signal mul_x:         Fp_element;
    signal mul_y:         Fp_element;
    signal mul_z:         Fp_element;

    signal div_start:     std_logic;
    signal div_done:      std_logic;
    signal div_x:         Fp_element;
    signal div_y:         Fp_element;
    signal div_z:         Fp_element;

    signal ecR_reg:       ec1_point;

    signal xP_eq_xQ:      std_logic;
    signal yP_eq_yQ:      std_logic;
    signal P_eq_minQ:     std_logic;
    signal P_eq_Q:        std_logic;
    signal yP_eq_0:       std_logic;

    type states is (
        S_FINISH,
        S_IDLE,
        S_CHECK_ADD,
        S_CHECK_DOUBLE,
        -- Addition sequence
        S_ADD_1_START, S_ADD_1_WAIT, S_ADD_2_START, S_ADD_2_WAIT,
        S_ADD_3_START, S_ADD_3_WAIT, S_ADD_4_START, S_ADD_4_WAIT,
        S_ADD_5_START, S_ADD_5_WAIT, S_ADD_6_START, S_ADD_6_WAIT,
        S_ADD_7_START, S_ADD_7_WAIT,
        -- Doubling sequence
        S_DOUBLE_1_START, S_DOUBLE_1_WAIT, S_DOUBLE_2_START,  S_DOUBLE_2_WAIT,
        S_DOUBLE_3_START, S_DOUBLE_3_WAIT, S_DOUBLE_4_START,  S_DOUBLE_4_WAIT,
        S_DOUBLE_5_START, S_DOUBLE_5_WAIT, S_DOUBLE_6_START,  S_DOUBLE_6_WAIT,
        S_DOUBLE_7_START, S_DOUBLE_7_WAIT, S_DOUBLE_8_START,  S_DOUBLE_8_WAIT,
        S_DOUBLE_9_START, S_DOUBLE_9_WAIT, S_DOUBLE_10_START, S_DOUBLE_10_WAIT
    );

    signal current_state: states;

begin

    ----------------------------------------------------------------------------
    -- First modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------

    fp_adder_subtractor1_i: entity work.fp_adder_subtractor
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

    adder_subtractor1_routing: process(all)
    begin
        case current_state is
            when S_ADD_1_START     to S_ADD_3_WAIT     => addn_sub1 <= '1'; addsub1_x <= ecQ.x;  addsub1_y <= ecP.x;
            when S_ADD_4_START     to S_ADD_6_WAIT     => addn_sub1 <= '1'; addsub1_x <= mul_z;  addsub1_y <= addsub2_z;
            when S_ADD_7_START     to S_ADD_7_WAIT     => addn_sub1 <= '1'; addsub1_x <= mul_z;  addsub1_y <= ecP.y;
            when S_DOUBLE_4_START  to S_DOUBLE_5_WAIT  => addn_sub1 <= '0'; addsub1_x <= ecP.y;  addsub1_y <= ecP.y;
            when S_DOUBLE_6_START  to S_DOUBLE_7_WAIT  => addn_sub1 <= '0'; addsub1_x <= ecP.x;  addsub1_y <= ecP.x;
            when S_DOUBLE_8_START  to S_DOUBLE_8_WAIT  => addn_sub1 <= '1'; addsub1_x <= ecP.x;  addsub1_y <= ecR_reg.x;
            when others                                => addn_sub1 <= '1'; addsub1_x <= ecQ.x;  addsub1_y <= ecQ.y;
        end case;
    end process adder_subtractor1_routing;

    ----------------------------------------------------------------------------
    -- Second modular addition/subtraction entity and input routing
    ----------------------------------------------------------------------------
    fp_adder_subtractor2_i: entity work.fp_adder_subtractor
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

    adder_subtractor2_routing: process(all)
    begin
        case current_state is
            when S_ADD_1_START     to S_ADD_2_WAIT     => addn_sub2 <= '1'; addsub2_x <= ecQ.y;     addsub2_y <= ecP.y;
            when S_ADD_3_START     to S_ADD_4_WAIT     => addn_sub2 <= '0'; addsub2_x <= ecP.x;     addsub2_y <= ecQ.x;
            when S_ADD_5_START     to S_ADD_5_WAIT     => addn_sub2 <= '1'; addsub2_x <= ecP.x;     addsub2_y <= ecR_reg.x;
            when S_DOUBLE_2_START  to S_DOUBLE_2_WAIT  => addn_sub2 <= '0'; addsub2_x <= mul_z;     addsub2_y <= mul_z;
            when S_DOUBLE_3_START  to S_DOUBLE_3_WAIT  => addn_sub2 <= '0'; addsub2_x <= addsub2_z; addsub2_y <= mul_z;
            when S_DOUBLE_4_START  to S_DOUBLE_6_WAIT  => addn_sub2 <= '0'; addsub2_x <= addsub2_z; addsub2_y <= C_E1_A4;
            when S_DOUBLE_7_START  to S_DOUBLE_9_WAIT  => addn_sub2 <= '1'; addsub2_x <= mul_z;     addsub2_y <= addsub1_z;
            when S_DOUBLE_10_START to S_DOUBLE_10_WAIT => addn_sub2 <= '1'; addsub2_x <= mul_z;     addsub2_y <= ecP.y;
            when others                                => addn_sub2 <= '1'; addsub2_x <= ecQ.y;     addsub2_y <= ecP.y;
        end case;
    end process adder_subtractor2_routing;

    ----------------------------------------------------------------------------
    -- Modular multiplier entity and input routing
    ----------------------------------------------------------------------------
    fp_multiplier_i: entity work.fp_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => mul_start,
        done  => mul_done,
        x     => mul_x,
        y     => mul_y,
        z     => mul_z
    );

    multiplier_routing: process(all)
    begin
        case current_state is
            when S_ADD_3_START     to S_ADD_5_WAIT     => mul_x <= div_z;     mul_y <= div_z;
            when S_ADD_6_START     to S_ADD_6_WAIT     => mul_x <= ecR_reg.y; mul_y <= addsub2_z;
            when S_DOUBLE_1_START  to S_DOUBLE_5_WAIT  => mul_x <= ecP.x;     mul_y <= ecP.x;
            when S_DOUBLE_6_START  to S_DOUBLE_8_WAIT  => mul_x <= ecR_reg.y; mul_y <= ecR_reg.y;
            when S_DOUBLE_9_START  to S_DOUBLE_9_WAIT  => mul_x <= ecR_reg.y; mul_y <= addsub1_z;
            when others                                => mul_x <= div_z;     mul_y <= div_z;
        end case;
    end process multiplier_routing;

    ----------------------------------------------------------------------------
    -- Modular division entity (no input routing needed)
    ----------------------------------------------------------------------------
    fp_divider_i: entity work.fp_divider
    port map (
        clk   => clk,
        reset => reset,
        start => div_start,
        done  => div_done,
        x     => div_x,
        y     => div_y,
        z     => div_z
    );

    div_x <= addsub2_z;
    div_y <= addsub1_z;

    ----------------------------------------------------------------------------
    -- Registers process
    ----------------------------------------------------------------------------
    registers: process(clk)
    begin
        if rising_edge(clk) then
            ecR_reg <= ecR_reg;
            case current_state is
                when S_IDLE =>
                    if start = '1' then
                        ecR_reg.ii <= '0';
                    end if;
                when S_CHECK_ADD =>
                    if ecP.ii = '1' then
                        -- If P = infinity, return Q
                        ecR_reg <= ecQ;
                    elsif ecQ.ii = '1' then
                        -- If Q = infinity, return P
                        ecR_reg <= ecP;
                    elsif P_eq_minQ = '1' then
                        -- If P = -Q, return infinity
                        ecR_reg <= EC1_POINT_I;
                    end if;
                when S_CHECK_DOUBLE =>
                    if ecP.ii = '1' or yP_eq_0 = '1' then
                        -- If P = infinity or y1 = 0, return infinity
                        ecR_reg <= EC1_POINT_I;
                    end if;
                -- Addition
                when S_ADD_2_WAIT =>
                    if div_done = '1' then
                        ecR_reg.y <= div_z;
                    end if;
                when S_ADD_4_WAIT =>
                    if addsub1_done = '1' then
                        ecR_reg.x <= addsub1_z;
                    end if;
                when S_ADD_7_WAIT =>
                    if addsub1_done = '1' then
                        ecR_reg.y <= addsub1_z;
                    end if;
                -- Doubling
                when S_DOUBLE_5_WAIT =>
                    if div_done = '1' then
                        ecR_reg.y <= div_z;
                    end if;
                when S_DOUBLE_7_WAIT =>
                    if addsub2_done = '1' then
                        ecR_reg.x <= addsub2_z;
                    end if;
                when S_DOUBLE_10_WAIT =>
                    if addsub2_done = '1' then
                        ecR_reg.y <= addsub2_z;
                    end if;

                when others =>
                    null;
            end case;
        end if;
    end process registers;

    ----------------------------------------------------------------------------
    -- Combinational comparators needed to check if P=Q, P=-Q or ecP.y=0
    -- Output of Peq_min_Q only valid during current_state = S_CHECK_ADD_WAIT
    ----------------------------------------------------------------------------
    xP_eq_xQ   <= '1' when ecP.x = ecQ.x                     else '0';
    yP_eq_yQ   <= '1' when ecP.y = ecQ.y                     else '0';
    P_eq_minQ  <= '1' when xP_eq_xQ = '1' and yP_eq_yQ = '0' else '0';
    P_eq_Q     <= '1' when xP_eq_xQ = '1' and yP_eq_yQ = '1' else '0';
    yP_eq_0    <= '1' when ecP.y = c_FP_ZERO                   else '0';

    ----------------------------------------------------------------------------
    -- Sequence unit: trig computation entities
    ----------------------------------------------------------------------------

    seq_unit: process(all)
    begin
        -- Start the different computations based on current state
        case current_state is
            when S_FINISH          => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '1';
            when S_IDLE            => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '1';
            when S_ADD_1_START     => addsub1_start <= '1'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_ADD_2_START     => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '1'; done <= '0';
            when S_ADD_3_START     => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_ADD_4_START     => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_ADD_5_START     => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_ADD_6_START     => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_ADD_7_START     => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_1_START  => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_DOUBLE_2_START  => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_3_START  => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_4_START  => addsub1_start <= '1'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_5_START  => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '1'; done <= '0';
            when S_DOUBLE_6_START  => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_DOUBLE_7_START  => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_8_START  => addsub1_start <= '1'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when S_DOUBLE_9_START  => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '1'; div_start <= '0'; done <= '0';
            when S_DOUBLE_10_START => addsub1_start <= '0'; addsub2_start <= '1'; mul_start <= '0'; div_start <= '0'; done <= '0';
            when others            => addsub1_start <= '0'; addsub2_start <= '0'; mul_start <= '0'; div_start <= '0'; done <= '0';
        end case;
    end process;

    ----------------------------------------------------------------------------
    -- Control unit: Sequence states and trig computation entities
    ----------------------------------------------------------------------------

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

                when S_IDLE =>   -- Wait start high
                    if start = '1' then
                        if an_d = '0' then
                            current_state <= S_CHECK_ADD;
                        else
                            current_state <= S_CHECK_DOUBLE;
                        end if;
                    end if;

                ----------------------------------------------------------------
                -- Check if addition is possible
                ----------------------------------------------------------------

                -- FIXME: merge this state with S_IDLE ?
                when S_CHECK_ADD =>
                    if ecP.ii = '1' or ecQ.ii = '1' or P_eq_minQ = '1' then
                        -- In theses conditions, the result will be known
                        -- immadiately
                        current_state <= S_FINISH;
                    elsif P_eq_Q = '1' then
                        -- If P equal Q, we need to douple P
                        current_state <= S_DOUBLE_1_START;
                    else
                        -- Addition is possible, start it
                        current_state <= S_ADD_1_START;
                    end if;

                ----------------------------------------------------------------
                -- Check if doubling is possible
                ----------------------------------------------------------------

                -- FIXME: merge this state with S_IDLE ?
                when S_CHECK_DOUBLE =>
                    if ecP.ii = '1' or yP_eq_0 = '1' then
                        -- If P is the point at infinity or ecP.y = 0, return
                        -- point at infinity...
                        current_state <= S_FINISH;
                    else
                        -- Start the doubling sequence
                        current_state <= S_DOUBLE_1_START;
                    end if;

                ----------------------------------------------------------------
                -- Addition sequence
                ----------------------------------------------------------------

                when S_ADD_1_START =>
                    current_state <= S_ADD_1_WAIT;
                when S_ADD_1_WAIT  =>
                    if addsub1_done = '1' and addsub2_done = '1' then
                        current_state <= S_ADD_2_START;
                    end if;

                when S_ADD_2_START =>
                    current_state <= S_ADD_2_WAIT;
                when S_ADD_2_WAIT  =>
                    if div_done = '1' then
                        current_state <= S_ADD_3_START;
                    end if;

                when S_ADD_3_START =>
                    current_state <= S_ADD_3_WAIT;
                when S_ADD_3_WAIT  =>
                    if addsub2_done = '1' and mul_done = '1' then
                        current_state <= S_ADD_4_START;
                    end if;

                when S_ADD_4_START =>
                    current_state <= S_ADD_4_WAIT;
                when S_ADD_4_WAIT  =>
                    if addsub1_done = '1' then
                        current_state <= S_ADD_5_START;
                    end if;

                when S_ADD_5_START =>
                    current_state <= S_ADD_5_WAIT;
                when S_ADD_5_WAIT  =>
                    if addsub2_done = '1' then
                        current_state <= S_ADD_6_START;
                    end if;

                when S_ADD_6_START =>
                    current_state <= S_ADD_6_WAIT;
                when S_ADD_6_WAIT  =>
                    if mul_done = '1' then
                        current_state <= S_ADD_7_START;
                    end if;

                when S_ADD_7_START =>
                    current_state <= S_ADD_7_WAIT;
                when S_ADD_7_WAIT  =>
                    if addsub1_done = '1' then
                        current_state <= S_FINISH;
                    end if;

                ----------------------------------------------------------------
                -- Doubling sequence
                ----------------------------------------------------------------

                when S_DOUBLE_1_START  =>
                    current_state <= S_DOUBLE_1_WAIT;
                when S_DOUBLE_1_WAIT   =>
                    if mul_done = '1' then
                        current_state <= S_DOUBLE_2_START;
                    end if;

                when S_DOUBLE_2_START  =>
                    current_state <= S_DOUBLE_2_WAIT;
                when S_DOUBLE_2_WAIT   =>
                    if addsub1_done = '1' then
                        current_state <= S_DOUBLE_3_START;
                    end if;

                when S_DOUBLE_3_START  =>
                    current_state <= S_DOUBLE_3_WAIT;
                when S_DOUBLE_3_WAIT   =>
                    if addsub1_done = '1' then
                        current_state <= S_DOUBLE_4_START;
                    end if;

                when S_DOUBLE_4_START  =>
                    current_state <= S_DOUBLE_4_WAIT;
                when S_DOUBLE_4_WAIT   =>
                    if addsub1_done = '1' and addsub2_done = '1' then
                        current_state <= S_DOUBLE_5_START;
                    end if;

                when S_DOUBLE_5_START  =>
                    current_state <= S_DOUBLE_5_WAIT;
                when S_DOUBLE_5_WAIT   =>
                    if div_done = '1' then
                        current_state <= S_DOUBLE_6_START;
                    end if;

                when S_DOUBLE_6_START  =>
                    current_state <= S_DOUBLE_6_WAIT;
                when S_DOUBLE_6_WAIT   =>
                    if addsub1_done = '1' and mul_done = '1' then
                        current_state <= S_DOUBLE_7_START;
                    end if;

                when S_DOUBLE_7_START  =>
                    current_state <= S_DOUBLE_7_WAIT;
                when S_DOUBLE_7_WAIT   =>
                    if addsub2_done = '1' then
                        current_state <= S_DOUBLE_8_START;
                    end if;

                when S_DOUBLE_8_START  =>
                    current_state <= S_DOUBLE_8_WAIT;
                when S_DOUBLE_8_WAIT   =>
                    if addsub1_done = '1' then
                        current_state <= S_DOUBLE_9_START;
                    end if;

                when S_DOUBLE_9_START  =>
                    current_state <= S_DOUBLE_9_WAIT;
                when S_DOUBLE_9_WAIT  =>
                    if mul_done = '1' then
                        current_state <= S_DOUBLE_10_START;
                    end if;

                when S_DOUBLE_10_START =>
                    current_state <= S_DOUBLE_10_WAIT;
                when S_DOUBLE_10_WAIT  =>
                    if addsub2_done = '1' then
                        current_state <= S_FINISH;
                    end if;

                when others =>
                    current_state <= S_FINISH;

            end case;
        end if;
    end process;

    -- Assign outputs
    ecR <= ecR_reg;

end rtl;
