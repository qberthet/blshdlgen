library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity bls_sign is
    port (
        clk:        in  std_logic;
        reset:      in  std_logic;
        src_ready:  in  std_logic;
        src_read:   out std_logic;
        skey:       in  Fp_element;
        done:       out std_logic;
        din:        in  std_logic_vector(64-1 downto 0);
        comp_ecP:   out compr_ec1_point
    );
end bls_sign;

architecture circuit of bls_sign is

    component map_to_point is
        port (
            clk:       in  std_logic;
            reset:     in  std_logic;
            start:     in  std_logic;
            src_ready: in  std_logic;
            src_read:  out std_logic;
            din:       in  std_logic_vector(64-1 downto 0);
            done:      out std_logic;
            ecR:       out ec1_point
        );
    end component;

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

    signal mtp_done:   std_logic;
    signal mtp_ecR:    ec1_point;

    signal pmul_start: std_logic;
    signal pmul_done:  std_logic;
    signal pmul_ecR:   ec1_point;

    signal comp_start: std_logic;
    signal comp_done:  std_logic;

    type state_t is (
        S_FINISH,
        S_IDLE,
        S_MTP_START,
        S_MTP_WAIT,
        S_MUL_START,
        S_MUL_WAIT,
        S_COMP_START,
        S_COMP_WAIT
    );
    signal current_state: state_t;

begin

    map_to_point_i: entity work.map_to_point
    port map (
        clk       => clk,
        reset     => reset,
        src_ready => src_ready,
        src_read  => src_read,
        din       => din,
        done      => mtp_done,
        ecR       => mtp_ecR
    );

    efp_point_multiplier_i: entity work.efp_point_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => pmul_start,
        ecP   => mtp_ecR,
        n     => skey,
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
        comp_ecP => comp_ecP
    );

    seq_unit: process(all)
    begin
        -- Start the different computations based on current state
        case current_state is
            when S_FINISH     => pmul_start <= '0'; comp_start <= '0'; done <= '1';
            when S_IDLE       => pmul_start <= '0'; comp_start <= '0'; done <= '1';
            when S_MUL_START  => pmul_start <= '1'; comp_start <= '0'; done <= '0';
            when S_COMP_START => pmul_start <= '0'; comp_start <= '1'; done <= '0';
            when others       => pmul_start <= '0'; comp_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset='1' then
            current_state <= S_IDLE;
        elsif rising_edge(clk) then
            case current_state is

                when S_FINISH =>
                    current_state <= S_IDLE;

                when S_IDLE =>
                    if src_ready = '0' then
                        current_state <= S_MTP_START;
                    end if;

                when S_MTP_START =>
                    current_state <= S_MTP_WAIT;
                when S_MTP_WAIT =>
                    if mtp_done = '1' then
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
