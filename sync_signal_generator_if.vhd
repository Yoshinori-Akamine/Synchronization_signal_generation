----------------------------------------------------------------------------------
-- sync_signal_generator_if
--
-- SYNC_SRC_MODE
--   "00": Use external zero-cross polarity signal ZC_IN
--   "01": Use delayed S1_IN
--   "10": Use delayed S2_IN
--   "11": No rectifier control / diode mode
--
-- Notes
--   - SYNC_OUT is a rectangular polarity signal, not a 1-clock pulse.
--   - S1/S2 modes use edge detection + delay counter.
--   - No long shift register is used.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_signal_generator_if is
    port (
        CLK_IN              : in  std_logic;
        RESET_IN            : in  std_logic;
        UPDATE              : in  std_logic;

        SYNC_SRC_MODE       : in  std_logic_vector(1 downto 0);

        ZC_IN               : in  std_logic;
        S1_IN               : in  std_logic;
        S2_IN               : in  std_logic;
        DELAY_CLK           : in  std_logic_vector(9 downto 0);
        MIN_ZC_PERIOD_CLK   : in  std_logic_vector(10 downto 0);

        SYNC_OUT            : out std_logic;
        RECT_NOCONTROL_FLAG : out std_logic
    );
end sync_signal_generator_if;

architecture Behavioral of sync_signal_generator_if is

    --------------------------------------------------------------------------
    -- Configuration registers
    --------------------------------------------------------------------------
    signal sync_mode_reg       : std_logic_vector(1 downto 0) := "11";
    signal delay_clk_reg       : unsigned(9 downto 0) := (others => '0');
    signal min_zc_period_reg   : unsigned(10 downto 0) := (others => '0');

    --------------------------------------------------------------------------
    -- Input synchronizers
    --------------------------------------------------------------------------
    signal zc_sync_1           : std_logic := '0';
    signal zc_sync_2           : std_logic := '0';
    signal zc_prev             : std_logic := '0';

    signal s1_sync_1           : std_logic := '0';
    signal s1_sync_2           : std_logic := '0';
    signal s1_prev             : std_logic := '0';

    signal s2_sync_1           : std_logic := '0';
    signal s2_sync_2           : std_logic := '0';
    signal s2_prev             : std_logic := '0';

    --------------------------------------------------------------------------
    -- Edge detection
    --------------------------------------------------------------------------
    signal zc_edge_detected    : std_logic := '0';
    signal zc_edge_valid       : std_logic := '0';

    signal s1_edge_detected    : std_logic := '0';
    signal s2_edge_detected    : std_logic := '0';

    --------------------------------------------------------------------------
    -- Zero-cross period counter
    --------------------------------------------------------------------------
    signal zc_period_counter   : unsigned(10 downto 0) := (others => '0');

    --------------------------------------------------------------------------
    -- Delay counter for S1/S2 modes
    --------------------------------------------------------------------------
    signal delay_running       : std_logic := '0';
    signal delay_counter       : unsigned(9 downto 0) := (others => '0');
    signal pending_sync_level  : std_logic := '0';

    --------------------------------------------------------------------------
    -- Output registers
    --------------------------------------------------------------------------
    signal sync_out_reg        : std_logic := '0';
    signal rect_nocontrol_reg  : std_logic := '1';

    --------------------------------------------------------------------------
    -- Debug attributes
    --------------------------------------------------------------------------
    attribute mark_debug : string;

    attribute mark_debug of sync_mode_reg       : signal is "true";
    attribute mark_debug of delay_clk_reg       : signal is "true";
    attribute mark_debug of min_zc_period_reg   : signal is "true";

    attribute mark_debug of zc_sync_2           : signal is "true";
    attribute mark_debug of zc_prev             : signal is "true";
    attribute mark_debug of zc_edge_detected    : signal is "true";
    attribute mark_debug of zc_edge_valid       : signal is "true";
    attribute mark_debug of zc_period_counter   : signal is "true";

    attribute mark_debug of s1_sync_2           : signal is "true";
    attribute mark_debug of s1_prev             : signal is "true";
    attribute mark_debug of s1_edge_detected    : signal is "true";

    attribute mark_debug of s2_sync_2           : signal is "true";
    attribute mark_debug of s2_prev             : signal is "true";
    attribute mark_debug of s2_edge_detected    : signal is "true";

    attribute mark_debug of delay_running       : signal is "true";
    attribute mark_debug of delay_counter       : signal is "true";
    attribute mark_debug of pending_sync_level  : signal is "true";

    attribute mark_debug of sync_out_reg        : signal is "true";
    attribute mark_debug of rect_nocontrol_reg  : signal is "true";

begin

    SYNC_OUT            <= sync_out_reg;
    RECT_NOCONTROL_FLAG <= rect_nocontrol_reg;

    process(CLK_IN)
    begin
        if rising_edge(CLK_IN) then
            if RESET_IN = '1' then

                sync_mode_reg     <= "11";
                delay_clk_reg     <= (others => '0');
                min_zc_period_reg <= (others => '0');

                zc_sync_1 <= '0';
                zc_sync_2 <= '0';
                zc_prev   <= '0';

                s1_sync_1 <= '0';
                s1_sync_2 <= '0';
                s1_prev   <= '0';

                s2_sync_1 <= '0';
                s2_sync_2 <= '0';
                s2_prev   <= '0';

                zc_edge_detected <= '0';
                zc_edge_valid    <= '0';
                s1_edge_detected <= '0';
                s2_edge_detected <= '0';

                zc_period_counter <= (others => '0');

                delay_running      <= '0';
                delay_counter      <= (others => '0');
                pending_sync_level <= '0';

                sync_out_reg       <= '0';
                rect_nocontrol_reg <= '1';

            else

                ------------------------------------------------------------------
                -- Update configuration registers
                ------------------------------------------------------------------
                if UPDATE = '1' then
                    sync_mode_reg     <= SYNC_SRC_MODE;
                    delay_clk_reg     <= unsigned(DELAY_CLK);
                    min_zc_period_reg <= unsigned(MIN_ZC_PERIOD_CLK);
                end if;

                ------------------------------------------------------------------
                -- Input synchronization
                ------------------------------------------------------------------
                zc_sync_1 <= ZC_IN;
                zc_sync_2 <= zc_sync_1;
                zc_prev   <= zc_sync_2;

                s1_sync_1 <= S1_IN;
                s1_sync_2 <= s1_sync_1;
                s1_prev   <= s1_sync_2;

                s2_sync_1 <= S2_IN;
                s2_sync_2 <= s2_sync_1;
                s2_prev   <= s2_sync_2;

                ------------------------------------------------------------------
                -- Edge detection
                -- Both rising and falling edges are detected.
                ------------------------------------------------------------------
                if zc_prev /= zc_sync_2 then
                    zc_edge_detected <= '1';
                else
                    zc_edge_detected <= '0';
                end if;

                if s1_prev /= s1_sync_2 then
                    s1_edge_detected <= '1';
                else
                    s1_edge_detected <= '0';
                end if;

                if s2_prev /= s2_sync_2 then
                    s2_edge_detected <= '1';
                else
                    s2_edge_detected <= '0';
                end if;

                ------------------------------------------------------------------
                -- Zero-cross period counter
                ------------------------------------------------------------------
                if zc_period_counter /= "11111111111" then
                    zc_period_counter <= zc_period_counter + 1;
                end if;

                ------------------------------------------------------------------
                -- Zero-cross validation
                -- Too-early ZC edges are ignored.
                ------------------------------------------------------------------
                if zc_edge_detected = '1' then
                    if zc_period_counter >= min_zc_period_reg then
                        zc_edge_valid     <= '1';
                        zc_period_counter <= (others => '0');
                    else
                        zc_edge_valid <= '0';
                    end if;
                else
                    zc_edge_valid <= '0';
                end if;

                ------------------------------------------------------------------
                -- Explicit 4-mode behavior
                ------------------------------------------------------------------
                case sync_mode_reg is

                    ------------------------------------------------------------------
                    -- 00: External zero-cross polarity mode
                    --     SYNC_OUT updates only at valid ZC edges.
                    ------------------------------------------------------------------
                    when "00" =>
                        rect_nocontrol_reg <= '0';

                        delay_running <= '0';
                        delay_counter <= (others => '0');

                        if zc_edge_valid = '1' then
                            sync_out_reg <= zc_sync_2;
                        end if;

                    ------------------------------------------------------------------
                    -- 01: Delayed S1 mode
                    --     When S1 changes, store its new level and output it after
                    --     DELAY_CLK cycles.
                    ------------------------------------------------------------------
                    when "01" =>
                        rect_nocontrol_reg <= '0';

                        if s1_edge_detected = '1' then
                            pending_sync_level <= s1_sync_2;

                            if delay_clk_reg = 0 then
                                sync_out_reg  <= s1_sync_2;
                                delay_running <= '0';
                                delay_counter <= (others => '0');
                            else
                                delay_running <= '1';
                                delay_counter <= (others => '0');
                            end if;
                        end if;

                    ------------------------------------------------------------------
                    -- 10: Delayed S2 mode
                    --     When S2 changes, store its new level and output it after
                    --     DELAY_CLK cycles.
                    ------------------------------------------------------------------
                    when "10" =>
                        rect_nocontrol_reg <= '0';

                        if s2_edge_detected = '1' then
                            pending_sync_level <= s2_sync_2;

                            if delay_clk_reg = 0 then
                                sync_out_reg  <= s2_sync_2;
                                delay_running <= '0';
                                delay_counter <= (others => '0');
                            else
                                delay_running <= '1';
                                delay_counter <= (others => '0');
                            end if;
                        end if;

                    ------------------------------------------------------------------
                    -- 11: No control / diode mode
                    ------------------------------------------------------------------
                    when others =>
                        rect_nocontrol_reg <= '1';
                        sync_out_reg       <= '0';

                        delay_running <= '0';
                        delay_counter <= (others => '0');

                end case;

                ------------------------------------------------------------------
                -- Delay counter
                -- Common block for S1/S2 delayed modes.
                ------------------------------------------------------------------
                if delay_running = '1' then
                    if delay_counter >= delay_clk_reg - 1 then
                        sync_out_reg  <= pending_sync_level;
                        delay_running <= '0';
                        delay_counter <= (others => '0');
                    else
                        delay_counter <= delay_counter + 1;
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;
