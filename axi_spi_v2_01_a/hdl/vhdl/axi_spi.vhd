-------------------------------------------------------------------------------
--  AXI Serial Peripheral Interface Module - entity/architecture pair
-------------------------------------------------------------------------------
--
-- ************************************************************************
-- ** DISCLAIMER OF LIABILITY                                            **
-- **                                                                    **
-- ** This file contains proprietary and confidential information of     **
-- ** Xilinx, Inc. ("Xilinx"), that is distributed under a license       **
-- ** from Xilinx, and may be used, copied and/or disclosed only         **
-- ** pursuant to the terms of a valid license agreement with Xilinx.    **
-- **                                                                    **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION              **
-- ** ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER         **
-- ** EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT                **
-- ** LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,          **
-- ** MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx      **
-- ** does not warrant that functions included in the Materials will     **
-- ** meet the requirements of Licensee, or that the operation of the    **
-- ** Materials will be uninterrupted or error-free, or that defects     **
-- ** in the Materials will be corrected. Furthermore, Xilinx does       **
-- ** not warrant or make any representations regarding use, or the      **
-- ** results of the use, of the Materials in terms of correctness,      **
-- ** accuracy, reliability or otherwise.                                **
-- **                                                                    **
-- ** Xilinx products are not designed or intended to be fail-safe,      **
-- ** or for use in any application requiring fail-safe performance,     **
-- ** such as life-support or safety devices or systems, Class III       **
-- ** medical devices, nuclear facilities, applications related to       **
-- ** the deployment of airbags, or any other applications that could    **
-- ** lead to death, personal injury or severe property or               **
-- ** environmental damage (individually and collectively, "critical     **
-- ** applications"). Customer assumes the sole risk and liability       **
-- ** of any use of Xilinx products in critical applications,            **
-- ** subject only to applicable laws and regulations governing          **
-- ** limitations on product liability.                                  **
-- **                                                                    **
-- ** Copyright 2010, 2011 Xilinx, Inc.                                  **
-- ** All rights reserved.                                               **
-- **                                                                    **
-- ** This disclaimer and copyright notice must be retained as part      **
-- ** of this file at all times.                                         **
-- ************************************************************************
--
-------------------------------------------------------------------------------
-- Filename:        axi_spi.vhd
-- Version:         v2.01.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit AXI bus and SPI master/slave device(s).
--
-------------------------------------------------------------------------------
-- Structure:   This section shows the hierarchical structure of axi_spi.
--
--              axi_spi.vhd
--              --axi_lite_ipif.vhd
--                    --slave_attachment.vhd
--                       --address_decoder.vhd
--                 --interrupt_control.vhd
--                 --soft_reset.vhd
--                 --srl_fifo.vhd
--                 --spi_receive_transmit_reg.vhd
--                 --spi_cntrl_reg.vhd
--                 --spi_status_slave_sel_reg.vhd
--                 --spi_module.vhd
--                 --spi_fifo_ifmodule.vhd
--                 --spi_occupancy_reg.vhd
-------------------------------------------------------------------------------

-- Author:      SK
-- ~~~~~~
--  - Redesigned version of axi_spi. Based on xps spi v2.01.b
-- ^^^^^^
-- ~~~~~~
--  20/09/20    SK 
--  - Updated the version as AXI Lite IPIF version is updated. 
-- ^^^^^^

-------------------------------------------------------------------------------
-- Naming Conventions:
--      active low signals:                     "*_n"
--      clock signals:                          "clk", "clk_div#", "clk_#x"
--      reset signals:                          "rst", "rst_n"
--      generics:                               "C_*"
--      user defined types:                     "*_TYPE"
--      state machine next state:               "*_ns"
--      state machine current state:            "*_cs"
--      combinatorial signals:                  "*_cmb"
--      pipelined or register delay signals:    "*_d#"
--      counter signals:                        "*cnt*"
--      clock enable signals:                   "*_ce"
--      internal version of output port         "*_i"
--      device pins:                            "*_pin"
--      ports:                                  - Names begin with Uppercase
--      processes:                              "*_PROCESS"
--      component instantiations:               "<ENTITY_>I_<#|FUNC>
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library axi_spi_v2_01_a_proc_common_v3_00_a;
use axi_spi_v2_01_a_proc_common_v3_00_a.proc_common_pkg.all;
use axi_spi_v2_01_a_proc_common_v3_00_a.proc_common_pkg.log2;
use axi_spi_v2_01_a_proc_common_v3_00_a.proc_common_pkg.max2;
use axi_spi_v2_01_a_proc_common_v3_00_a.family_support.all;
use axi_spi_v2_01_a_proc_common_v3_00_a.ipif_pkg.all;

library axi_spi_v2_01_a_axi_lite_ipif_v1_01_a;

library axi_spi_v2_01_a;
    use axi_spi_v2_01_a.spi_core_interface;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------
-- SPI generics
--  C_FIFO_EXIST          --    non-zero if FIFOs exist
--  C_SCK_RATIO           --    2, 4, 16, 32, , , , 1024, 2048 SPI Clock
--                        --    ratios
--  C_NUM_SS_BITS         --    Total number of SS-bits
--  C_NUM_TRANSFER_BITS   --    SPI Serial transfer width.
--                        --    Can be 8, 16 or 32 bit wide
--------------------
-- AXI LITE Generics
--------------------
-- C_S_AXI_DATA_WIDTH    -- AXI data bus width
-- C_S_AXI_ADDR_WIDTH    -- AXI address bus width
-- C_S_AXI_MIN_SIZE      -- Minimum address range of the IP
-- C_USE_WSTRB           -- Use write strobs or not
-- C_DPHASE_TIMEOUT      -- Data phase time out counter
-- C_ARD_ADDR_RANGE_ARRAY-- Base /High Address Pair for each Address Range
-- C_ARD_NUM_CE_ARRAY    -- Desired number of chip enables for an address range
-- C_FAMILY              -- Target FPGA family

-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------
-- S_AXI_ACLK            -- AXI Clock
-- S_AXI_ARESETN          -- AXI Reset
-- S_AXI_AWADDR          -- AXI Write address
-- S_AXI_AWVALID         -- Write address valid
-- S_AXI_AWREADY         -- Write address ready
-- S_AXI_WDATA           -- Write data
-- S_AXI_WSTRB           -- Write strobes
-- S_AXI_WVALID          -- Write valid
-- S_AXI_WREADY          -- Write ready
-- S_AXI_BRESP           -- Write response
-- S_AXI_BVALID          -- Write response valid
-- S_AXI_BREADY          -- Response ready
-- S_AXI_ARADDR          -- Read address
-- S_AXI_ARVALID         -- Read address valid
-- S_AXI_ARREADY         -- Read address ready
-- S_AXI_RDATA           -- Read data
-- S_AXI_RRESP           -- Read response
-- S_AXI_RVALID          -- Read valid
-- S_AXI_RREADY          -- Read ready

-- SPI INTERFACE
--  SCK_I                -- SPI Bus Clock Input
--  SCK_O                -- SPI Bus Clock Output
--  SCK_T                -- SPI Bus Clock 3-state Enable
--                          (3-state when high)
--  MISO_I               -- Master out,Slave in Input
--  MISO_O               -- Master out,Slave in Output
--  MISO_T               -- Master out,Slave in 3-state Enable
--  MOSI_I               -- Master in,Slave out Input
--  MOSI_O               -- Master in,Slave out Output
--  MOSI_T               -- Master in,Slave out 3-state Enable
--  SPISEL               -- Local SPI slave select active low input
--                          has to be initialzed to VCC
--  SS_I                 -- Input of slave select vector
--                          of length N input where there are
--                          N SPI devices,but not connected
--  SS_O                 -- One-hot encoded,active low slave select
--                          vector of length N ouput
--  SS_T                 -- Single 3-state control signal for
--                          slave select vector of length N
--                          (3-state when high)
-- INTERRUPT INTERFACE
--  IP2INTC_Irpt         -- Interrupt signal to interrupt controller

-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------

entity axi_spi is
 generic
  (
--  -- System Parameter
    C_FAMILY              : string                        := "virtex6";
    C_INSTANCE            : string                        := "axi_spi_inst";
--  -- AXI Parameters
    C_BASEADDR            : std_logic_vector(31 downto 0) := X"FFFF_FFFF";
    C_HIGHADDR            : std_logic_vector(31 downto 0) := X"0000_0000";
    C_S_AXI_ADDR_WIDTH    : integer range 32 to 32        := 32;
    C_S_AXI_DATA_WIDTH    : integer range 32 to 128       := 32;
  --SPI generics
    C_FIFO_EXIST          : integer range 0 to 1          := 1;
    C_SCK_RATIO           : integer range 2 to 2048       := 32;
    C_NUM_SS_BITS         : integer range 1 to 32         := 1;
    C_NUM_TRANSFER_BITS   : integer range 8 to 32         := 8
  );
    port (

        --System signals
    S_AXI_ACLK            : in  std_logic;
    S_AXI_ARESETN         : in  std_logic;
    -- AXI Write address channel signals
    S_AXI_AWADDR          : in  std_logic_vector
                            ((C_S_AXI_ADDR_WIDTH-1) downto 0);
    S_AXI_AWVALID         : in  std_logic;
    S_AXI_AWREADY         : out std_logic;
    -- AXI Write data channel signals
    S_AXI_WDATA           : in  std_logic_vector
                            ((C_S_AXI_DATA_WIDTH-1) downto 0);
    S_AXI_WSTRB           : in  std_logic_vector
                            (((C_S_AXI_DATA_WIDTH/8)-1) downto 0);
    S_AXI_WVALID          : in  std_logic;
    S_AXI_WREADY          : out std_logic;
    -- AXI Write response channel signals
    S_AXI_BRESP           : out std_logic_vector(1 downto 0);
    S_AXI_BVALID          : out std_logic;
    S_AXI_BREADY          : in  std_logic;
    -- AXI Read address channel signals
    S_AXI_ARADDR          : in  std_logic_vector
                            ((C_S_AXI_ADDR_WIDTH-1) downto 0);
    S_AXI_ARVALID         : in  std_logic;
    S_AXI_ARREADY         : out std_logic;
    -- AXI Read address channel signals
    S_AXI_RDATA           : out std_logic_vector
                            ((C_S_AXI_DATA_WIDTH-1) downto 0);
    S_AXI_RRESP           : out std_logic_vector(1 downto 0);
    S_AXI_RVALID          : out std_logic;
    S_AXI_RREADY          : in  std_logic;

    --SPI INTERFACE
    
    --SCK                 : inout std_logic;
    --MOSI                : inout std_logic;
    --MISO                : inout std_logic;
    --SS                  : inout std_logic_vector((C_NUM_SS_BITS-1) downto 0);
    
    SCK_I                 : in  std_logic;
    SCK_O                 : out std_logic;
    SCK_T                 : out std_logic;
    
    MISO_I                : in  std_logic;
    MISO_O                : out std_logic;
    MISO_T                : out std_logic;
    
    MOSI_I                : in  std_logic;
    MOSI_O                : out std_logic;
    MOSI_T                : out std_logic;

    SPISEL                : in  std_logic;

    SS_I                  : in  std_logic_vector((C_NUM_SS_BITS-1) downto 0);
    SS_O                  : out std_logic_vector((C_NUM_SS_BITS-1) downto 0);
    SS_T                  : out std_logic;
    -- INTERRUPT INTERFACE
    IP2INTC_Irpt          : out std_logic
);

-------------------------------------------------------------------------------
  -- Fan-Out attributes for XST
-------------------------------------------------------------------------------

    ATTRIBUTE MAX_FANOUT                   : string;
    ATTRIBUTE MAX_FANOUT  of S_AXI_ACLK    : signal is "10000";
    ATTRIBUTE MAX_FANOUT  of S_AXI_ARESETN : signal is "10000";
-----------------------------------------------------------------
  -- Start of PSFUtil MPD attributes
-----------------------------------------------------------------

    ATTRIBUTE ADDR_TYPE   : string;
    ATTRIBUTE ASSIGNMENT  : string;
    ATTRIBUTE HDL         : string;
    ATTRIBUTE IMP_NETLIST : string;
    ATTRIBUTE IPTYPE      : string;
    ATTRIBUTE MIN_SIZE    : string;
    ATTRIBUTE SIGIS       : string;
    ATTRIBUTE STYLE       : string;
-----------------------------------------------------------------
  -- Attribute INITIALVAL added to fix CR 213432
-----------------------------------------------------------------
    ATTRIBUTE INITIALVAL  : string;


    ATTRIBUTE ADDR_TYPE   of  C_BASEADDR   :  constant is  "REGISTER";
    ATTRIBUTE ADDR_TYPE   of  C_HIGHADDR   :  constant is  "REGISTER";
    ATTRIBUTE ASSIGNMENT  of  C_BASEADDR   :  constant is  "REQUIRE";
    ATTRIBUTE ASSIGNMENT  of  C_HIGHADDR   :  constant is  "REQUIRE";
    ATTRIBUTE HDL         of  axi_spi      :  entity   is  "VHDL";
    ATTRIBUTE IMP_NETLIST of  axi_spi      :  entity   is  "TRUE";
    ATTRIBUTE IPTYPE      of  axi_spi      :  entity   is  "PERIPHERAL";

    ATTRIBUTE SIGIS       of  S_AXI_ACLK    :  signal   is  "CLK";
    ATTRIBUTE SIGIS       of  S_AXI_ARESETN :  signal   is  "RST";
    ATTRIBUTE SIGIS       of  IP2INTC_Irpt  :  signal   is  "INTR_LEVEL_HIGH";
    ATTRIBUTE STYLE       of  axi_spi       :  entity   is  "HDL";

    ATTRIBUTE INITIALVAL  of  SPISEL        :  signal   is  "VCC";
end entity axi_spi;
-------------------------------------------------------------------------------
-- Architecture Section
-------------------------------------------------------------------------------
architecture imp of axi_spi is
-------------------------------------------------------------------------------
-- constant added for webtalk information
-------------------------------------------------------------------------------
  constant C_CORE_GENERATION_INFO : string := C_INSTANCE & ",axi_spi,{"
      & "C_FAMILY = "                & C_FAMILY
      & ",C_INSTANCE = "             & C_INSTANCE
      & ",C_S_AXI_ADDR_WIDTH = "     & integer'image(C_S_AXI_ADDR_WIDTH)
      & ",C_S_AXI_DATA_WIDTH = "     & integer'image(C_S_AXI_DATA_WIDTH)
      & ",C_FIFO_EXIST = "           & integer'image(C_FIFO_EXIST)
      & ",C_SCK_RATIO = "            & integer'image(C_SCK_RATIO)
      & ",C_NUM_SS_BITS = "          & integer'image(C_NUM_SS_BITS)
      & ",C_NUM_TRANSFER_BITS = "    & integer'image(C_NUM_TRANSFER_BITS)
      & "}";

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of imp : architecture is C_CORE_GENERATION_INFO;
 ------------------------------
 -- Constant declarations
 ------------------------------
 -- AXI lite parameters
  constant C_S_AXI_SPI_MIN_SIZE  : std_logic_vector(31 downto 0):= X"0000007c";
  constant C_USE_WSTRB           : integer := 1;
  constant C_DPHASE_TIMEOUT      : integer := 8;

 -- core generics
   constant C_FIFO_DEPTH         : integer      := 16;
 --width of spi shift register
   constant C_NUM_BITS_REG       : integer      := 8;
   constant C_OCCUPANCY_NUM_BITS : integer      := 4;
   constant C_NUM_USER_REGS      : integer      := 8;--5 + (2*C_FIFO_EXIST);-- Two
                 -- additional registers are required if FIFOs are optioned in.
   constant IP_INTR_MODE_ARRAY   : INTEGER_ARRAY_TYPE(0 to (8)):=
    (
     others => INTR_REG_EVENT
      -- Seven  interrupts if C_FIFO_EXIST = 0
      -- OR
      -- Eight interrupts if C_FIFO_EXIST = 0 and slave mode
      ----------------------- OR ---------------------------
      -- Nine  interrupts if C_FIFO_EXIST = 1 and slave mode
      -- OR
      -- Seven  interrupts if C_FIFO_EXIST = 1
    );
   constant ZEROES               : std_logic_vector(31 downto 0):= X"00000000";

-- this constant is defined as the start of SPI register addresses.
   constant C_IP_REG_BAR_OFFSET  : std_logic_vector := X"00000060";

   constant C_ARD_ADDR_RANGE_ARRAY : SLV64_ARRAY_TYPE :=
    (
    -- interrupt address base & high range
     ZEROES & C_BASEADDR,
     ZEROES & (C_BASEADDR or X"0000003F"),--interrupt address higher range

    -- soft reset register base & high addr
     ZEROES & (C_BASEADDR or X"00000040"),
     ZEROES & (C_BASEADDR or X"00000043"),--soft reset register high addr

     -- SPI registers Base & High Address
     -- Range is 60 to 78 -- for internal registers
     ZEROES & (C_BASEADDR or C_IP_REG_BAR_OFFSET),
     ZEROES & (C_BASEADDR or C_IP_REG_BAR_OFFSET or X"00000018")
    );

   constant C_ARD_NUM_CE_ARRAY     : INTEGER_ARRAY_TYPE :=
    (
     0 => 16    ,             -- 16  CEs required for interrupt
     1 => 1,                  -- 1   CE  required for soft reset
     2 => C_NUM_USER_REGS
    );

   constant C_NUM_CE_SIGNALS      : integer :=
                                   calc_num_ce(C_ARD_NUM_CE_ARRAY);
   constant C_NUM_CS_SIGNALS      : integer :=
                                   (C_ARD_ADDR_RANGE_ARRAY'LENGTH/2);
-------------------------------------------------------------------------------
 signal bus2ip_clk           : std_logic;
 signal bus2ip_be_int        : std_logic_vector
                                     (((C_S_AXI_DATA_WIDTH/8)-1)downto 0);
 signal bus2ip_cs_int        : std_logic_vector
                                       ((C_NUM_CS_SIGNALS-1)downto 0);
 signal bus2ip_rdce_int      : std_logic_vector
                                       ((C_NUM_CE_SIGNALS-1)downto 0);
 signal bus2ip_wrce_int      : std_logic_vector
                                       ((C_NUM_CE_SIGNALS-1)downto 0);
 signal bus2ip_data_int      : std_logic_vector
                                       ((C_S_AXI_DATA_WIDTH-1)downto 0);
 signal ip2bus_data_int      : std_logic_vector
                                       ((C_S_AXI_DATA_WIDTH-1)downto 0 )
                             := (others  => '0');
 signal ip2bus_wrack_int     : std_logic := '0';
 signal ip2bus_rdack_int     : std_logic := '0';
 signal ip2bus_error_int     : std_logic := '0';

 signal bus2ip_reset_int     : std_logic;

 signal bus2ip_reset_int_core: std_logic;
-------------------------------------------------------------------------------
------------------------
-- Architecture Starts
------------------------
begin  -- architecture IMP
--------------------------------------------------------------------------
-- Instantiate AXI lite IPIF
--------------------------------------------------------------------------
AXI_LITE_IPIF_I : entity axi_spi_v2_01_a_axi_lite_ipif_v1_01_a.axi_lite_ipif
  generic map
   (
    C_S_AXI_ADDR_WIDTH        => C_S_AXI_ADDR_WIDTH,
    C_S_AXI_DATA_WIDTH        => C_S_AXI_DATA_WIDTH,

    C_S_AXI_MIN_SIZE          => C_S_AXI_SPI_MIN_SIZE,
    C_USE_WSTRB               => C_USE_WSTRB,
    C_DPHASE_TIMEOUT          => C_DPHASE_TIMEOUT,

    C_ARD_ADDR_RANGE_ARRAY    => C_ARD_ADDR_RANGE_ARRAY,
    C_ARD_NUM_CE_ARRAY        => C_ARD_NUM_CE_ARRAY,
    C_FAMILY                  => C_FAMILY
   )
 port map
   (
    S_AXI_ACLK                =>  S_AXI_ACLK,           -- in
    S_AXI_ARESETN             =>  S_AXI_ARESETN,         -- in

    S_AXI_AWADDR              =>  S_AXI_AWADDR,         -- in
    S_AXI_AWVALID             =>  S_AXI_AWVALID,        -- in
    S_AXI_AWREADY             =>  S_AXI_AWREADY,        -- out
    S_AXI_WDATA               =>  S_AXI_WDATA,          -- in
    S_AXI_WSTRB               =>  S_AXI_WSTRB,          -- in
    S_AXI_WVALID              =>  S_AXI_WVALID,         -- in
    S_AXI_WREADY              =>  S_AXI_WREADY,         -- out
    S_AXI_BRESP               =>  S_AXI_BRESP,          -- out
    S_AXI_BVALID              =>  S_AXI_BVALID,         -- out
    S_AXI_BREADY              =>  S_AXI_BREADY,         -- in
    S_AXI_ARADDR              =>  S_AXI_ARADDR,         -- in
    S_AXI_ARVALID             =>  S_AXI_ARVALID,        -- in
    S_AXI_ARREADY             =>  S_AXI_ARREADY,        -- out
    S_AXI_RDATA               =>  S_AXI_RDATA,          -- out
    S_AXI_RRESP               =>  S_AXI_RRESP,          -- out
    S_AXI_RVALID              =>  S_AXI_RVALID,         -- out
    S_AXI_RREADY              =>  S_AXI_RREADY,         -- in

 -- IP Interconnect (IPIC) port signals
    Bus2IP_Clk                => bus2ip_clk,                -- out
    Bus2IP_Resetn             => bus2ip_reset_int,          -- out

    Bus2IP_Addr               => open, -- bus2ip_addr_int,  -- out
    Bus2IP_RNW                => open,                      -- out
    Bus2IP_BE                 => bus2ip_be_int,             -- out
    Bus2IP_CS                 => bus2ip_cs_int,             -- out
    Bus2IP_RdCE               => bus2ip_rdce_int,           -- out
    Bus2IP_WrCE               => bus2ip_wrce_int,           -- out
    Bus2IP_Data               => bus2ip_data_int,           -- out

    IP2Bus_Data               => ip2bus_data_int,           -- in
    IP2Bus_WrAck              => ip2bus_wrack_int,          -- in
    IP2Bus_RdAck              => ip2bus_rdack_int,          -- in
    IP2Bus_Error              => ip2bus_error_int           -- in
   );


  ----------------------
  --REG_RESET_FROM_IPIF: convert active low to active hig reset to rest of
  --                     the core.
  ----------------------
  REG_RESET_FROM_IPIF: process (S_AXI_ACLK) is
  begin
       if(S_AXI_ACLK'event and S_AXI_ACLK = '1') then
           bus2ip_reset_int_core <= not(bus2ip_reset_int);
       end if;
  end process REG_RESET_FROM_IPIF;

--    --------------------------------------------------------------------------
--    -- Instansiating the SPI core
--    --------------------------------------------------------------------------

AXI_SPI_CORE_INTERFACE_I : entity axi_spi_v2_01_a.spi_core_interface
  generic map
   (
    C_S_AXI_ADDR_WIDTH        => C_S_AXI_ADDR_WIDTH,
    C_S_AXI_DATA_WIDTH        => C_S_AXI_DATA_WIDTH,
    C_NUM_CE_SIGNALS          => C_NUM_CE_SIGNALS,
    C_NUM_CS_SIGNALS          => C_NUM_CS_SIGNALS,

    -- SPI generics
    C_NUM_BITS_REG            => C_NUM_BITS_REG,
    C_OCCUPANCY_NUM_BITS      => C_OCCUPANCY_NUM_BITS,
    C_FIFO_DEPTH              => C_FIFO_DEPTH,
    C_IP_INTR_MODE_ARRAY      => IP_INTR_MODE_ARRAY,
    C_FIFO_EXIST              => C_FIFO_EXIST,
    C_SCK_RATIO               => C_SCK_RATIO,
    C_NUM_SS_BITS             => C_NUM_SS_BITS,
    C_NUM_TRANSFER_BITS       => C_NUM_TRANSFER_BITS
   )
   port map
   (
 -- IP Interconnect (IPIC) port signals
    Bus2IP_Clk                => bus2ip_clk,
    Bus2IP_Reset              => bus2ip_reset_int_core,

    Bus2IP_BE                 => bus2ip_be_int,
    Bus2IP_CS                 => bus2ip_cs_int,
    Bus2IP_RdCE               => bus2ip_rdce_int,
    Bus2IP_WrCE               => bus2ip_wrce_int,
    Bus2IP_Data               => bus2ip_data_int,

    IP2Bus_Data               => ip2bus_data_int,
    IP2Bus_WrAck              => ip2bus_wrack_int,
    IP2Bus_RdAck              => ip2bus_rdack_int,
    IP2Bus_Error              => ip2bus_error_int,

    --SPI Ports
--SCK                       => SCK ,
--MOSI                      => MOSI,
--MISO                      => MISO,
--SS                        => SS  ,
    SCK_I                     => SCK_I,
    SCK_O                     => SCK_O,
    SCK_T                     => SCK_T,
    
    MISO_I                    => MISO_I,
    MISO_O                    => MISO_O,
    MISO_T                    => MISO_T,
    
    MOSI_I                    => MOSI_I,
    MOSI_O                    => MOSI_O,
    MOSI_T                    => MOSI_T,

    SPISEL                    => SPISEL,

    SS_I                      => SS_I,
    SS_O                      => SS_O,
    SS_T                      => SS_T,

    IP2INTC_Irpt              => IP2INTC_Irpt
   );
end architecture imp;
