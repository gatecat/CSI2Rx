library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--MIPI CSI-2 Rx Packet Handler
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This controls the wait_for_sync and packet_done inputs to the byte/word aligners;
--receives aligned words and processes them
--It keeps track of whether or not we are currently in a video line or frame;
--and pulls the video payload out of long packets of the correct type

entity csi_rx_packet_handler is
    Port ( clock : in STD_LOGIC; --word clock in
           reset : in STD_LOGIC; --asynchronous active high reset
           enable : in STD_LOGIC; --active high enable
           data : in STD_LOGIC_VECTOR (31 downto 0); --data in from word aligner
           data_valid : in STD_LOGIC; --data valid in from word aligner
           sync_wait : out STD_LOGIC; --drives byte and word aligner wait_for_sync
           packet_done : out STD_LOGIC; --drives word aligner packet_done
           payload_out : out STD_LOGIC_VECTOR(31 downto 0); --payload out from long video packets
           payload_valid : out STD_LOGIC; --whether or not payload output is valid (i.e. currently receiving a long packet)
           vsync_out : out STD_LOGIC; --vsync output to timing controller
           in_frame : out STD_LOGIC; --whether or not currently in video frame (i.e. got FS but not FE)
			     in_line : out STD_LOGIC); --whether or not receiving video line
end csi_rx_packet_handler;


architecture Behavioral of csi_rx_packet_handler is
  signal is_hdr : std_logic;
  signal packet_type : std_logic_vector(7 downto 0);
  signal long_packet : std_logic;
  signal packet_len  : unsigned(15 downto 0);
  signal packet_len_q : unsigned(15 downto 0) := x"0000";
  signal state : std_logic_vector(2 downto 0) := "000";
  signal bytes_read : unsigned(15 downto 0);
  signal in_frame_d : std_logic;
  signal in_line_d : std_logic;
  signal valid_packet : std_logic;


  signal packet_for_ecc : std_logic_vector(23 downto 0);
  signal expected_ecc : std_logic_vector(7 downto 0);

  function is_allowed_type(packet_type : std_logic_vector)
    return std_logic is
    variable result : std_logic;
    variable packet_type_temp : std_logic_vector(7 downto 0);
    begin
      packet_type_temp := packet_type; --keep GHDL happy
      case packet_type_temp is
      when x"00" | x"01" | x"02" | x"03" => --sync
      	result := '1';
      when x"10" | x"11" | x"12" => --non image
      	result := '1';
      when x"28" | x"29" | x"2A" | x"2B" | x"2C" | x"2D" => --RAW
      	result := '1';
      when others =>
      	result := '0';
      end case;
    return result;
  end is_allowed_type;

begin
  --Main state machine process
  process(reset, clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        state <= "000";
      elsif enable = '1' then
        case state is
          when "000" => --waiting to init
            state <= "001";
          when "001" => --waiting for start
            bytes_read <= x"0000";
            if data_valid = '1' then
              packet_len_q <= packet_len;
              if long_packet = '1' then
                  state <= "010";
              else
                  state <= "011";
              end if;
            end if;
          when "010" => --rx long packet
            if (bytes_read < (packet_len_q - 4)) and(bytes_read < 8192) then
              bytes_read <= bytes_read + 4;
            else
              state <= "011";
            end if;
          when "011" => --packet done, assert packet_done
            state <= "100";
          when "100" => --wait one cycle and reset
            state <= "001";
          when others =>
            state <= "000";
        end case;
      end if;
    end if;
  end process;

  --At the moment we only calculate the expected ECC and compare it to the received ECC,
  --rejecting the packet if this fails. In the future it would be better to also correct
  --single bit errors
  ecc : entity work.csi_rx_hdr_ecc port map(
    data => packet_for_ecc,
    ecc => expected_ecc);

  packet_type <= "00" & data(5 downto 0);
  valid_packet <= '1' when (data(31 downto 24) = expected_ecc) and
                           (is_allowed_type(packet_type) = '1') and
                           (data(7 downto 6) = "00")
                      else '0';

  is_hdr <= '1' when data_valid = '1' and state = "001"
                else '0';

  long_packet <= '1' when (packet_type > x"0F") and (valid_packet = '1')
                     else '0';

  vsync_out <= '1' when is_hdr = '1' and packet_type = x"00"
                   else '0';

  packet_for_ecc <= data(23 downto 0);
  packet_len <= unsigned(data(23 downto 8));

  process(reset, clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        in_frame_d <= '0';
        in_line_d <= '0';
      elsif enable = '1' then
        if is_hdr = '1' and packet_type = x"00" and valid_packet = '1' then --FS
          in_frame_d <= '1';
        elsif is_hdr = '1' and packet_type = x"01" and valid_packet = '1' then --FE
          in_frame_d <= '0';
        end if;

        if is_hdr = '1' and (packet_type(7 downto 4) = x"2") and valid_packet = '1' then
          in_line_d <= '1';
        elsif state /= "010" and state /= "001" then
          in_line_d <= '0';
        end if;
      end if;
    end if;
  end process;

  in_frame <= in_frame_d;
  in_line <= in_line_d;
  sync_wait <= '1' when state = "001" else '0';
  packet_done <= '1' when state = "011" else '0';
  payload_out <= data when state = "010" else x"00000000";
  payload_valid <= '1' when state = "010" else '0';

end Behavioral;
