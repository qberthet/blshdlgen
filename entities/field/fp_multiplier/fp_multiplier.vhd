-------------------------------------------------------------------------------
-- Algorithm .:
--
-- FIXME Try CSA mod?
--
-- Constants used:
--   c_P
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fp_multiplier is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
end fp_multiplier;

architecture circuit of fp_multiplier is

    -- Pre-compute exp_2k = 2^(2*k) mod p
    -- (k = P'length)
    function f_exp_2k (
        module : in unsigned
    )
    return unsigned is
        variable power     : unsigned(module'length*2 downto 0);
        variable result    : unsigned(module'range);
    begin
        power := (others => '0');
        power(power'left) := '1';
        result := power mod module;
        return result(module'range);
    end;

    constant EXP_2K: unsigned(c_P'range) := f_exp_2k(unsigned(c_P));

    component fp_montgomery_product is
    port (
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
    end component fp_montgomery_product;

    type state_t is (S_FINISH, S_IDLE, S_MTP1_START, S_MTP1_WAIT, S_MTP2_START, S_MTP2_WAIT);
    signal current_state: state_t;

    signal mtp_done:  std_logic;
    signal mtp_start: std_logic;

    signal z_reg:     Fp_element;

    signal mtp_x:     Fp_element;
    signal mtp_y:     Fp_element;
    signal mtp_z:     Fp_element;

begin

    fp_montgomery_product_i : entity work.fp_montgomery_product
    port map (
        clk   => clk,
        reset => reset,
        start => mtp_start,
        done  => mtp_done,
        x     => mtp_x,
        y     => mtp_y,
        z     => mtp_z
    );

    fp_montgomery_product_routing: process(all)
    begin
        case current_state is
            when S_MTP1_START to S_MTP1_WAIT   => mtp_x <= x;     mtp_y <= y;
            when others                        => mtp_x <= mtp_z; mtp_y <= std_logic_vector(EXP_2K);
        end case;
    end process fp_montgomery_product_routing;

    seq_unit: process(all)
    begin
        case current_state is
            when S_FINISH to S_IDLE  => mtp_start <= '0'; done <= '1'; -- Wait start
            when S_MTP1_START        => mtp_start <= '1'; done <= '0';
            when S_MTP2_START        => mtp_start <= '1'; done <= '0';
            when others              => mtp_start <= '0'; done <= '0';
        end case;
    end process;

    control_unit: process(clk, reset)
    begin
        if reset = '1' then
            current_state <= S_IDLE;
            z_reg <= (others=>'0');
        elsif rising_edge(clk) then
            z_reg <= z_reg;
            case current_state is

                when S_FINISH => -- Wait start low
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                when S_IDLE => -- Wait start high
                    if start = '1' then
                        current_state <= S_MTP1_START;
                    end if;

                when S_MTP1_START =>
                    current_state <= S_MTP1_WAIT;
                when S_MTP1_WAIT =>
                    if mtp_done = '1' then
                        current_state <= S_MTP2_START;
                    end if;

                when S_MTP2_START =>
                    current_state <= S_MTP2_WAIT;
                when S_MTP2_WAIT =>
                    if mtp_done = '1' then
                        current_state <= S_FINISH;
                        z_reg <= mtp_z;
                    end if;

            end case;
        end if;
    end process;

    z <= z_reg;

end circuit;