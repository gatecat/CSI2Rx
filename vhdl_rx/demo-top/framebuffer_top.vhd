library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Top Level Framebuffer and Video Output Design
--Copyright (C) 2016 David Shah
--Licensed under the MIT License

entity framebuffer_top is
  port(
    --Video input port
    input_pixck : in std_logic;
    input_vsync : in std_logic;
    input_line_start : in std_logic;
    input_den : in std_logic;
    input_data_even : in std_logic_vector(23 downto 0);
    input_data_odd : in std_logic_vector(23 downto 0);
    
    --System/control inputs
    system_clock : in std_logic;
    system_reset : in std_logic;
    zoom_mode : in std_logic;
    freeze : in std_logic;
    
    --Video output port
    output_pixck : in std_logic;
    output_vsync : out std_logic;
    output_hsync : out std_logic;
    output_den : out std_logic;
    output_line_start : out std_logic;
    output_data : out std_logic_vector(23 downto 0);
    
    --DDR3 interface
    ddr3_addr : out std_logic_vector(14 downto 0);
    ddr3_ba : out std_logic_vector(2 downto 0);
    ddr3_cas_n : out std_logic;
    ddr3_ck_n : out std_logic_vector(0 downto 0);
    ddr3_ck_p : out std_logic_vector(0 downto 0);
    ddr3_cke : out std_logic_vector(0 downto 0);
    ddr3_ras_n : out std_logic;
    ddr3_reset_n : out std_logic;
    ddr3_we_n : out std_logic;
    ddr3_dq : inout std_logic_vector(31 downto 0);
    ddr3_dqs_n : inout std_logic_vector(3 downto 0);
    ddr3_dqs_p : inout std_logic_vector(3 downto 0);
    ddr3_cs_n : out std_logic_vector(0 downto 0);
    ddr3_dm : out std_logic_vector(3 downto 0);
    ddr3_odt : out std_logic_vector(0 downto 0)
  );
end framebuffer_top;

architecture Behavioral of framebuffer_top is
  signal ui_clock : std_logic;
  signal axi_resetn : std_logic;
  
  signal axi_awid : std_logic_vector(0 downto 0);
  signal axi_awaddr : std_logic_vector(29 downto 0);
  signal axi_awlen : std_logic_vector(7 downto 0);
  signal axi_awsize : std_logic_vector(2 downto 0);
  signal axi_awburst : std_logic_vector(1 downto 0);
  signal axi_awlock : std_logic_vector(0 downto 0);
  signal axi_awcache : std_logic_vector(3 downto 0);
  signal axi_awprot : std_logic_vector(2 downto 0);
  signal axi_awqos : std_logic_vector(3 downto 0);
  signal axi_awvalid : std_logic;
  signal axi_awready : std_logic;
  
  signal axi_wdata : std_logic_vector(255 downto 0);
  signal axi_wstrb : std_logic_vector(31 downto 0);
  signal axi_wlast : std_logic;
  signal axi_wvalid : std_logic;
  signal axi_wready : std_logic;
  
  signal axi_bid : std_logic_vector(0 downto 0);
  signal axi_bresp : std_logic_vector(1 downto 0);
  signal axi_bvalid : std_logic;
  signal axi_bready : std_logic;
  
  signal axi_arid : std_logic_vector(0 downto 0);
  signal axi_araddr : std_logic_vector(29 downto 0);
  signal axi_arlen : std_logic_vector(7 downto 0);
  signal axi_arsize : std_logic_vector(2 downto 0);
  signal axi_arburst : std_logic_vector(1 downto 0);
  signal axi_arlock : std_logic_vector(0 downto 0);
  signal axi_arcache : std_logic_vector(3 downto 0);
  signal axi_arprot : std_logic_vector(2 downto 0);
  signal axi_arqos : std_logic_vector(3 downto 0);
  signal axi_arvalid : std_logic;
  signal axi_arready : std_logic;
  
  signal axi_rid : std_logic_vector(0 downto 0);
  signal axi_rdata : std_logic_vector(255 downto 0);
  signal axi_rresp : std_logic_vector(1 downto 0);
  signal axi_rlast : std_logic;
  signal axi_rvalid : std_logic;
  signal axi_rready : std_logic;
  
  signal fbc_ovsync : std_logic;
  signal fbc_data : std_logic_vector(23 downto 0);
  
  signal output_line_start_int : std_logic;
  signal output_den_int : std_logic;
  
  component ddr3_if is
    port(
      ddr3_addr : out std_logic_vector(14 downto 0);
      ddr3_ba : out std_logic_vector(2 downto 0);
      ddr3_cas_n : out std_logic;
      ddr3_ck_n : out std_logic_vector(0 downto 0);
      ddr3_ck_p : out std_logic_vector(0 downto 0);
      ddr3_cke : out std_logic_vector(0 downto 0);
      ddr3_ras_n : out std_logic;
      ddr3_reset_n : out std_logic;
      ddr3_we_n : out std_logic;
      ddr3_dq : inout std_logic_vector(31 downto 0);
      ddr3_dqs_n : inout std_logic_vector(3 downto 0);
      ddr3_dqs_p : inout std_logic_vector(3 downto 0);
      init_calib_complete : out std_logic;
      ddr3_cs_n : out std_logic_vector(0 downto 0);
      ddr3_dm : out std_logic_vector(3 downto 0);
      ddr3_odt : out std_logic_vector(0 downto 0);
      
      ui_clk : out std_logic;
      ui_clk_sync_rst : out std_logic;
      mmcm_locked : out std_logic;
      aresetn : in std_logic;
      app_sr_req : in std_logic;
      app_ref_req : in std_logic;
      app_zq_req : in std_logic;
      app_sr_active : out std_logic;
      app_ref_ack : out std_logic;
      app_zq_ack : out std_logic;
      
      s_axi_awid : in std_logic_vector(0 downto 0);
      s_axi_awaddr : in std_logic_vector(29 downto 0);
      s_axi_awlen : in std_logic_vector(7 downto 0);
      s_axi_awsize : in std_logic_vector(2 downto 0);
      s_axi_awburst : in std_logic_vector(1 downto 0);
      s_axi_awlock : in std_logic_vector(0 downto 0);
      s_axi_awcache : in std_logic_vector(3 downto 0);
      s_axi_awprot : in std_logic_vector(2 downto 0);
      s_axi_awqos : in std_logic_vector(3 downto 0);
      s_axi_awvalid : in std_logic;
      s_axi_awready : out std_logic;
      
      s_axi_wdata : in std_logic_vector(255 downto 0);
      s_axi_wstrb : in std_logic_vector(31 downto 0);
      s_axi_wlast : in std_logic;
      s_axi_wvalid : in std_logic;
      s_axi_wready : out std_logic;
      
      s_axi_bid : out std_logic_vector(0 downto 0);
      s_axi_bresp : out std_logic_vector(1 downto 0);
      s_axi_bvalid : out std_logic;
      s_axi_bready : in std_logic;
      
      s_axi_arid : in std_logic_vector(0 downto 0);
      s_axi_araddr : in std_logic_vector(29 downto 0);
      s_axi_arlen : in std_logic_vector(7 downto 0);
      s_axi_arsize : in std_logic_vector(2 downto 0);
      s_axi_arburst : in std_logic_vector(1 downto 0);
      s_axi_arlock : in std_logic_vector(0 downto 0);
      s_axi_arcache : in std_logic_vector(3 downto 0);
      s_axi_arprot : in std_logic_vector(2 downto 0);
      s_axi_arqos : in std_logic_vector(3 downto 0);
      s_axi_arvalid : in std_logic;
      s_axi_arready : out std_logic;
      
      s_axi_rid : out std_logic_vector(0 downto 0);
      s_axi_rdata : out std_logic_vector(255 downto 0);
      s_axi_rresp : out std_logic_vector(1 downto 0);
      s_axi_rlast : out std_logic;
      s_axi_rvalid : out std_logic;
      s_axi_rready : in std_logic;
      
      sys_clk_i : in std_logic;
      sys_rst : in std_logic
    );
  end component;

begin
  
    axi_resetn <= not system_reset;
    
    fbctl : entity work.framebuffer_ctrl_crop_scale
      generic map(
        burst_len => 16,
        input_width => 3840,
        input_height => 2160,
        output_width => 1920,
        output_height => 1080,
        crop_xoffset => 1024,
        crop_yoffset => 540,
        scale_xoffset => 0,
        scale_yoffset => 0)
      port map(
        input_clock => input_pixck,
        input_vsync => input_vsync,
        input_line_start => input_line_start,
        input_den => input_den,
        input_data_even => input_data_even,
        input_data_odd => input_data_odd,
        
        output_clock => output_pixck,
        output_vsync => fbc_ovsync,
        output_line_start => output_line_start_int,
        output_den => output_den_int,
        output_data => fbc_data,
        
        axi_clock => ui_clock,
        axi_resetn => axi_resetn,
        
        axi_awid => axi_awid,
        axi_awaddr => axi_awaddr,
        axi_awlen => axi_awlen,
        axi_awsize => axi_awsize,
        axi_awburst => axi_awburst,
        axi_awlock => axi_awlock,
        axi_awcache => axi_awcache,
        axi_awprot => axi_awprot,
        axi_awqos => axi_awqos,
        axi_awvalid => axi_awvalid,
        axi_awready => axi_awready,
        
        axi_wdata => axi_wdata,
        axi_wstrb => axi_wstrb,
        axi_wlast => axi_wlast,
        axi_wvalid => axi_wvalid,
        axi_wready => axi_wready,
        
        axi_bid => axi_bid,
        axi_bresp => axi_bresp,
        axi_bvalid => axi_bvalid,
        axi_bready => axi_bready,
        
        axi_arid => axi_arid,
        axi_araddr => axi_araddr,
        axi_arlen => axi_arlen,
        axi_arsize => axi_arsize,
        axi_arburst => axi_arburst,
        axi_arlock => axi_arlock,
        axi_arcache => axi_arcache,
        axi_arprot => axi_arprot,
        axi_arqos => axi_arqos,
        axi_arvalid => axi_arvalid,
        axi_arready => axi_arready,
        
        axi_rid => axi_rid,
        axi_rdata => axi_rdata,
        axi_rresp => axi_rresp,
        axi_rlast => axi_rlast,
        axi_rvalid => axi_rvalid,
        axi_rready => axi_rready,
        
        zoom_mode => zoom_mode,
        freeze => freeze
      );
    
    output : entity work.video_fb_output
      generic map(
        video_hlength => 2200,
        video_vlength => 1125,
        
        video_hsync_pol => true,
        video_hsync_len => 44,
        video_hbp_len => 148,
        video_h_visible => 1920,
        
        video_vsync_pol => true,
        video_vsync_len => 5,
        video_vbp_len => 36,
        video_v_visible => 1080)
      port map(
        pixel_clock => output_pixck,
        reset => system_reset,
        
        fbc_vsync => fbc_ovsync,
        fbc_data => fbc_data,
        
        video_vsync => output_vsync,
        video_hsync => output_hsync,
        video_den => output_den_int,
        video_line_start => output_line_start_int,
        video_data => output_data);
    
    output_den <= output_den_int;
    output_line_start <= output_line_start_int;
    
    memctl : ddr3_if
      port map(
        ddr3_addr => ddr3_addr,
        ddr3_ba => ddr3_ba,
        ddr3_cas_n => ddr3_cas_n,
        ddr3_ck_n => ddr3_ck_n,
        ddr3_ck_p => ddr3_ck_p,
        ddr3_cke => ddr3_cke,
        ddr3_ras_n => ddr3_ras_n,
        ddr3_reset_n => ddr3_reset_n,
        ddr3_we_n => ddr3_we_n,
        ddr3_dq => ddr3_dq,
        ddr3_dqs_p => ddr3_dqs_p,
        ddr3_dqs_n => ddr3_dqs_n,
        init_calib_complete => open,
        ddr3_cs_n => ddr3_cs_n,
        ddr3_dm => ddr3_dm,
        ddr3_odt => ddr3_odt,
        
        ui_clk => ui_clock,
        ui_clk_sync_rst => open,
        mmcm_locked => open,
        aresetn => axi_resetn,
        app_sr_req => '0',
        app_ref_req => '0',
        app_zq_req => '0',
        app_sr_active => open,
        app_ref_ack => open,
        app_zq_ack => open,
        
        s_axi_awid => axi_awid,
        s_axi_awaddr => axi_awaddr,
        s_axi_awlen => axi_awlen,
        s_axi_awsize => axi_awsize,
        s_axi_awburst => axi_awburst,
        s_axi_awlock => axi_awlock,
        s_axi_awcache => axi_awcache,
        s_axi_awprot => axi_awprot,
        s_axi_awqos => axi_awqos,
        s_axi_awvalid => axi_awvalid,
        s_axi_awready => axi_awready,
        
        s_axi_wdata => axi_wdata,
        s_axi_wstrb => axi_wstrb,
        s_axi_wlast => axi_wlast,
        s_axi_wvalid => axi_wvalid,
        s_axi_wready => axi_wready,
        
        s_axi_bid => axi_bid,
        s_axi_bresp => axi_bresp,
        s_axi_bvalid => axi_bvalid,
        s_axi_bready => axi_bready,
        
        s_axi_arid => axi_arid,
        s_axi_araddr => axi_araddr,
        s_axi_arlen => axi_arlen,
        s_axi_arsize => axi_arsize,
        s_axi_arburst => axi_arburst,
        s_axi_arlock => axi_arlock,
        s_axi_arcache => axi_arcache,
        s_axi_arprot => axi_arprot,
        s_axi_arqos => axi_arqos,
        s_axi_arvalid => axi_arvalid,
        s_axi_arready => axi_arready,
        
        s_axi_rid => axi_rid,
        s_axi_rdata => axi_rdata,
        s_axi_rresp => axi_rresp,
        s_axi_rlast => axi_rlast,
        s_axi_rvalid => axi_rvalid,
        s_axi_rready => axi_rready,
        
        sys_clk_i => system_clock,
        sys_rst => '1');

end Behavioral;
