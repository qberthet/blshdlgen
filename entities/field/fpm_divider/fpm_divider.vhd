----------------------------------------------------------------------------
-- Pseudo Euclidean Divider (pseudo_Euclidean_Divider.vhd)
--
-- FIXME: optimise parallelization, c.f thread 1&2 in ADA code
--
-- Constants used:
--   c_P
--   c_M
--   c_F
--   c_FP_ZERO
--   c_FPM_ZERO
--
----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.math_real."ceil";
use ieee.math_real."log2";

library work;
use work.domain_param_pkg.all;

entity fpm_divider is
    port(
        clk:   in  std_logic;
        reset: in  std_logic;
        start: in  std_logic;
        done:  out std_logic;
        x:     in  Fpm_element;
        y:     in  Fpm_element;
        z:     out Fpm_element
    );
end fpm_divider;

architecture circuit of fpm_divider is

    constant LOGM: natural := natural(ceil(log2(real(c_M)))) + 1;

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

    signal n_a:        Fpm_element_long;
    signal n_b:        Fpm_element_long;
    signal n_r:        Fpm_element_long;
    signal next_a:     Fpm_element_long;
    signal next_b:     Fpm_element_long;
    signal next_r:     Fpm_element_long;
    signal sub1:       Fpm_element_long;
    signal sub2:       Fpm_element_long;
    signal out1:       Fpm_element_long;
    signal nbe:        Fpm_element_long;
    signal nr_by_x:    Fpm_element_long;
    signal nb_by_x:    Fpm_element_long;
    signal y_by_x:     Fpm_element_long;
    signal long_c:     Fpm_element_long;
    signal long_e:     Fpm_element_long;
    signal c:          Fpm_element;
    signal d:          Fpm_element;
    signal e:          Fpm_element;
    signal next_c:     Fpm_element;
    signal next_e:     Fpm_element;
    signal sub3:       Fpm_element;
    signal sub4:       Fpm_element;
    signal out2:       Fpm_element;
    signal short_out1: Fpm_element;
    signal deg_a:      std_logic_vector(LOGM-1 downto 0);
    signal deg_b:      std_logic_vector(LOGM-1 downto 0);
    signal deg_r:      std_logic_vector(LOGM-1 downto 0);
    signal dif:        std_logic_vector(LOGM-1 downto 0);
    signal next_da:    std_logic_vector(LOGM-1 downto 0);
    signal next_db:    std_logic_vector(LOGM-1 downto 0);
    signal next_dr:    std_logic_vector(LOGM-1 downto 0);
    signal dr_minus1:  std_logic_vector(LOGM-1 downto 0);
    signal db_minus1:  std_logic_vector(LOGM-1 downto 0);
    signal count:      std_logic_vector(LOGM-1 downto 0);
    signal inv_out:    std_logic_vector(c_P'range);
    signal coef:       std_logic_vector(c_P'range);
    signal ce_a:       std_logic;
    signal ce_b:       std_logic;
    signal ce_d:       std_logic;
    signal ce_r:       std_logic;
    signal ce_e:       std_logic;
    signal sel_a:      std_logic;
    signal sel_b:      std_logic;
    signal sel_r:      std_logic;
    signal sel_sub:    std_logic;
    signal load:       std_logic;
    signal update:     std_logic;
    signal count_zero: std_logic;
    signal deg_zero:   std_logic;
    signal swap:       std_logic;
    signal first:      std_logic;
    signal b_zero:     std_logic;
    signal r_zero:     std_logic;
    signal sel_e:      std_logic_vector(1 downto 0);

    signal m1_start:   std_logic;
    signal m2_start:   std_logic;
    signal d1_start:   std_logic;
    signal d2_start:   std_logic;
    signal s1_start:   std_logic;
    signal s2_start:   std_logic;

    signal m1_done_vec: std_logic_vector(c_M downto 0);
    signal m1_done:     std_logic;
    signal m2_done_vec: std_logic_vector(c_M-1 downto 0);
    signal m2_done:     std_logic;
    signal d1_done:     std_logic;
    signal d2_done_vec: std_logic_vector(c_M-1 downto 0);
    signal d2_done:     std_logic;
    signal s1_done_vec: std_logic_vector(c_M downto 0);
    signal s1_done:     std_logic;
    signal s2_done_vec: std_logic_vector(c_M-1 downto 0);
    signal s2_done:     std_logic;

    type states is (
        S_FINISH,     S_IDLE,       S_FIRST,      S_NORM_B,     S_TEST_DEG,
        S_START_D1,   S_WAIT_D1,    S_START_M1_1, S_WAIT_M1_1,  S_START_S1_1,
        S_WAIT_S1_1,  S_NORM_NR,    S_START_M2,   S_WAIT_M2,    S_START_S2,
        S_WAIT_S2,    S_START_M1_2, S_WAIT_M1_2,  S_START_S1_2, S_WAIT_S1_2,
        S_CHECK_SWAP, S_START_D2,   S_WAIT_D2
    );
    signal current_state: states;

begin

    ----------------------------------------------------------------------------

    long_c(c_M) <= c_FP_ZERO;
    long_e(c_M) <= c_FP_ZERO;
    definition: for i in 0 to c_M-1 generate
        long_c(i) <= c(i);
        long_e(i) <= e(i);
    end generate;

    with sel_sub select sub1 <=    n_a when '0',
                                long_c when others;

    with sel_sub select nbe <=    n_b when '0',
                               long_e when others;

    functions1: for i in 0 to c_M generate
        m1: fp_multiplier
        port map(
            clk   => clk,
            reset => reset,
            start => m1_start,
            done  => m1_done_vec(i),
            x     => coef,
            y     => nbe(i),
            z     => sub2(i)
        );

        s1: fp_subtractor
        port map (
            clk   => clk,
            reset => reset,
            start => s1_start,
            done  => s1_done_vec(i),
            x     => sub1(i),
            y     => sub2(i),
            z     => out1(i)
        );
    end generate;

    ----------------------------------------------------------------------------

    sub3(0) <= c_FP_ZERO;
    by_x1: for i in 1 to c_M-1 generate
        sub3(i) <= e(i-1);
    end generate;

    functions2: for i in 0 to c_M-1 generate
        m2: fp_multiplier
        port map(
            clk   => clk,
            reset => reset,
            start => m2_start,
            done  => m2_done_vec(i),
            x     => e(c_M-1),
            y     => c_F(i),
            z     => sub4(i)
        );

        s2: fp_subtractor
        port map (
            clk   => clk,
            reset => reset,
            start => s2_start,
            done  => s2_done_vec(i),
            x     => sub3(i),
            y     => sub4(i),
            z     => out2(i)
        );
    end generate;

    d1: fp_divider
    port map (
        clk   => clk,
        reset => reset,
        start => d1_start,
        done  => d1_done,
        x     => n_a(c_M),
        y     => n_b(c_M),
        z     => coef
    );

    functions3: for i in 0 to c_M-1 generate
        d2: fp_divider
        port map (
            clk   => clk,
            reset => reset,
            start => d2_start,
            done  => d2_done_vec(i),
            x     => d(i),
            y     => n_b(c_M),
            z     => z(i)
        );
    end generate;

--------------------------------------------------------------------------------

    with sel_a select next_a <= n_b when '0',
                                n_r when others;

    with sel_a select next_da <= deg_b when '0',
                                 deg_r when others;

    with sel_a select next_c <= d when '0',
                                e when others;

    registers_ac: process(clk)
    begin
        if rising_edge(clk) then
            if first = '1' then
                n_a   <= c_F;
                deg_a <= std_logic_vector( to_unsigned(c_M, LOGM) );
                c     <= c_FPM_ZERO;
            elsif ce_a = '1' then
                n_a   <= next_a;
                deg_a <= next_da;
                c     <= next_c;
            end if;
        end if;
    end process registers_ac;

    ----------------------------------------------------------------------------

    y_by_x(0) <= c_FP_ZERO;
    by_x4: for i in 1 to c_M generate
        y_by_x(i) <= y(i-1);
    end generate;

    nb_by_x(0) <= c_FP_ZERO;
    by_x3: for i in 1 to c_M generate
        nb_by_x(i) <= n_b(i-1);
    end generate;

    with sel_b select next_b <= nb_by_x when '0',
                                    n_r when others;

    db_minus1 <= std_logic_vector( unsigned(deg_b) - 1);

    with sel_b select next_db <= db_minus1 when '0',
                                     deg_r when others;

    register_b: process(clk)
    begin
        if rising_edge(clk) then
            if first = '1' then
                n_b   <= y_by_x;
                deg_b <= std_logic_vector( to_unsigned(c_M-1, LOGM) );
            elsif ce_b = '1' then
                n_b   <= next_b;
                deg_b <= next_db;
            end if;
        end if;
    end process register_b;

    ----------------------------------------------------------------------------

    nr_by_x(0) <= c_FP_ZERO;
    by_x2: for i in 1 to c_M generate
        nr_by_x(i) <= n_r(i-1);
    end generate;

    with sel_r select next_r <= out1 when '0',
                             nr_by_x when others;

    dr_minus1 <= std_logic_vector( unsigned(deg_r) - 1);

    with sel_r select next_dr <= deg_a when '0',
                             dr_minus1 when others;

    register_r: process(clk)
    begin
        if rising_edge(clk) then
            if ce_r = '1' then
                n_r   <= next_r;
                deg_r <= next_dr;
            end if;
        end if;
    end process register_r;

    ----------------------------------------------------------------------------

    register_d: process(clk)
    begin
        if rising_edge(clk) then
            if first = '1' then
                d <= x;
            elsif ce_d = '1' then
                d <= e;
            end if;
        end if;
    end process register_d;

    ----------------------------------------------------------------------------

    definition2: for i in 0 to c_M-1 generate
        short_out1(i) <= out1(i);
    end generate;

    with sel_e select next_e <= d          when "00",
                                out2       when "01",
                                short_out1 when others;

    register_e: process(clk)
    begin
        if rising_edge(clk) then
            if ce_e = '1' then
                e <= next_e;
            end if;
        end if;
    end process register_e;

--------------------------------------------------------------------------------

    swap     <= '1' when deg_b  < deg_r else '0';
    deg_zero <= '1' when deg_b  = std_logic_vector( to_unsigned(0, LOGM) ) else '0';
    b_zero   <= '1' when n_b(c_M) = std_logic_vector( to_unsigned(0, c_P'length) ) else '0';
    r_zero   <= '1' when n_r(c_M) = std_logic_vector( to_unsigned(0, c_P'length) ) else '0';

    -- And reduction of all *_done_vec signals
    m1_done <= and m1_done_vec;
    m2_done <= and m2_done_vec;
    d2_done <= and d2_done_vec;
    s1_done <= and s1_done_vec;
    s2_done <= and s2_done_vec;

    dif     <= std_logic_vector( unsigned(deg_a) - unsigned(deg_b) );

    counter: process(clk)
    begin
        if rising_edge(clk) then
            if load = '1' then
                count <= dif;
            elsif update = '1' then
                count <= std_logic_vector( unsigned(count) - 1 );
            end if;
        end if;
    end process counter;

    count_zero <= '1' when count = std_logic_vector( to_unsigned(0, LOGM) ) else '0';

    seq_unit: process(all)
    begin

        -- Control signals default values
        first  <= '0';
        load   <= '0';
        update <= '0';
        done   <= '0';
        ce_a   <= '0';   sel_a  <= '0';
        ce_b   <= '0';   sel_b  <= '0';
        ce_d   <= '0';
        ce_r   <= '0';   sel_r  <= '0'; sel_sub <= '0';
        ce_e   <= '0';   sel_e  <= "00";
        m1_start <= '0'; m2_start <= '0';
        d1_start <= '0'; d2_start <= '0';
        s1_start <= '0'; s2_start <= '0';

        case current_state is

            -- IDLE and hysteresis states

            when S_FINISH to S_IDLE =>
                done <= '1';

            --------------------------------------------------------------------
            -- First state:
            -- Initialize n_a <= F, deg_a <= M, c <= 0, n_b <= y_by_x, deg_b <= m-1, d <= x

            when S_FIRST =>
                first <= '1';

            --------------------------------------------------------------------
            -- Normalization of b???:
            -- while n_b(m) = 0 loop
            --     n_b := multiply_by_x(n_b);
            --     deg_b := deg_b-1
            -- end loop;
            when S_NORM_B =>
                if b_zero = '1' then           -- While n_b(m) == 0
                    ce_b <= '1'; sel_b <= '0';  -- Register shifted n_b
                end if;
            --------------------------------------------------------------------
            -- Main loop test, if deg_b > 0, loop, else finish with last division d2
            when S_TEST_DEG =>
                null;
            --------------------------------------------------------------------
            -- Compute coef
            -- Dif  := Deg_A - Deg_B;
            -- Coef := (N_A(M)*Invert(N_B(M))) mod P;
            when S_START_D1 =>
                d1_start <= '1';
            when S_WAIT_D1 =>
                null;
            --------------------------------------------------------------------
            when S_START_M1_1 =>
                sel_sub <= '0';
                m1_start <= '1';
            when S_WAIT_M1_1 =>
                sel_sub <= '0';
                null;
            --
            when S_START_S1_1 =>
                sel_sub <= '0';
                s1_start <= '1';
            when S_WAIT_S1_1 =>
                sel_sub <= '0';
                if s1_done = '1' then
                    load <= '1';                -- counter = deg_a - deg_b
                    ce_r <= '1'; sel_r <= '0';  -- register n_r = out1 and deg_r = deg_a
                    ce_e <= '1'; sel_e <= "00"; -- register e:=d
                end if;
            --------------------------------------------------------------------
            when S_NORM_NR =>
                if r_zero = '1' then
                    ce_r <= '1'; sel_r <= '1';
                end if;
            --------------------------------------------------------------------
            when S_START_M2 =>
                m2_start <= '1';
                update <= '1';
            when S_WAIT_M2 =>
                null;
            --
            when S_START_S2 =>
                s2_start <= '1';
            when S_WAIT_S2 =>
                if s2_done = '1' then
                    ce_e  <= '1'; sel_e <= "01"; -- register e :=out2 (s2 out)
                end if;
            --------------------------------------------------------------------
            when S_START_M1_2 =>
                sel_sub <= '1';
                m1_start <= '1';
            when S_WAIT_M1_2 =>
                sel_sub <= '1';
                null;
            --
            when S_START_S1_2 =>
                sel_sub <= '1';
                s1_start <= '1';
            when S_WAIT_S1_2 =>
                sel_sub <= '1';
                if s1_done = '1' then
                    ce_e <= '1'; sel_e <= "11"; -- register e := short_out1 (s1 out)
                end if;
            --------------------------------------------------------------------
            when S_CHECK_SWAP =>
                -- if Deg_B >= Deg_R then
                -- swap <= '1' when deg_b  < deg_r else '0';
                if swap = '0' then
                    ce_a  <= '1'; sel_a <= '0'; -- register n_a := n_b, deg_a := deg_b, c := d
                    ce_b  <= '1'; sel_b <= '1'; -- register n_b := n_r, deb_b := deg_r
                    ce_d  <= '1';               -- register d := e
                else
                    ce_a <= '1';  sel_a <= '1'; -- register n_a := n_r, deg_a := deg_r, c := e
                end if;
            --------------------------------------------------------------------
            when S_START_D2 =>
                d2_start <= '1';

            when S_WAIT_D2 =>
                null;
        end case;
    end process;

    control_unit: process(clk,reset)
    begin
        if reset = '1' then
            current_state <= S_FINISH;
        elsif rising_edge(clk) then
            case current_state is
                when S_FINISH =>
                    if start = '0' then
                        current_state <= S_IDLE;
                    end if;
                when S_IDLE =>
                    if start = '1' then
                        current_state <= S_FIRST;
                    end if;
                when S_FIRST =>
                    current_state <= S_NORM_B;
                when S_NORM_B =>
                    if b_zero /= '1' then
                        current_state <= S_TEST_DEG;
                    end if;
                when S_TEST_DEG =>
                    if deg_zero = '0' then
                        current_state <= S_START_D1; -- do loop
                    else
                        --current_state <= 0; -- Finish condition, do last division?
                        current_state <= S_START_D2; -- Finish condition, do last division
                    end if;
                ----------------------------------------------------------------
                -- compute division
                when S_START_D1 =>
                    current_state <= S_WAIT_D1;
                when S_WAIT_D1 =>
                    if d1_done = '1' then
                        current_state <= S_START_M1_1;
                    end if;
                ----------------------------------------------------------------
                -- sub2 := Product(N_B, Coef)   -- m1_1 -- sel_sub = 0
                when S_START_M1_1 =>
                    current_state <= S_WAIT_M1_1;
                when S_WAIT_M1_1 =>
                    if m1_done = '1' then
                        current_state <= S_START_S1_1;
                    end if;
                --
                -- N_R   := Subtract(N_A, sub2); -- s1_1 -- sel_sub = 0
                when S_START_S1_1 =>
                    current_state <= S_WAIT_S1_1;
                when S_WAIT_S1_1 =>
                    current_state <= S_NORM_NR;
                ----------------------------------------------------------------
                when S_NORM_NR =>
                    if r_zero /= '1' then
                        if count_zero /= '1' then
                            current_state <= S_START_M2;
                        else
                            current_state <= S_START_M1_2;
                        end if;
                    end if;
                ----------------------------------------------------------------
                when S_START_M2 =>
                    current_state <= S_WAIT_M2;
                when S_WAIT_M2 =>
                    if m2_done = '1' then
                        current_state <= S_START_S2;
                    end if;
                --
                when S_START_S2 =>
                    current_state <= S_WAIT_S2;
                when S_WAIT_S2 =>
                    if s2_done = '1' then
                        if count_zero /= '1' then
                            -- Loop again
                            current_state <= S_START_M2;
                        else
                            -- Loop finished
                            current_state <= S_START_M1_2;
                        end if;
                    end if;
                ----------------------------------------------------------------
                -- sub2 := Product(E,Coef) -- m1_2 -- sub_sel = 1
                when S_START_M1_2 =>
                    current_state <= S_WAIT_M1_2;
                when S_WAIT_M1_2 =>
                    if m1_done = '1' then
                        current_state <= S_START_S1_2;
                    end if;
                -- E := Subtract(C, sub2); -- s1_2 -- sub_sel = 1
                when S_START_S1_2 =>
                    current_state <= S_WAIT_S1_2;
                when S_WAIT_S1_2 =>
                    if s1_done = '1' then
                        current_state <= S_CHECK_SWAP;
                    end if;

                when S_CHECK_SWAP =>
                    current_state <= S_TEST_DEG;

                when S_START_D2 =>
                    current_state <= S_WAIT_D2;
                when S_WAIT_D2 =>
                    if d2_done = '1' then
                        current_state <= S_FINISH;
                    end if;

            end case;
        end if;
    end process control_unit;

end circuit;
