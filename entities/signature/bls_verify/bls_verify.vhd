library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity bls_verify is
    port (
        clk:        in  std_logic;
        reset:      in  std_logic;
        done:       out std_logic;
        src_ready:  in  std_logic;
        src_read:   out std_logic;
        signature:  in  compr_ec1_point;
        pkey:       in  compr_ec1_point;
        din:        in  std_logic_vector(64-1 downto 0);
        sign_valid: out std_logic
    );
end bls_verify;

architecture circuit of bls_verify is

    component efp_point_decompressor is
        port (
            clk:       in  std_logic;
            reset:     in  std_logic;
            start:     in  std_logic;
            done:      out std_logic;
            comp_ecP:  in  compr_ec1_point;
            ecP:       out ec1_point
        );
    end component;

    component map_to_point is
        port (
            clk:       in  std_logic;
            reset:     in  std_logic;
            src_ready: in  std_logic;
            src_read:  out std_logic;
            din:       in  std_logic_vector(64-1 downto 0);
            done:      out std_logic;
            ecR:       out ec1_point
        );
    end component;

    component twisted_weil is
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            ecP:   in  ec1_point;
            ecQ:   in  ec1_point;
            n:     in  std_logic_vector;
            r:     out Fpm_element;
            done:  out std_logic
        );
    end component;

    signal dec_start:  std_logic;
    signal dec_done:   std_logic;
    signal comp_ecP:   compr_ec1_point;
    signal dec_ecP:    ec1_point;

    signal mtp_done:   std_logic;
    signal mtp_ecR:    ec1_point;

    signal pair_start: std_logic;
    signal pair_done:  std_logic;
    signal pair_ecP:   ec1_point;
    signal pair_ecQ:   ec1_point;
    signal pair_r:     Fpm_element;

    signal pairing_1_r: Fpm_element;

    signal sig_valid_r: std_logic;

    type state_t is (
        S_FINISH,
        S_IDLE,
        S_MTP_START,
        S_MTP_WAIT,
        S_DEC1_START,
        S_DEC1_WAIT,
        S_PAIR1_START,
        S_PAIR1_WAIT,
        S_DEC2_START,
        S_DEC2_WAIT,
        S_PAIR2_START,
        S_PAIR2_WAIT
    );
    signal current_state: state_t;

begin

    efp_point_decompressor_i: entity work.efp_point_decompressor
    port map (
        clk      => clk,
        reset    => reset,
        start    => dec_start,
        done     => dec_done,
        comp_ecP => comp_ecP,
        ecP      => dec_ecP
    );

    efp_point_decompressor_routing: process(all)
    begin
        case current_state is
            when S_DEC1_START to S_PAIR1_WAIT => comp_ecP <= signature;
            when others                       => comp_ecP <= pkey;
        end case;
    end process efp_point_decompressor_routing;

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

    twisted_weil_i: entity work.twisted_weil
    port map (
        clk   => clk,
        reset => reset,
        start => pair_start,
        ecP   => pair_ecP,
        ecQ   => pair_ecQ,
        n     => c_E1_G_n, -- Generator order
        r     => pair_r,
        done  => pair_done
    );

    twisted_weil_routing: process(all)
    begin
        case current_state is
            when S_DEC1_START to S_PAIR1_WAIT => pair_ecP <= c_E1_G;  pair_ecQ <= dec_ecP; -- generator and sig
            when others                       => pair_ecP <= dec_ecP; pair_ecQ <= mtp_ecR; -- public key and data point
        end case;
    end process twisted_weil_routing;

    -- Register pairing 1 result
    process(clk, reset)
    begin
        if reset='1' then
            pairing_1_r <= (others=>(others=>'0'));
        elsif rising_edge(clk) then
            pairing_1_r <= pairing_1_r;
            if current_state = S_PAIR1_WAIT and pair_done = '1' then
                pairing_1_r <= pair_r;
            end if;
        end if;
    end process;

    -- Signature valid register
    process(clk, reset)
    begin
        if reset='1' then
            sig_valid_r <= '0';
        elsif rising_edge(clk) then
            sig_valid_r <= sig_valid_r;
            if current_state = S_MTP_START then
                -- Verification start, clear signature valid register
                sig_valid_r <= '0';
            elsif current_state = S_PAIR2_WAIT and pair_done = '1' then
                if pairing_1_r = pair_r then
                    -- Pairing matches, signature valid
                    sig_valid_r <= '1';
                else
                    -- Pairing mismatches, signature invalid
                    sig_valid_r <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Assign output
    sign_valid <= sig_valid_r;

    process(all)
    begin
        -- Start the different computations based on current state
        case current_state is
            when S_FINISH      => pair_start <= '0'; dec_start <= '0'; done <= '1';
            when S_IDLE        => pair_start <= '0'; dec_start <= '0'; done <= '1';
            when S_DEC1_START  => pair_start <= '0'; dec_start <= '1'; done <= '0';
            when S_PAIR1_START => pair_start <= '1'; dec_start <= '0'; done <= '0';
            when S_DEC2_START  => pair_start <= '0'; dec_start <= '1'; done <= '0';
            when S_PAIR2_START => pair_start <= '1'; dec_start <= '0'; done <= '0';
            when others        => pair_start <= '0'; dec_start <= '0'; done <= '0';
        end case;
    end process;

    process(clk, reset)
    begin
        if reset='1' then
            current_state <= S_IDLE;
        elsif rising_edge(clk) then
            case current_state is

                when S_FINISH =>
                    current_state <= S_IDLE;

                when S_IDLE =>   -- Wait start high
                    if src_ready = '0' then
                        current_state <= S_MTP_START;
                    end if;

                when S_MTP_START =>
                    current_state <= S_MTP_WAIT;
                when S_MTP_WAIT =>
                    if mtp_done = '1' then
                        current_state <= S_DEC1_START;
                    end if;

                when S_DEC1_START =>
                    current_state <= S_DEC1_WAIT;
                when S_DEC1_WAIT =>
                    if dec_done = '1' then
                        current_state <= S_PAIR1_START;
                    end if;

                when S_PAIR1_START =>
                    current_state <= S_PAIR1_WAIT;
                when S_PAIR1_WAIT =>
                    if pair_done = '1' then
                        current_state <= S_DEC2_START;
                    end if;

                when S_DEC2_START =>
                    current_state <= S_DEC2_WAIT;
                when S_DEC2_WAIT =>
                    if dec_done = '1' then
                        current_state <= S_PAIR2_START;
                    end if;

                when S_PAIR2_START =>
                    current_state <= S_PAIR2_WAIT;
                when S_PAIR2_WAIT =>
                    if pair_done = '1' then
                        current_state <= S_FINISH;
                    end if;

            end case;
        end if;

    end process;

end circuit;
