-- ================================================================================ --
-- NEORV32 on Nexys 4 - Fast simulation testbench                                   --
-- -------------------------------------------------------------------------------- --
-- Simulates the SAME processor as the FPGA bitstream (neorv32_test_setup_bootloader:--
-- RV32IMC + Zicsr + Zicntr, 16 kB IMEM, 8 kB DMEM, 8 GPIO, CLINT, UART0), but boots  --
-- directly from the IMEM image (BOOT_MODE_SELECT = 2) instead of the UART          --
-- bootloader, so a compiled C program starts running immediately.                  --
--                                                                                  --
-- Output:                                                                          --
--  * UART0 in simulation mode (-DUART0_SIM_MODE): characters print to the console  --
--  * UART0 normal mode: decoded from the TX pin into nexys4.uart0_rx.log (slower)  --
--  * GPIO: every change of the 8 LEDs is reported as  [LEDS] 00000101 @ <time>     --
-- ================================================================================ --

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library neorv32;
use neorv32.neorv32_package.all;

entity neorv32_nexys4_tb is
  generic (
    -- Simulated clock. The board runs at 100 MHz, but software reads the frequency from
    -- SYSINFO, so delay_ms() and the UART adapt automatically. At 1 MHz every millisecond
    -- costs 100x fewer simulated cycles, which makes LED demos practical in simulation.
    -- Timestamps in the output are still real milliseconds.
    CLOCK_FREQUENCY : natural := 1_000_000;
    IMEM_SIZE       : natural := 16*1024;     -- same as the FPGA test setup
    DMEM_SIZE       : natural := 8*1024;      -- same as the FPGA test setup
    UART_BAUD       : natural := 19200        -- only used by the TX-pin decoder
  );
end entity;

architecture neorv32_nexys4_tb_rtl of neorv32_nexys4_tb is

  constant t_clk_c : time := (1 sec) / CLOCK_FREQUENCY;

  signal clk   : std_ulogic := '0';
  signal rstn  : std_ulogic := '0';
  signal gpio  : std_ulogic_vector(31 downto 0);
  signal txd   : std_ulogic;

begin

  -- 100 MHz clock and reset --------------------------------------------------------------
  clk  <= not clk after (t_clk_c / 2);
  rstn <= '0', '1' after (50 * t_clk_c);

  -- The processor, configured exactly like the FPGA test setup ----------------------------
  dut: entity neorv32.neorv32_top
  generic map (
    CLOCK_FREQUENCY  => CLOCK_FREQUENCY,
    BOOT_MODE_SELECT => 2,          -- boot from the IMEM image (no bootloader in simulation)
    RISCV_ISA_C      => true,
    RISCV_ISA_M      => true,
    RISCV_ISA_Zicntr => true,
    IMEM_EN          => true,
    IMEM_SIZE        => IMEM_SIZE,
    DMEM_EN          => true,
    DMEM_SIZE        => DMEM_SIZE,
    IO_GPIO_NUM      => 8,
    IO_CLINT_EN      => true,
    IO_UART0_EN      => true
  )
  port map (
    clk_i       => clk,
    rstn_i      => rstn,
    gpio_o      => gpio,
    uart0_txd_o => txd,
    uart0_rxd_i => '1'
  );

  -- Decode the real UART TX line (programs built without UART0_SIM_MODE) ------------------
  uart_rx: entity work.sim_uart_rx
  generic map (
    NAME => "nexys4.uart0_rx",
    FCLK => real(CLOCK_FREQUENCY),
    BAUD => real(UART_BAUD)
  )
  port map (
    clk => clk,
    rxd => txd
  );

  -- Virtual LEDs: report every change of LD7..LD0 -----------------------------------------
  led_monitor: process
    variable prev_v : std_ulogic_vector(7 downto 0) := (others => '0');
    function bits_f(v : std_ulogic_vector) return string is
      variable s : string(1 to v'length);
      variable i : natural := 1;
    begin
      for k in v'range loop
        if v(k) = '1' then s(i) := '1'; else s(i) := '0'; end if;
        i := i + 1;
      end loop;
      return s;
    end function;
  begin
    wait until rstn = '1';
    loop
      wait until rising_edge(clk);
      if gpio(7 downto 0) /= prev_v then
        prev_v := gpio(7 downto 0);
        report "[LEDS] " & bits_f(prev_v) & " (LD7..LD0)";
      end if;
    end loop;
  end process;

end architecture;
