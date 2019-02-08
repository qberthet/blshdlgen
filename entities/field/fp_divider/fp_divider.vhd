----------------------------------------------------------------------------
-- Plus minus algorithm for modular divison (fp_divider.vhd)
--
-- FIXME: in some case, the prime modulus P in returned instead of 0
--        Small hack implemented to avoid that, but root cause not yet
--        identified
--
-- Constants used:
--   c_P
--
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.domain_param_pkg.all;

entity fp_divider is
    port(
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fp_element;
        y:     in  Fp_element;
        z:     out Fp_element
    );
end fp_divider;

architecture rtl of fp_divider is

    constant K: natural := c_P'length;

    -- LOGK = log2(k)+1 bits for representing integers between -k and k
    constant LOGK:       natural := natural(ceil(log2(real(K)))) + 1;

    constant P_LONG:     std_logic_vector(K   downto 0)    := "0" & c_P;
    constant MINUS_P:    std_logic_vector(K+1 downto 0)    := std_logic_vector( unsigned('1' & not P_LONG) + 1 );
    constant TWO_P:      std_logic_vector(K+1 downto 0)    := P_LONG & '0';
    constant ZERO:       std_logic_vector(K downto 0)      := (others => '0');
    constant SHORT_ZERO: std_logic_vector(LOGK-1 downto 0) := (others => '0');
    constant MINUS_ONE:  std_logic_vector(LOGK downto 0)   := std_logic_vector(to_signed(-1, LOGK+1));
    constant MINUS_TWO:  std_logic_vector(LOGK downto 0)   := std_logic_vector(to_signed(-2, LOGK+1));

    -- Pre-compute pp1
    function comp_pp1 (
        prime : in std_logic_vector
    )
    return std_logic_vector is
        variable result    : std_logic_vector(prime'left + 1 downto 0);
        constant module    : unsigned := to_unsigned(4, prime'length + 2);
    begin
        if unsigned(prime) mod module = to_unsigned(3, prime'length + 2) then
            result := prime(k) & prime;
        elsif unsigned(prime) mod module = to_unsigned(1, prime'length + 2) then
            result := MINUS_P;
        else
            report "Invalid prime, must be 1 or 3 mod 4" severity failure;
        end if;
        return result;
    end;

    -- Pre-compute pp3
    function comp_pp3 (
        prime : in std_logic_vector
    )
    return std_logic_vector is
        variable result    : std_logic_vector(prime'left + 1 downto 0);
        constant module    : unsigned := to_unsigned(4, prime'length + 2);
    begin
        if unsigned(prime) mod module = to_unsigned(3, prime'length + 2) then
            result := MINUS_P;
        elsif unsigned(c_P) mod module = to_unsigned(1, prime'length + 2) then
            result := prime(k) & prime;
        else
            report "Invalid prime, must be 1 or 3 mod 4" severity failure;
        end if;
        return result;
    end;

    constant pp1:          std_logic_vector(K+1 downto 0) := comp_pp1(P_LONG);
    constant pp3:          std_logic_vector(K+1 downto 0) := comp_pp3(P_LONG);

    signal x_reg:          std_logic_vector(K-1 downto 0);
    signal y_reg:          std_logic_vector(K-1 downto 0);

    signal a:              std_logic_vector(K downto 0);
    signal b:              std_logic_vector(K downto 0);
    signal c:              std_logic_vector(K downto 0);
    signal d:              std_logic_vector(K downto 0);
    signal next_a:         std_logic_vector(K downto 0);
    signal next_b:         std_logic_vector(K downto 0);
    signal next_c:         std_logic_vector(K downto 0);
    signal next_d:         std_logic_vector(K downto 0);
    signal half_a:         std_logic_vector(K downto 0);
    signal half_b:         std_logic_vector(K downto 0);
    signal sum_ab:         std_logic_vector(K downto 0);
    signal half_sum_ab:    std_logic_vector(K downto 0);
    signal aa:             std_logic_vector(K downto 0);
    signal cc:             std_logic_vector(K downto 0);
    signal dd:             std_logic_vector(K downto 0);
    signal sum_cd:         std_logic_vector(K+1 downto 0);
    signal pp:             std_logic_vector(K+1 downto 0);
    signal corrected_sum:  std_logic_vector(K+2 downto 0);
    signal oper:           std_logic_vector(1 downto 0);
    signal sel_bd:         std_logic_vector(1 downto 0);
    signal sel_corr:       std_logic_vector(1 downto 0);
    signal sel_dif:        std_logic_vector(1 downto 0);
    signal sel_min:        std_logic_vector(1 downto 0);
    signal s:              std_logic_vector(1 downto 0);
    signal sel_ac:         std_logic;
    signal lastb:          std_logic;
    signal firstb:         std_logic;
    signal oper_dif:       std_logic;
    signal ce_ac:          std_logic;
    signal ce_bd:          std_logic;
    signal b_4:            std_logic;
    signal b_2:            std_logic;
    signal b_plus_a:       std_logic;
    signal dif_neg:        std_logic;
    signal dif_zero:       std_logic;
    signal dif_neg_zero:   std_logic;
    signal dif_one:        std_logic;
    signal cond:           std_logic;
    signal min_zero:       std_logic;
    signal min_zero_neg:   std_logic;
    signal dif:            std_logic_vector(LOGK downto 0);
    signal min:            std_logic_vector(LOGK downto 0);
    signal next_dif:       std_logic_vector(LOGK downto 0);
    signal next_min:       std_logic_vector(LOGK downto 0);
    signal d1:             std_logic_vector(LOGK downto 0);
    signal d2:             std_logic_vector(LOGK downto 0);
    signal m1:             std_logic_vector(LOGK downto 0);
    signal m2:             std_logic_vector(LOGK downto 0);

    type states is range 0 to 4;
    signal current_state: states;

begin

    half_b <= b(K) & b(K downto 1);
    half_a <= a(K) & a(K downto 1);

    gates1: for i in 0 to K generate
        aa(i) <= (oper(1) and (oper(0) xor half_a(i)));
    end generate;

    sum_ab <= std_logic_vector( signed(half_b) + signed(aa) + signed'('0' & oper(1)));

    half_sum_ab <= sum_ab(K) & sum_ab(K downto 1);

    with sel_bd select next_b <= '0' & y_reg when "00",
                                 sum_ab      when "01",
                                 half_sum_ab when others;

    gates2: for i in 0 to k generate
        dd(i) <= lastb and d(i);
        cc(i) <= (oper(1) and (oper(0) xor c(i)));
    end generate;

    sum_cd <= std_logic_vector( signed(dd(k) & dd) + signed((cc(k) & cc)) + signed'('0' & oper(0)) );

    with sel_corr select pp <= '0' & ZERO when "00",
                               pp1        when "01",
                               TWO_P      when "10",
                               pp3        when others;

    corrected_sum <= std_logic_vector( signed(sum_cd(K+1) & sum_cd) + signed ((pp(K+1) & pp)) );

    -- FIXME here is the hack mentioned in header
    --z <= corrected_sum(K-1 downto 0);
    with corrected_sum(K-1 downto 0) select z <= (others=>'0')               when c_P,
                                                 corrected_sum(K-1 downto 0) when others;

    with sel_bd select next_d <= '0' & x_reg                 when "00",
                                 corrected_sum(K+1 downto 1) when "01",
                                 corrected_sum(K+2 downto 2) when others;

    with sel_ac select next_a <= P_LONG    when '0', b when others;
    with sel_ac select next_c <= ZERO when '0', d when others;
    with sel_dif select d1 <= '0' & SHORT_ZERO when "00",
                              MINUS_ONE        when "01",
                              MINUS_TWO        when others;

    gates3: for i in 0 to LOGK generate
        d2(i) <= firstb and dif(i);
    end generate;

    with oper_dif select next_dif <= std_logic_vector(signed(d1) + signed(d2)) when '0',
                                     std_logic_vector(signed(d1) - signed(d2)) when others;
    with sel_min select m1 <= '0' & SHORT_ZERO when "00",
                              MINUS_ONE        when "01",
                              MINUS_TWO        when others;

    m2 <= std_logic_vector(signed(m1) + signed(min));

    with firstb select next_min <= std_logic_vector(to_signed(K, LOGK+1)) when '0',
                                   m2                                     when others;

    registers_xy: process(clk,reset)
    begin
        if reset = '1' then
            x_reg <= (others=>'0');
            y_reg <= (others=>'0');
        elsif rising_edge(clk) then
            if current_state = 1 and start = '1' then
                x_reg <= x;
                y_reg <= y;
            end if;
        end if;
    end process registers_xy;

    registers_ac: process(clk,reset)
    begin
        if reset = '1' then
            a <= (others=>'0');
            c <= (others=>'0');
        elsif rising_edge(clk) then
            if ce_ac = '1' then
                a <= next_a;
                c <= next_c;
            end if;
        end if;
    end process registers_ac;

    registers_bd: process(clk,reset)
    begin
        if reset = '1' then
            b <= (others=>'0');
            d <= (others=>'0');
        elsif rising_edge(clk) then
            if ce_bd = '1' then
                b <= next_b;
                d <= next_d;
            end if;
        end if;
    end process registers_bd;

    registers_md: process(clk,reset)
    begin
        if reset = '1' then
            min <= (others=>'0');
            dif <= (others=>'0');
        elsif rising_edge(clk) then
            min <= next_min;
            dif <= next_dif;
        end if;
    end process registers_md;

    --flag generation
    b_4          <= b(1) or b(0);
    b_2          <= b(0);
    s            <= std_logic_vector(unsigned(a(1 downto 0)) + unsigned(b(1 downto 0)));
    b_plus_a     <= s(1) or s(0);
    dif_neg      <= dif(LOGK);
    cond         <= '1' when dif(LOGK downto 1) = SHORT_ZERO else '0';
    dif_zero     <= cond and not(dif(0));
    dif_one      <= cond and dif(0);
    dif_neg_zero <= dif_neg or dif_zero;
    min_zero     <= '1' when min = '0' & SHORT_ZERO else '0';
    min_zero_neg <= min_zero or min(LOGK);

    seq_unit: process(all)
    begin
        case current_state is
            when 0 to 1 =>
                oper     <= '1' & a(k);
                sel_bd   <= "00";
                sel_corr <= '0' & (a(k) xor c(k));
                sel_dif  <= "00";
                sel_min  <= "00";
                sel_ac   <= '0';
                lastb    <= '0';
                firstb   <= '1';
                oper_dif <= '0';
                ce_ac    <= '0';
                ce_bd    <= '0';
                done     <= '1';
            when 2 =>
                oper     <= "00";
                sel_bd   <= "00";
                sel_corr <= "00";
                sel_dif  <= "00";
                sel_min  <= "00";
                sel_ac   <= '0';
                lastb    <= '1';
                firstb   <= '0';
                oper_dif <= '0';
                ce_ac    <= '1';
                ce_bd    <= '1';
                done     <= '0';
            when 3 =>
                if (min_zero_neg ='1') then
                    oper     <= '1' & a(k);
                    sel_bd   <= "00";
                    sel_corr <= '0' & (a(k) xor c(k));
                    sel_dif  <= "00";
                    sel_min  <= "00";
                    sel_ac   <= '0';
                    lastb    <= '0';
                    firstb   <= '1';
                    oper_dif <= '0';
                    ce_ac    <= '0';
                    ce_bd    <= '0';
                    done     <= '0';
                elsif (b_4 = '0') then
                    if (dif_neg_zero = '1') then
                        oper     <= "00";
                        sel_bd   <= "10";
                        sel_corr <= d(1 downto 0);
                        sel_dif  <= "10";
                        sel_min  <= "10";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    elsif (dif_one = '1') then
                        oper     <= "00";
                        sel_bd   <= "10";
                        sel_corr <= d(1 downto 0);
                        sel_dif  <= "10";
                        sel_min  <= "01";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    else
                        oper     <= "00";
                        sel_bd   <= "10";
                        sel_corr <= d(1 downto 0);
                        sel_dif  <= "10";
                        sel_min  <= "00";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    end if;
                elsif (b_2 = '0') then
                    if (dif_neg_zero = '1') then
                        oper     <= "00";
                        sel_bd   <= "01";
                        sel_corr <= '0' & d(0);
                        sel_dif  <= "01";
                        sel_min  <= "01";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    else
                        oper     <= "00";
                        sel_bd   <= "01";
                        sel_corr <= '0' & d(0);
                        sel_dif  <= "01";
                        sel_min  <= "00";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    end if;
                elsif (b_plus_a = '0') then
                    if (dif_neg = '1') then
                        oper     <= "10";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "00";
                        sel_ac   <= '1';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '1';
                        ce_ac    <= '1';
                        ce_bd    <= '1';
                        done     <= '0';
                    elsif (dif_zero = '1') then
                        oper     <= "10";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "01";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    else
                        oper     <= "10";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "00";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    end if;
                else
                    if (dif_neg = '1') then
                        oper     <= "11";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "00";
                        sel_ac   <= '1';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '1';
                        ce_ac    <= '1';
                        ce_bd    <= '1';
                        done     <= '0';
                    elsif (dif_zero = '1') then
                        oper     <= "11";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "01";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    else
                        oper     <= "11";
                        sel_bd   <= "10";
                        sel_corr <= sum_cd(1 downto 0);
                        sel_dif  <= "01";
                        sel_min  <= "00";
                        sel_ac   <= '0';
                        lastb    <= '1';
                        firstb   <= '1';
                        oper_dif <= '0';
                        ce_ac    <= '0';
                        ce_bd    <= '1';
                        done     <= '0';
                    end if;
                end if;
            when 4 =>
                oper     <= '1' & a(k);
                sel_bd   <= "00";
                sel_corr <= '0' & (a(k) xor c(k));
                sel_dif  <= "00";
                sel_min  <= "00";
                sel_ac   <= '0';
                lastb    <= '0';
                firstb   <= '1';
                oper_dif <= '0';
                ce_ac    <= '0';
                ce_bd    <= '0';
                done     <= '0';
        end case;
    end process;

    control_unit: process(clk,reset)
    begin
        if reset = '1' then
            current_state <= 0;
        elsif rising_edge(clk) then
            case current_state is
                when 0 =>
                    if start = '0' then
                        current_state <= 1;
                    end if;
                when 1 =>
                    if start = '1' then
                        current_state <= 2;
                    end if;
                when 2 =>
                    current_state <= 3;
                when 3 =>
                    if min_zero_neg = '1' then
                        current_state <= 4;
                    end if;
                when 4 =>
                    current_state <= 0;
            end case;
        end if;

    end process;
end rtl;
