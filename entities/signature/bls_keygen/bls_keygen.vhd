library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity bls_keygen is
    port (
        clk:        in  std_logic;
        reset:      in  std_logic;
        start:      in  std_logic;
        random:     in  Fp_element;
        done:       out std_logic;
        skey:       out Fp_element;
        pkey:       out compr_ec1_point
    );
end bls_keygen;

architecture circuit of bls_keygen is

    component efp_point_multiplier is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            ecP:   in  ec1_point;
            n:     in  std_logic_vector(c_P'range);
            ecR:   out ec1_point;
            done:  out std_logic
        );
    end component;

    component efp_point_compressor is
        port (
            clk:       in  std_logic;
            reset:     in  std_logic;
            start:     in  std_logic;
            done:      out std_logic;
            ecP:       in  ec1_point;
            comp_ecP:  out compr_ec1_point
        );
    end component;

    signal pmul_start: std_logic;
    signal pmul_done:  std_logic;
    signal pmul_ecR:   ec1_point;

    signal comp_start: std_logic;
    signal comp_done:  std_logic;

    type state_t is (
        S_FINISH,
        S_IDLE,
        S_MUL_START,
        S_MUL_WAIT,
        S_COMP_START,
        S_COMP_WAIT
    );
    signal current_state: state_t;

begin

    skey <= random;

    efp_point_multiplier_i: entity work.efp_point_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => pmul_start,
        ecP   => c_E1_G, -- Group generator
        n     => random,
        ecR   => pmul_ecR,
        done  => pmul_done
    );

    efp_point_compressor_i: entity work.efp_point_compressor
    port map (
        clk      => clk,
        reset    => reset,
        start    => comp_start,
        done     => comp_done,
        ecP      => pmul_ecR,
        comp_ecP => pkey
    );

    process(clk, reset)
    begin

        -- Start the different computations based on current state
        case current_state is
            when S_FINISH      => pmul_start <= '0'; comp_start <= '0'; done <= '1';
            when S_IDLE        => pmul_start <= '0'; comp_start <= '0'; done <= '1';
            when S_MUL_START   => pmul_start <= '1'; comp_start <= '0'; done <= '0';
            when S_COMP_START  => pmul_start <= '0'; comp_start <= '1'; done <= '0';
            when others        => pmul_start <= '0'; comp_start <= '0'; done <= '0';
        end case;

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
                        current_state <= S_MUL_START;
                    end if;

                when S_MUL_START =>
                    current_state <= S_MUL_WAIT;
                when S_MUL_WAIT =>
                    if pmul_done = '1' then
                        current_state <= S_COMP_START;
                    end if;

                when S_COMP_START =>
                    current_state <= S_COMP_WAIT;
                when S_COMP_WAIT =>
                    if comp_done = '1' then
                        current_state <= S_FINISH;
                    end if;

            end case;
        end if;

    end process;

end circuit;
