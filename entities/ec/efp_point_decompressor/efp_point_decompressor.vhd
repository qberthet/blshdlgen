-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity efp_point_decompressor is
    port (
        clk:       in  std_logic;
        reset:     in  std_logic;
        start:     in  std_logic;
        done:      out std_logic;
        comp_ecP:  in  compr_ec1_point;
        ecP:       out ec1_point
    );
end efp_point_decompressor;

architecture circuit of efp_point_decompressor is

    component fp_multiplier is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  std_logic_vector;
            y:     in  std_logic_vector;
            z:     out std_logic_vector
        );
    end component;

    component fp_adder is
        port (
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  std_logic_vector;
            y:        in  std_logic_vector;
            z:        out std_logic_vector
        );
    end component;

    component fp_square_rooter is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  std_logic_vector;
            z1:    out std_logic_vector;
            z2:    out std_logic_vector
        );
    end component;

    signal suffix:     std_logic;
    signal half_p:     std_logic_vector(c_P'range);
    signal x_coord:    std_logic_vector(c_P'range);

    signal mul_start:  std_logic;
    signal mul_done:   std_logic;
    signal mul_y:      std_logic_vector(c_P'range);
    signal mul_z:      std_logic_vector(c_P'range);

    signal add_start:  std_logic;
    signal add_done:   std_logic;
    signal add_z:      std_logic_vector(c_P'range);

    signal sqrt_start: std_logic;
    signal sqrt_done:  std_logic;
    signal sqrt_x:     std_logic_vector(c_P'range);
    signal sqrt_z1:    std_logic_vector(c_P'range);
    signal sqrt_z2:    std_logic_vector(c_P'range);

    type state_t is (
        S_FINISH,
        S_IDLE,
        S_MUL1_START,
        S_MUL1_WAIT,
        S_MUL2_START,
        S_MUL2_WAIT,
        S_ADD_START,
        S_ADD_WAIT,
        S_SQRT_START,
        S_SQRT_WAIT
    );
    signal current_state: state_t;

begin

    -- Half P by shifting
    half_p <= "0" & c_P(c_P'length-1 downto 1);

    suffix <= comp_ecP(0);
    x_coord <= comp_ecP(c_P'length downto 1);

    fp_multiplier_i: entity work.fp_multiplier
    port map(
        clk   => clk,
        reset => reset,
        start => mul_start,
        done  => mul_done,
        x     => x_coord,
        y     => mul_y,
        z     => mul_z
    );

    fp_multiplier_routing: process(all)
    begin
        case current_state is
            when S_MUL1_START to S_MUL1_WAIT => mul_y <= x_coord;
            when others                      => mul_y <= mul_z;
        end case;
    end process fp_multiplier_routing;

    fp_adder_i: entity work.fp_adder
    port map (
        clk      => clk,
        reset    => reset,
        start    => add_start,
        done     => add_done,
        x        => mul_z,
        y        => c_FP_TREE,
        z        => add_z
    );

    fp_square_rooter_i: entity work.fp_square_rooter
    port map (
        clk   => clk,
        reset => reset,
        start => sqrt_start,
        done  => sqrt_done,
        x     => add_z,
        z1    => sqrt_z1,
        z2    => sqrt_z2
    );

    seq_unit: process(all)
    begin
        -- Start the different computations based on current state
        case current_state is
            when S_FINISH     => mul_start <= '0'; add_start <= '0'; sqrt_start <= '0'; done <= '1';
            when S_IDLE       => mul_start <= '0'; add_start <= '0'; sqrt_start <= '0'; done <= '1';
            when S_MUL1_START => mul_start <= '1'; add_start <= '0'; sqrt_start <= '0'; done <= '0';
            when S_MUL2_START => mul_start <= '1'; add_start <= '0'; sqrt_start <= '0'; done <= '0';
            when S_ADD_START  => mul_start <= '0'; add_start <= '1'; sqrt_start <= '0'; done <= '0';
            when S_SQRT_START => mul_start <= '0'; add_start <= '0'; sqrt_start <= '1'; done <= '0';
            when others       => mul_start <= '0'; add_start <= '0'; sqrt_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset='1' then
            current_state <= S_IDLE;
        elsif rising_edge(clk) then

            case current_state is
                when S_FINISH => -- Wait start low
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;

                when S_IDLE =>   -- Wait start high
                    if start = '1' then
                        current_state <= S_MUL1_START;
                    end if;

                when S_MUL1_START =>
                    current_state <= S_MUL1_WAIT;
                when S_MUL1_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_MUL2_START;
                    end if;

                when S_MUL2_START =>
                    current_state <= S_MUL2_WAIT;
                when S_MUL2_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_ADD_START;
                    end if;

                when S_ADD_START =>
                    current_state <= S_ADD_WAIT;
                when S_ADD_WAIT =>
                    if add_done = '1' then
                        current_state <= S_SQRT_START;
                    end if;

                when S_SQRT_START =>
                    current_state <= S_SQRT_WAIT;
                when S_SQRT_WAIT =>
                    if sqrt_done = '1' then
                        current_state <= S_FINISH;
                    end if;

            end case;
        end if;

    end process;

    ecP.x  <= x_coord;
    ecP.ii <= '0';

    -- Combinatorial process to choose between the two roots depending on
    -- roots values and suffix bit of the compressed signature
    process(all)
    begin
        if unsigned(sqrt_z1) > unsigned(half_p) then
            if comp_ecP(0) = '1' then
                ecP.y <= sqrt_z1;
            else
                ecP.y <= sqrt_z2;
            end if;
        else
            if comp_ecP(0) = '1' then
                ecP.y <= sqrt_z2;
            else
                ecP.y <= sqrt_z1;
            end if;
        end if;
    end process;

end circuit;
