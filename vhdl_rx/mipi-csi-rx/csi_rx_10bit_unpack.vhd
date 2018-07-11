library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--MIPI CSI-2 10bit pixel unpacker
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This receives 32-bit words from the long video packet payload in; and unpacks them
--into 40 bits of output (which is only active - signified with the 'dout_valid' output -
--80% of the time). It is intended that the dout_valid signal drives the write enable for a linebuffer
--or FIFO.

--At the moment only MIPI 10bit RAW format is supported, other formats may be
--supported in the future (for 8bit you could simply bypass this entity)


entity csi_rx_10bit_unpack is
    Port ( clock : in STD_LOGIC; --word clock in
           reset : in STD_LOGIC; --synchronous active high reset
           enable : in STD_LOGIC; --active high enable
           data_in : in STD_LOGIC_VECTOR (31 downto 0); --packet payload in
           din_valid : in STD_LOGIC; --payload in valid
           data_out : out STD_LOGIC_VECTOR (39 downto 0); --unpacked data out
           dout_valid : out STD_LOGIC); --data out valid (see above)
end csi_rx_10bit_unpack;

architecture Behavioral of csi_rx_10bit_unpack is
  signal dout_int : std_logic_vector(39 downto 0);
  signal bytes_int : std_logic_vector(31 downto 0);
  signal byte_count_int : integer range 0 to 4;
  signal dout_valid_int : std_logic;
  signal dout_unpacked : std_logic_vector(39 downto 0);
  signal dout_valid_up : std_logic;

  --Unpack CSI packed 10-bit to 4 sequential 10-bit pixels
  function mipi_unpack(packed : std_logic_vector)
    return std_logic_vector is
    variable result : std_logic_vector(39 downto 0);
  begin
    result(9 downto 0) := packed(7 downto 0) & packed(33 downto 32);
    result(19 downto 10) := packed(15 downto 8) & packed(35 downto 34);
    result(29 downto 20) := packed(23 downto 16) & packed(37 downto 36);
    result(39 downto 30) := packed(31 downto 24) & packed(39 downto 38);

    return result;
  end mipi_unpack;

begin

  process(clock, reset)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        dout_int <= x"0000000000";
        byte_count_int <= 0;
        dout_valid_int <= '0';
      elsif enable = '1' then
        if din_valid = '1' then
          --Behaviour is based on the number of bytes in the buffer
          case byte_count_int is
            when 0 =>
              dout_int <= x"0000000000";
              dout_valid_int <= '0';
              bytes_int <= data_in;
              byte_count_int <= 4;
            when 1 =>
              dout_int <= data_in & bytes_int(7 downto 0);
              dout_valid_int <= '1';
              bytes_int <= x"00000000";
              byte_count_int <= 0;
            when 2 =>
              dout_int <= data_in(23 downto 0) & bytes_int(15 downto 0);
              dout_valid_int <= '1';
              bytes_int <= x"000000" & data_in(31 downto 24);
              byte_count_int <= 1;
            when 3 =>
              dout_int <= data_in(15 downto 0) & bytes_int(23 downto 0);
              dout_valid_int <= '1';
              bytes_int <= x"0000" & data_in(31 downto 16);
              byte_count_int <= 2;
            when 4 =>
              dout_int <= data_in(7 downto 0) & bytes_int(31 downto 0);
              dout_valid_int <= '1';
              bytes_int <= x"00" & data_in(31 downto 8);
              byte_count_int <= 3;
          end case;
        else
          byte_count_int <= 0;
          dout_valid_int <= '0';
        end if;

        dout_unpacked <= mipi_unpack(dout_int);
        dout_valid_up <= dout_valid_int;
        data_out <= dout_unpacked;
        dout_valid <= dout_valid_up;
      end if;
    end if;
  end process;
end Behavioral;
