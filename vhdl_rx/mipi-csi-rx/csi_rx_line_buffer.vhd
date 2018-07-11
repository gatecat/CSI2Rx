library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--MIPI CSI-2 Rx Line Buffer
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity csi_rx_line_buffer is
  generic(
    line_width : natural := 3840; --width of a single line
    pixels_per_clock : natural := 2 --number of pixels output every clock cycle; either 1, 2 or 4
  );
  port(
    write_clock : in std_logic;
    write_addr : in natural range 0 to (line_width / 4) - 1;
    write_data : in std_logic_vector(39 downto 0); --write port is always 4 pixels wide
    write_en : in std_logic;

    read_clock : in std_logic;
    read_addr : in natural range 0 to (line_width / pixels_per_clock) - 1;
    read_q : out std_logic_vector((10 * pixels_per_clock) - 1 downto 0)
  );
end csi_rx_line_buffer;

architecture Behavioral of csi_rx_line_buffer is
  type linebuf_t is array(0 to (line_width / 4) - 1) of std_logic_vector(39 downto 0);
  signal linebuf : linebuf_t;

  signal linebuf_read_address : natural range 0 to (line_width / 4) - 1;
  signal read_address_lat : natural range 0 to (line_width / pixels_per_clock) - 1;

  signal linebuf_read_q : std_logic_vector(39 downto 0);
begin

  process(write_clock)
  begin
    if rising_edge(write_clock) then
      if write_en = '1' then
        linebuf(write_addr) <= write_data;
      end if;
    end if;
  end process;

  process(read_clock)
  begin
    if rising_edge(read_clock) then
      read_address_lat <= read_addr;
      linebuf_read_q <= linebuf(linebuf_read_address);
    end if;
  end process;

  sppc : if pixels_per_clock = 1 generate
    linebuf_read_address <= read_addr / 4;
    read_q <= linebuf_read_q(9 downto 0) when read_address_lat mod 4 = 0 else
              linebuf_read_q(19 downto 10) when read_address_lat mod 4 = 1 else
              linebuf_read_q(29 downto 20) when read_address_lat mod 4 = 2 else
              linebuf_read_q(39 downto 30);
  end generate;

  dppc : if pixels_per_clock = 2 generate
    linebuf_read_address <= read_addr / 2;
    read_q <= linebuf_read_q(19 downto 0) when read_address_lat mod 2 = 0 else
              linebuf_read_q(39 downto 20);
  end generate;

  qppc : if pixels_per_clock = 4 generate
    linebuf_read_address <= read_addr;
    read_q <= linebuf_read_q;
  end generate;
end architecture;
