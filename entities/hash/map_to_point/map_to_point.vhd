--------------------------------------------------------------------------------
-- c_FP_TWO
-- c_MTP_EXP
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;
use work.keccak_pkg.all;
use work.sha3_pkg.all;

entity map_to_point is
    port (
        clk:       in  std_logic;
        reset:     in  std_logic;
        src_ready: in  std_logic;
        src_read:  out std_logic;
        din:       in  std_logic_vector(64-1 downto 0);
        done:      out std_logic;
        ecR:       out ec1_point
    );
end map_to_point;

architecture circuit of map_to_point is

    component keccak_top is
        port (
            rst:       in  std_logic;
            clk:       in  std_logic;
            src_ready: in  std_logic;
            src_read:  out std_logic;
            dst_ready: in  std_logic;
            dst_write: out std_logic;
            din:       in  std_logic_vector(w-1 downto 0);
            dout:      out std_logic_vector(w-1 downto 0)
        );
    end component;

    component fp_reducer is
        generic (
            c_LENGTH: natural := c_N
        );
        port (
            clk:   in  std_logic;
            reset: in  std_logic;
            start: in  std_logic;
            done:  out std_logic;
            x:     in  std_logic_vector(c_LENGTH-1 downto 0);
            y:     in  Fp_element;
            z:     out Fp_element
        );
    end component;

    -- Used as squarer
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

    component fp_subtractor is
        port (
            clk:      in  std_logic;
            reset:    in  std_logic;
            start:    in  std_logic;
            done:     out std_logic;
            x:        in  Fp_element;
            y:        in  Fp_element;
            z:        out Fp_element
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

    signal hash_r:       std_logic_vector(512-1 downto 0);
    signal hash_out:     std_logic_vector(64-1 downto 0);
    signal hash_count:   unsigned(2 downto 0);

    signal dst_write:    std_logic;
    signal dst_ready:    std_logic;

    signal reduce_start: std_logic;
    signal reduce_done:  std_logic;
    signal reduce_z:     Fp_element;

    signal mul_start: std_logic;
    signal mul_done:  std_logic;
    signal mul_z:     Fp_element;

    signal addsub_start: std_logic;
    signal addsub_done:  std_logic;
    signal addsub_z:     Fp_element;

    signal exp_start:    std_logic;
    signal exp_done:     std_logic;
    signal exp_z:        Fp_element;

    signal pmul_start: std_logic;
    signal pmul_done:  std_logic;
    signal pmul_P:     ec1_point;

    type state_t is (
        S_FINISH,
        S_IDLE,
        S_HASHING,
        S_REDUCE_START,
        S_REDUCE_WAIT,
        S_SQUARE_START,
        S_SQUARE_WAIT,
        S_SUB_START,
        S_SUB_WAIT,
        S_EXP2_START,
        S_EXP2_WAIT,
        S_PMUL_START,
        S_PMUL_WAIT
    );
    signal current_state: state_t;

begin

    keccak_top_i: entity work.Keccak_top
    generic map (
        HS        => HASH_SIZE_512
    )
    port map (
        rst       => reset,
        clk       => clk,
        src_ready => src_ready,
        src_read  => src_read,
        dst_ready => dst_ready,
        dst_write => dst_write,
        din       => din,
        dout      => hash_out
    );

    with current_state select dst_ready <= '0' when S_HASHING, '1' when others;

    -- Register hash output:
    --   Keccak ip output hash result by 64bits chunk, but we need it in one
    --   register to map it to a curve point.
    process(clk, reset)
    begin
        if reset = '1' then
            hash_r <= (others => '0');
            hash_count <= to_unsigned(0, hash_count'length);
        elsif rising_edge(clk) then
            hash_r <= hash_r;
            if dst_write = '1' then
                case hash_count is
                    when to_unsigned(0, hash_count'length) => hash_r(511 downto 448) <= hash_out;
                    when to_unsigned(1, hash_count'length) => hash_r(447 downto 384) <= hash_out;
                    when to_unsigned(2, hash_count'length) => hash_r(383 downto 320) <= hash_out;
                    when to_unsigned(3, hash_count'length) => hash_r(319 downto 256) <= hash_out;
                    when to_unsigned(4, hash_count'length) => hash_r(255 downto 192) <= hash_out;
                    when to_unsigned(5, hash_count'length) => hash_r(191 downto 128) <= hash_out;
                    when to_unsigned(6, hash_count'length) => hash_r(127 downto 64)  <= hash_out;
                    when to_unsigned(7, hash_count'length) => hash_r( 63 downto 0)   <= hash_out;
                    when others => null;
                end case;
                hash_count <= hash_count + 1;
            end if;
        end if;
    end process;

    fp_reducer_i: entity work.fp_reducer
    generic map (
        c_LENGTH => 512
    )
    port map (
        clk   => clk,
        reset => reset,
        start => reduce_start,
        done  => reduce_done,
        x     => hash_r,
        y     => c_P,
        z     => reduce_z
    );

    -- Used as squarer
    fp_multiplier_i: entity work.fp_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => mul_start,
        done  => mul_done,
        x     => reduce_z,
        y     => reduce_z,
        z     => mul_z
    );

    fp_subtractor_i: entity work.fp_subtractor
    port map (
        clk      => clk,
        reset    => reset,
        start    => addsub_start,
        done     => addsub_done,
        x        => mul_z,
        y        => c_E1_A6, -- B
        z        => addsub_z
    );

    fp_exponentiator_i: entity work.fp_exponentiator
    port map(
        clk   => clk,
        reset => reset,
        start => exp_start,
        done  => exp_done,
        x     => c_MTP_EXP,
        y     => addsub_z,
        z     => exp_z
    );

    pmul_P.x  <= exp_z;
    pmul_P.y  <= reduce_z;
    pmul_P.ii <= '0';

    efp_point_multiplier_i: entity work.efp_point_multiplier
    port map (
        clk   => clk,
        reset => reset,
        start => pmul_start,
        ecP   => pmul_P,
        n     => c_C,
        ecR   => ecR,
        done  => pmul_done
    );

    seq_unit: process(all)
    begin
        -- Start the different computations based on current state
        case current_state is
            when S_FINISH       => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '0'; done <= '1';
            when S_IDLE         => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '0'; done <= '1';
            when S_REDUCE_START => reduce_start <= '1'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '0'; done <= '0';
            when S_SQUARE_START => reduce_start <= '0'; mul_start <= '1'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '0'; done <= '0';
            when S_SUB_START    => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '1'; exp_start <= '0'; pmul_start <= '0'; done <= '0';
            when S_EXP2_START   => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '1'; pmul_start <= '0'; done <= '0';
            when S_PMUL_START   => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '1'; done <= '0';
            when others         => reduce_start <= '0'; mul_start <= '0'; addsub_start <= '0'; exp_start <= '0'; pmul_start <= '0'; done <= '0';
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
                        current_state <= S_HASHING;
                    end if;

                when S_HASHING =>
                    if hash_count = to_unsigned(7, hash_count'length) and dst_write = '1' then
                        current_state <= S_REDUCE_START;
                    end if;

                when S_REDUCE_START =>
                    current_state <= S_REDUCE_WAIT;
                when S_REDUCE_WAIT =>
                    if reduce_done = '1' then
                        current_state <= S_SQUARE_START;
                    end if;

                when S_SQUARE_START =>
                    current_state <= S_SQUARE_WAIT;
                when S_SQUARE_WAIT =>
                    if mul_done = '1' then
                        current_state <= S_SUB_START;
                    end if;

                when S_SUB_START =>
                    current_state <= S_SUB_WAIT;
                when S_SUB_WAIT =>
                    if addsub_done = '1' then
                        current_state <= S_EXP2_START;
                    end if;

                when S_EXP2_START =>
                    current_state <= S_EXP2_WAIT;
                when S_EXP2_WAIT =>
                    if exp_done = '1' then
                        current_state <= S_PMUL_START;
                    end if;

                when S_PMUL_START =>
                    current_state <= S_PMUL_WAIT;
                when S_PMUL_WAIT =>
                    if pmul_done = '1' then
                        current_state <= S_FINISH;
                    end if;

            end case;
        end if;

    end process;

end circuit;
