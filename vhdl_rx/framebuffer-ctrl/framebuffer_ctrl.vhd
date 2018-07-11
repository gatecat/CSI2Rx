library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Framebuffer Controller for 4k camera demo
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

--This controls a AXI4 compliant framebuffer (implemented in DDR3) for the purposes
--of processing the 4k camera stream to display on a 1080p monitor. It supports either
--a 1x crop mode or a 0.5x zoom-out mode implemented by skipping lines and pixels

--The input port is two pixels wide and the output port one pixel wide. VSYNC and DE inputs in both
--cases are active high

entity framebuffer_ctrl_crop_scale is
  generic(
    burst_len : natural := 16;
    input_width : natural := 3840; --Pixel size of input video
    input_height : natural := 2160;
    output_width : natural := 1920; --Pixel size of output video
    output_height : natural := 1080;
    crop_xoffset : natural := 1024; --X/Y offset in crop mode (chosen to avoid bursts crossing a 4k boundary)
    crop_yoffset : natural := 540;
    scale_xoffset : natural := 0; --X/Y offset in scale mode (not used, for future purposes only)
    scale_yoffset : natural := 0
  );
  port(
    --Input pixel port
    input_clock : in std_logic;
    input_vsync : in std_logic;
    input_line_start : in std_logic;
    input_den : in std_logic;
    input_data_even : in std_logic_vector(23 downto 0);
    input_data_odd : in std_logic_vector(23 downto 0);

    --Output pixel port
    output_clock : in std_logic;
    output_vsync : in std_logic;
    output_line_start : in std_logic;
    output_den : in std_logic;
    output_data : out std_logic_vector(23 downto 0);

    --AXI4 master general
    axi_clock : in std_logic;
    axi_resetn : in std_logic;
    --AXI4 write address
    axi_awid : out std_logic_vector(0 downto 0);
    axi_awaddr : out std_logic_vector(29 downto 0);
    axi_awlen : out std_logic_vector(7 downto 0);
    axi_awsize : out std_logic_vector(2 downto 0);
    axi_awburst : out std_logic_vector(1 downto 0);
    axi_awlock : out std_logic_vector(0 downto 0);
    axi_awcache : out std_logic_vector(3 downto 0);
    axi_awprot : out std_logic_vector(2 downto 0);
    axi_awqos : out std_logic_vector(3 downto 0);
    axi_awvalid : out std_logic;
    axi_awready : in std_logic;
    --AXI4 write data
    axi_wdata : out std_logic_vector(255 downto 0);
    axi_wstrb : out std_logic_vector(31 downto 0);
    axi_wlast : out std_logic;
    axi_wvalid : out std_logic;
    axi_wready : in std_logic;
    --AXI4 write response
    axi_bid : in std_logic_vector(0 downto 0);
    axi_bresp : in std_logic_vector(1 downto 0);
    axi_bvalid : in std_logic;
    axi_bready : out std_logic;
    --AXI4 read address
    axi_arid : out std_logic_vector(0 downto 0);
    axi_araddr : out std_logic_vector(29 downto 0);
    axi_arlen : out std_logic_vector(7 downto 0);
    axi_arsize : out std_logic_vector(2 downto 0);
    axi_arburst : out std_logic_vector(1 downto 0);
    axi_arlock : out std_logic_vector(0 downto 0);
    axi_arcache : out std_logic_vector(3 downto 0);
    axi_arprot : out std_logic_vector(2 downto 0);
    axi_arqos : out std_logic_vector(3 downto 0);
    axi_arvalid : out std_logic;
    axi_arready : in std_logic;
    --AXI4 read data
    axi_rid : in std_logic_vector(0 downto 0);
    axi_rdata : in std_logic_vector(255 downto 0);
    axi_rresp : in std_logic_vector(1 downto 0);
    axi_rlast : in std_logic;
    axi_rvalid : in std_logic;
    axi_rready : out std_logic;
    --Misc
    zoom_mode : in std_logic; --0=scale, 1=crop
    freeze : in std_logic --assert to disable writing
  );
end framebuffer_ctrl_crop_scale;

architecture Behavioral of framebuffer_ctrl_crop_scale is

  COMPONENT input_line_buffer
    PORT (
      clka : IN STD_LOGIC;
      ena : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      clkb : IN STD_LOGIC;
      addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      doutb : OUT STD_LOGIC_VECTOR(255 DOWNTO 0)
    );
  END COMPONENT;

  COMPONENT output_line_buffer
    PORT (
      clka : IN STD_LOGIC;
      ena : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(255 DOWNTO 0);
      clkb : IN STD_LOGIC;
      addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
      doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
  END COMPONENT;

  signal global_reset : std_logic;

  signal write_state : natural range 0 to 4;
  signal write_count : natural range 0 to burst_len-1;
  signal read_state : natural range 0 to 3;


  signal input_linebuf_read_high, input_linebuf_write_high, output_linebuf_read_high, output_linebuf_write_high : std_logic_vector(0 downto 0);

  signal input_read_x, input_write_x, output_read_x, output_write_x : natural range 0 to 4095;
  signal input_read_y, input_write_y, output_read_y, output_write_y : natural range 0 to 4095;

  signal input_write_y_curr, input_write_y_last, output_read_y_curr, output_read_y_last : natural range 0 to 4095;

  signal input_linebuf_write_addr : std_logic_vector(11 downto 0);
  signal input_linebuf_read_addr : std_logic_vector(9 downto 0);
  signal output_linebuf_write_addr : std_logic_vector(9 downto 0);
  signal output_linebuf_read_addr : std_logic_vector(11 downto 0);

  signal input_linebuf_din : std_logic_vector(63 downto 0);
  signal input_linebuf_wren : std_logic_vector(0 downto 0);
  signal input_linebuf_q : std_logic_vector(255 downto 0);

  signal output_linebuf_din : std_logic_vector(255 downto 0);
  signal output_linebuf_wren : std_logic_vector(0 downto 0);
  signal output_linebuf_q : std_logic_vector(63 downto 0);

  signal fb_read_address : std_logic_vector(23 downto 0);
  signal fb_write_address : std_logic_vector(23 downto 0);

  signal output_write_end_x : natural range 0 to 4095;

  signal axi_wready_last : std_logic;
  signal input_linebuf_ready : std_logic;

  --Average two pixels for downscaling purposes
  function rgb_average(pixel_1, pixel_2 : std_logic_vector)
    return std_logic_vector is
      variable pixel_1_t, pixel_2_t : std_logic_vector(23 downto 0);
      variable sum : unsigned(8 downto 0);
      variable result : std_logic_vector(23 downto 0);
    begin
      pixel_1_t := pixel_1;
      pixel_2_t := pixel_2;
      for i in 0 to 2 loop
        sum := resize(unsigned(pixel_1_t((8*i+7) downto (8*i))), 9) + resize(unsigned(pixel_2_t((8*i+7) downto (8*i))), 9);
        result((8*i+7) downto (8*i)) := std_logic_vector(sum(8 downto 1));
      end loop;
      return result;
  end function;

begin

  global_reset <= not axi_resetn;

  input_linebuf_write_addr <= input_linebuf_write_high & std_logic_vector(to_unsigned(input_write_x, 12)(11 downto 1));
  input_linebuf_read_addr <= input_linebuf_read_high & std_logic_vector(to_unsigned(input_read_x, 12)(11 downto 3));
  output_linebuf_write_addr <= output_linebuf_write_high & std_logic_vector(to_unsigned(output_write_x, 12)(11 downto 3));
  output_linebuf_read_addr <= output_linebuf_read_high & std_logic_vector(to_unsigned(output_read_x, 12)(11 downto 1));

  fb_write_address <= std_logic_vector(to_unsigned((input_read_y * input_width) + input_read_x, 24));

  fb_read_address <= std_logic_vector(to_unsigned((output_write_y * input_width * 2) + output_write_x, 24)) when zoom_mode = '0' else
                     std_logic_vector(to_unsigned(((output_write_y + crop_yoffset) * input_width) + output_write_x + crop_xoffset, 24));

  output_write_end_x <= (output_width * 2) when zoom_mode = '0' else output_width;

  process(input_clock)
  begin
    if rising_edge(input_clock) then
      if input_vsync = '1' then
        input_write_x <= 0;
        input_write_y <= 4095;
        input_linebuf_write_high <= "1";
      elsif input_line_start = '1' then
        input_write_x <= 0;
        input_linebuf_write_high <= not input_linebuf_write_high;
        if input_write_y = 4095 then
          input_write_y <= 0;
        else
          input_write_y <= input_write_y + 1;
        end if;
      elsif input_den = '1' then
        input_write_x <= input_write_x + 2; --2 pixels per clock
      end if;
    end if;
  end process;

  process(output_clock)
  begin
    if rising_edge(output_clock) then
      if output_vsync = '1' then
        output_read_x <= 0;
        output_read_y <= 4095;
        output_linebuf_read_high <= "1";
      elsif output_line_start = '1' then
        output_read_x <= 0;
        output_linebuf_read_high <= not output_linebuf_read_high;
        if output_read_y = 4095 then
          output_read_y <= 0;
        else
          output_read_y <= output_read_y + 1;
        end if;
      elsif output_den = '1' then
        if zoom_mode = '0' then
          output_read_x <= output_read_x + 2; --2 pixels per clock for downscaling
        else
          output_read_x <= output_read_x + 1;
        end if;
      end if;
    end if;
  end process;

  process(axi_clock)
  begin
    if rising_edge(axi_clock) then
      input_write_y_curr <= input_write_y;
      input_write_y_last <= input_write_y_curr;
      output_read_y_curr <= output_read_y;
      output_read_y_last <= output_read_y_curr;
      --Only make changes not during writes/reads
      if write_state = 0 then
        --Has write y (i.e. other side) changed?
        if input_write_y_curr /= input_write_y_last then
          input_read_x <= 0;
        end if;
        input_read_y <= input_write_y_curr - 1;
        input_linebuf_read_high <= not input_linebuf_write_high;
        input_linebuf_ready <= '1';
      elsif write_state = 3 then
        if axi_wready = '1' and input_linebuf_ready = '1' then
          input_read_x <= input_read_x + 8;
          input_linebuf_ready <= '0';
        else
          input_linebuf_ready <= '1';
        end if;
      else
        input_linebuf_ready <= '1';
      end if;

      -- if axi_wready = '1' and axi_wready_last = '0' then
      --   input_linebuf_ready <= '0';
      -- else
      --   input_linebuf_ready <= '1';
      -- end if;

      if read_state = 0 then
        if output_read_y_curr /= output_read_y_last then
          output_write_x <= 0;
        end if;
        if output_read_y_curr = 4095 then
          output_write_y <= 0;
        else
          output_write_y <= output_read_y_curr + 1;
        end if;
        output_linebuf_write_high <= not output_linebuf_read_high;
      elsif read_state = 2 then
        if axi_rvalid = '1' then
          output_write_x <= output_write_x + 8;
        end if;
      end if;
    end if;
  end process;

  process(output_linebuf_q, zoom_mode, output_read_x)
  begin
    if zoom_mode = '1' then --crop, alternate between LSW and MSW
        if output_read_x mod 2 = 0 then
          output_data <= output_linebuf_q(31 downto 8);
        else
          output_data <= output_linebuf_q(63 downto 40);
        end if;
    else --zoom, average between both pixels
      output_data <= rgb_average(output_linebuf_q(63 downto 40), output_linebuf_q(31 downto 8));
    end if;
  end process;

  input_linebuf_din <= input_data_odd & x"00" & input_data_even & x"00";
  input_linebuf_wren <= "" & input_den;

  axi_awaddr <= "0000" & fb_write_address & "00";
  axi_araddr <= "0000" & fb_read_address & "00";
  --Write state machine
  process(axi_clock)
  begin
    if rising_edge(axi_clock) then
      axi_wready_last <= axi_wready;
      if global_reset = '1' then
        write_state <= 0;
        write_count <= 0;
      else
        case write_state is
          when 0 => --wait to be able to start writing
            if input_read_x < input_width and input_read_y < input_height and freeze = '0' then
              write_state <= 1;
            end if;
          when 1 => --assert awvalid, wait for awready
            if axi_awready = '1' then
              write_state <= 2;
              write_count <= 0;
            end if;
          when 2 => --begin write
            write_state <= 3;
          when 3 => --write in progress
            if input_linebuf_ready = '1' and axi_wready = '1' then
              if write_count = burst_len - 1 then
                write_state <= 4;
              else
                write_count <= write_count + 1;
              end if;
            end if;
          when 4 =>
            write_state <= 0;
        end case;
      end if;
    end if;
  end process;

  axi_awvalid <= '1' when write_state = 1 else '0';
  axi_wvalid <= input_linebuf_ready when write_state = 3 else '0';
  axi_wlast <= '1' when write_state = 3 and write_count = burst_len - 1 else '0';
  axi_wdata <= input_linebuf_q;

  --Read state machine
  process(axi_clock)
  begin
    if rising_edge(axi_clock) then
      if global_reset = '1' then
        read_state <= 0;
      else
        case read_state is
          when 0 => --wait to be able to start reading
            if output_write_x < output_write_end_x and output_write_y < output_height then
              read_state <= 1;
            end if;
          when 1 => --assert arvalid, wait for arready
            if axi_arready = '1' then
              read_state <= 2;
            end if;

          when 2 => --read in progress

            if axi_rvalid = '1' and axi_rlast = '1' then
              read_state <= 3;
            end if;
          when 3 =>
            read_state <= 0;
        end case;
      end if;
    end if;
  end process;

  axi_arvalid <= '1' when read_state = 1 else '0';
  output_linebuf_wren <= "1" when ((read_state = 1) or (read_state = 2)) and (axi_rvalid = '1') else "0";
  --Split pixels between the two fifos
  output_linebuf_din <= axi_rdata;

  inbuf : input_line_buffer
    port map(
      clka => input_clock,
      ena => '1',
      wea => input_linebuf_wren,
      addra => input_linebuf_write_addr,
      dina => input_linebuf_din,

      clkb => axi_clock,
      addrb => input_linebuf_read_addr,
      doutb => input_linebuf_q
    );

  outbuf : output_line_buffer
    port map(
      clka => axi_clock,
      ena => '1',
      wea => output_linebuf_wren,
      addra => output_linebuf_write_addr,
      dina => output_linebuf_din,

      clkb => output_clock,
      addrb => output_linebuf_read_addr,
      doutb => output_linebuf_q
    );

  --Hardwired AXI4 signals (useful)
  axi_awlen <= std_logic_vector(to_unsigned(burst_len - 1, 8)); --burst len of 16 transfers (128 32-bit words)
  axi_arlen <= std_logic_vector(to_unsigned(burst_len - 1, 8));
  axi_awsize <= "010"; --not sure about this - AXI4 spec does not consider 256-bit datapath
  axi_arsize <= "010";
  axi_awburst <= "01"; --INCR burst type
  axi_arburst <= "01";
  axi_rready <= '1'; --we're always ready
  axi_bready <= '1';
  axi_wstrb <= (others => '1'); --all data bytes always valid
  axi_awid <= "0";
  axi_arid <= "1";

  --Hardwired AXI4 signals (useless)
  axi_awlock <= "0";
  axi_awcache <= "0011";
  axi_awprot <= "000";
  axi_awqos <= "0000";
  axi_arlock <= "0";
  axi_arcache <= "0011";
  axi_arprot <= "000";
  axi_arqos <= "0000";
end Behavioral;
