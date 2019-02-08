-- Constants used:
--   c_FP_ZERO
--   c_FP_INV_FOUR
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fp_square_rooter is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        z1:    out Fp_element;
        z2:    out Fp_element
    );
end fp_square_rooter;

architecture circuit of fp_square_rooter is

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

    component fp_exponentiator is
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

    signal z1_temp: Fp_element;

    signal sub_start: std_logic;
    signal sub_done:  std_logic;

    signal exp_start: std_logic;
    signal exp_done:  std_logic;

    type states is (
        S_FINISH,
        S_IDLE,
        S_EXP_START,
        S_EXP_WAIT,
        S_SUB_START,
        S_SUB_WAIT
    );
    signal current_state: states;

begin

    fp_exponentiator_i: entity work.fp_exponentiator
    port map (
        clk   => clk,
        reset => reset,
        start => exp_start,
        done  => exp_done,
        x     => c_FP_INV_FOUR,
        y     => x,
        z     => z1_temp
    );

    fp_subtractor_i: entity work.fp_subtractor
    port map (
        clk   => clk,
        reset => reset,
        start => sub_start,
        done  => sub_done,
        x     => c_FP_ZERO,
        y     => z1_temp,
        z     => z2
    );

    z1 <= z1_temp;

    seq_unit: process(all)
    begin
        case current_state is
            when S_FINISH    => sub_start <= '0'; exp_start <= '0'; done <= '1';
            when S_IDLE      => sub_start <= '0'; exp_start <= '0'; done <= '1';
            when S_EXP_START => sub_start <= '0'; exp_start <= '1'; done <= '0';
            when S_SUB_START => sub_start <= '1'; exp_start <= '0'; done <= '0';
            when others      => sub_start <= '0'; exp_start <= '0'; done <= '0';
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

                when S_IDLE =>   -- Wait start high
                    if start = '1' then
                        current_state <= S_EXP_START;
                    end if;

                when S_EXP_START =>
                    current_state <= S_EXP_WAIT;

                when S_EXP_WAIT =>
                    if exp_done = '1' then
                        current_state <= S_SUB_START;
                    end if;

                when S_SUB_START =>
                    current_state <= S_SUB_WAIT;

                when S_SUB_WAIT =>
                    if sub_done = '1' then
                        current_state <= S_FINISH;
                    end if;

                when others =>
                    current_state <= S_FINISH;
            end case;
        end if;
    end process;

end circuit;
