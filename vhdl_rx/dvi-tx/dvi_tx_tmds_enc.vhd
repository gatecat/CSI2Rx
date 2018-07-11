library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--DVI Transmitter TMDS encoder
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This encodes TMDS 'characters' according to the algorithm in the DVI specification

entity dvi_tx_tmds_enc is
  port(
    clock : in std_logic; --TMDS character clock
    reset : in std_logic; --synchronous reset input
    den   : in std_logic; --display data enable
    data  : in std_logic_vector(7 downto 0); --8bit display data
    ctrl  : in std_logic_vector(1 downto 0); --2bit control (vsync+hsync for ch0)
    tmds  : out std_logic_vector(9 downto 0) --10bit encoded TMDS to transmit
  );
end dvi_tx_tmds_enc;

architecture Behavioral of dvi_tx_tmds_enc is
  signal data_lat : std_logic_vector(7 downto 0);
  signal den_lat : std_logic;
  signal ctrl_lat : std_logic_vector(1 downto 0);
  signal tmds_int : std_logic_vector(9 downto 0);
  signal cnt_q    : integer range -256 to 255;
  signal cnt_d    : integer range -256 to 255;

  signal q_m      : std_logic_vector(8 downto 0);

  function count_ones(x : std_logic_vector) return integer is
    variable count : natural := 0;
  begin
    for i in x'range loop
      if x(i) = '1' then
        count := count + 1;
      end if;
    end loop;
    return count;
  end function;

  function count_zeros(x : std_logic_vector) return integer is
    variable count : natural := 0;
  begin
    for i in x'range loop
      if x(i) = '0' then
        count := count + 1;
      end if;
    end loop;
    return count;
  end function;

begin

  process(clock)
  begin
    if rising_edge(clock) then
      if reset = '1' then
        data_lat <= (others => '0');
        ctrl_lat <= (others => '0');
        den_lat <= '0';
        tmds <= (others => '0');
        cnt_q <= 0;
      else
        data_lat <= data;
        den_lat <= den;
        ctrl_lat <= ctrl;
        tmds <= tmds_int;
        cnt_q <= cnt_d;
      end if;
    end if;
  end process;

  process(data_lat)
    variable q_m_temp : std_logic_vector(8 downto 0);
  begin
    q_m_temp(0) := data_lat(0);
    if count_ones(data_lat) > 4 or ((count_ones(data_lat) = 4) and data_lat(0) = '0') then
      for i in 1 to 7 loop
        q_m_temp(i) := not(q_m_temp(i-1) xor data_lat(i));
      end loop;
      q_m_temp(8) := '0';
    else
      for i in 1 to 7 loop
        q_m_temp(i) := q_m_temp(i-1) xor data_lat(i);
      end loop;
      q_m_temp(8) := '1';
    end if;
    q_m <= q_m_temp;
  end process;

  process(cnt_q, q_m, den_lat, ctrl_lat)
    variable q_out : std_logic_vector(9 downto 0);
  begin
    if den_lat = '0' then
      cnt_d <= 0;
      case ctrl_lat is
        when "00" =>
          q_out := "1101010100";
        when "01" =>
          q_out := "0010101011";
        when "10" =>
          q_out := "0101010100";
        when "11" =>
          q_out := "1010101011";
        when others => --never occurs in synthesised system but keeps sims happy
          q_out := "0000000000";
      end case;
    else
      if cnt_q = 0 or count_ones(q_m(7 downto 0)) = 4 then
        q_out(9) := not q_m(8);
        q_out(8) := q_m(8);
        if q_m(8) = '1' then
          q_out(7 downto 0) := q_m(7 downto 0);
          cnt_d <= cnt_q + 2 * (count_ones(q_m(7 downto 0)) - 4);
        else
          q_out(7 downto 0) := not q_m(7 downto 0);
          cnt_d <= cnt_q + 2 * (4 - count_ones(q_m(7 downto 0)));
        end if;
      else
        if ((cnt_q > 0) and (count_ones(q_m(7 downto 0)) > 4))
            or ((cnt_q < 0) and (count_ones(q_m(7 downto 0)) < 4)) then
          q_out(9) := '1';
          q_out(8) := q_m(8);
          q_out(7 downto 0) := not q_m(7 downto 0);
          if q_m(8) = '1' then
            cnt_d <= cnt_q + 2 + 2 * (4 - count_ones(q_m(7 downto 0)));
          else
            cnt_d <= cnt_q + 2 * (4 - count_ones(q_m(7 downto 0)));
          end if;
        else
          q_out(9) := '0';
          q_out(8) := q_m(8);
          q_out(7 downto 0) := q_m(7 downto 0);
          if q_m(8) = '0' then
            cnt_d <= (cnt_q - 2) + 2 * (count_ones(q_m(7 downto 0)) - 4);
          else
            cnt_d <= cnt_q + 2 * (count_ones(q_m(7 downto 0)) - 4);
          end if;
        end if;
      end if;
    end if;
    tmds_int <= q_out;
  end process;
end Behavioral;
