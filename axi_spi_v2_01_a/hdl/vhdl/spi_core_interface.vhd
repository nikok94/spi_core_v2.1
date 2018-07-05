-------------------------------------------------------------------------------
--  spi_core_interface Module - entity/architecture pair
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
-- Filename:        spi_core_interface.vhd
-- Version:         v1.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit AXI bus.
--
-------------------------------------------------------------------------------
-- Structure:   This section shows the hierarchical structure of xps_spi.
--
--              axi_spi.vhd
--              --axi_lite_ipif.vhd
--                    --slave_attachment.vhd
--                       --address_decoder.vhd
--              --spi_core_interface.vhd
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
-- SK           6-jun-2011
-- ~~~~~~
--  -- Fixed CR #610995. SS_O bit positions are corrected.
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

library axi_spi_v2_01_a_interrupt_control_v2_01_a;

library axi_spi_v2_01_a;
    use axi_spi_v2_01_a.all;
library UNISIM;
  use UNISIM.VComponents.all;
-------------------------------------------------------------------------------

entity spi_core_interface is
generic(
        --  -- AXI Parameters
        C_S_AXI_ADDR_WIDTH    : integer range 32 to 32 := 32;
        C_S_AXI_DATA_WIDTH    : integer range 32 to 128:= 32;

        C_NUM_CE_SIGNALS      : integer;
        C_NUM_CS_SIGNALS      : integer;
        C_IP_INTR_MODE_ARRAY  : INTEGER_ARRAY_TYPE;

        --SPI generics
        C_NUM_BITS_REG        : integer;
        C_OCCUPANCY_NUM_BITS  : integer;
        C_FIFO_DEPTH          : integer;
        C_FIFO_EXIST          : integer range 0 to 1   := 1;
        C_SCK_RATIO           : integer range 2 to 2048:= 32;
        C_NUM_SS_BITS         : integer range 1 to 32  := 1;
        C_NUM_TRANSFER_BITS   : integer                := 8
       );
   port(
        Bus2IP_Clk          : in std_logic;
        Bus2IP_Reset        : in std_logic;

        Bus2IP_BE           : in std_logic_vector
                                        (0 to ((C_S_AXI_DATA_WIDTH/8)-1));
        Bus2IP_CS           : in std_logic_vector
                                              (0 to (C_NUM_CS_SIGNALS-1));
        Bus2IP_RdCE         : in  std_logic_vector
                                              (0 to (C_NUM_CE_SIGNALS-1));
        Bus2IP_WrCE         : in  std_logic_vector
                                              (0 to (C_NUM_CE_SIGNALS-1));
        Bus2IP_Data         : in std_logic_vector
                                            (0 to (C_S_AXI_DATA_WIDTH-1));

        IP2Bus_Data         : out std_logic_vector
                                            (0 to (C_S_AXI_DATA_WIDTH-1));
        IP2Bus_WrAck        : out std_logic;
        IP2Bus_RdAck        : out std_logic;
        IP2Bus_Error        : out std_logic;

        --SPI Ports         :
--        SCK                 : inout std_logic;
--        MOSI                : inout std_logic;
--        MISO                : inout std_logic;
--        SS                  : inout std_logic_vector((C_NUM_SS_BITS-1) downto 0);

        
        SCK_I               : in  std_logic;
        SCK_O               : out std_logic;
        SCK_T               : out std_logic;

        MISO_I              : in  std_logic;
        MISO_O              : out std_logic;
        MISO_T              : out std_logic;

        MOSI_I              : in  std_logic;
        MOSI_O              : out std_logic;
        MOSI_T              : out std_logic;

        SPISEL              : in  std_logic;

        SS_I                : in  std_logic_vector((C_NUM_SS_BITS-1) downto 0);
        SS_O                : out std_logic_vector((C_NUM_SS_BITS-1) downto 0);
        SS_T                : out std_logic;

        IP2INTC_Irpt        : out std_logic
       );

end entity spi_core_interface;

-------------------------------------------------------------------------------
------------
architecture imp of spi_core_interface is
------------

-- These constants are indices into the "CE" arrays for the various registers.
 constant INTR_LO  : natural :=  0;
 constant INTR_HI  : natural := 15;
 constant SWRESET  : natural := 16;
 constant SPICR    : natural := 17;
 constant SPISR    : natural := 18;
 constant SPIDTR   : natural := 19;
 constant SPIDRR   : natural := 20;
 constant SPISSR   : natural := 21;
 constant SPITFOR  : natural := 22;
 constant SPIRFOR  : natural := 23;
 
 constant REG_HOLE : natural := 24;
 --SPI MODULE SIGNALS
 signal spiXfer_done_int         : std_logic;
 signal dtr_underrun_int         : std_logic;
 signal modf_strobe_int          : std_logic;
 signal slave_MODF_strobe_int    : std_logic;

 --OR REGISTER/FIFO SIGNALS
 --TO/FROM REG/FIFO DATA
 signal receive_Data_int       : std_logic_vector(0 to (C_NUM_TRANSFER_BITS-1));
 signal transmit_Data_int      : std_logic_vector(0 to (C_NUM_TRANSFER_BITS-1));

 --Extra bit required for signal Register_Data_ctrl
 signal register_Data_cntrl_int :std_logic_vector(0 to (C_NUM_BITS_REG+3));
 signal register_Data_slvsel_int:std_logic_vector(0 to (C_NUM_SS_BITS-1));
 signal reg2SA_Data_cntrl_int   :std_logic_vector(0 to (C_NUM_BITS_REG+3));
 signal reg2SA_Data_status_int  :std_logic_vector(0 to (C_NUM_BITS_REG-1));
 signal reg2SA_Data_receive_int :std_logic_vector(0 to (C_NUM_TRANSFER_BITS-1));
 signal reg2SA_Data_receive_plb_int:
                                  std_logic_vector(0 to (C_S_AXI_DATA_WIDTH-1));
 signal reg2SA_Data_slvsel_int  : std_logic_vector(0 to (C_NUM_SS_BITS-1));
 signal reg2SA_Data_TxOccupancy_int:
                                std_logic_vector(0 to (C_OCCUPANCY_NUM_BITS-1));
 signal reg2SA_Data_RcOccupancy_int:
                                std_logic_vector(0 to (C_OCCUPANCY_NUM_BITS-1));

 --STATUS REGISTER SIGNALS
 signal sr_3_MODF_int            : std_logic;
 signal sr_4_Tx_Full_int         : std_logic;
 signal sr_5_Tx_Empty_int        : std_logic;
 signal sr_6_Rx_Full_int         : std_logic;
 signal sr_7_Rx_Empty_int        : std_logic;

 --RECEIVE AND TRANSMIT REGISTER SIGNALS
 signal drr_Overrun_int          : std_logic;
 signal dtr_Underrun_strobe_int  : std_logic;
 --FIFO SIGNALS
 signal rc_FIFO_Full_strobe_int  : std_logic;
 signal rc_FIFO_occ_Reversed_int :std_logic_vector
                                           (0 to (C_OCCUPANCY_NUM_BITS-1));
 signal rc_FIFO_Data_Out_int     : std_logic_vector
                                            (0 to (C_NUM_TRANSFER_BITS-1));
 signal data_Exists_RcFIFO_int   : std_logic;
 signal tx_FIFO_Empty_strobe_int : std_logic;
 signal tx_FIFO_occ_Reversed_int : std_logic_vector
                                            (0 to (C_OCCUPANCY_NUM_BITS-1));
 signal data_Exists_TxFIFO_int   : std_logic;
 signal data_From_TxFIFO_int     : std_logic_vector
                                            (0 to (C_NUM_TRANSFER_BITS-1));
 signal tx_FIFO_less_half_int    : std_logic;
 signal reset_TxFIFO_ptr_int     : std_logic;
 signal reset_RcFIFO_ptr_int     : std_logic;
 signal ip2Bus_Data_Reg_int      : std_logic_vector
                                            (0 to (C_S_AXI_DATA_WIDTH-1));
 signal ip2Bus_Data_occupancy_int: std_logic_vector
                                            (0 to (C_S_AXI_DATA_WIDTH-1));
 signal ip2Bus_Data_SS_int       : std_logic_vector
                                            (0 to (C_S_AXI_DATA_WIDTH-1));

 -- interface between signals on instance basis
 signal bus2IP_Reset_int         : std_logic;


 
 signal bus2IP_Data_processed  : std_logic_vector
                                (0 to C_S_AXI_DATA_WIDTH-1);
 
 signal ip2Bus_Error_int         : std_logic;
 signal ip2Bus_WrAck_int         : std_logic := '0';
 signal ip2Bus_RdAck_int         : std_logic := '0';
 signal ip2Bus_IntrEvent_int     : std_logic_vector
                                       (0 to (C_IP_INTR_MODE_ARRAY'length-1));
 signal transmit_ip2bus_error    : std_logic;
 signal receive_ip2bus_error     : std_logic;

 -- SOFT RESET SIGNALS
 signal reset2ip_reset_int       : std_logic;
 signal rst_ip2bus_wrack         : std_logic;
 signal rst_ip2bus_error         : std_logic;
 signal rst_ip2bus_rdack         : std_logic;

 -- INTERRUPT SIGNALS
 signal intr_ip2bus_data         : std_logic_vector
                                               (0 to (C_S_AXI_DATA_WIDTH-1));
 signal intr_ip2bus_rdack        : std_logic;
 signal intr_ip2bus_wrack        : std_logic;
 signal intr_ip2bus_error        : std_logic;
 signal ip2bus_error_RdWr        : std_logic;
 --

 signal wr_ce_reduce_ack_gen: std_logic;
 --

 signal rd_ce_reduce_ack_gen     : std_logic;
 --
 signal control_bit_9_10_int      : std_logic_vector(0 to 1);

 signal spisel_pulse_o_int       : std_logic;
 signal spisel_d1_reg            : std_logic;
 signal Mst_N_Slv_mode           : std_logic;
-----
 signal bus2ip_intr_rdce         : std_logic_vector(INTR_LO to INTR_HI);
 signal bus2ip_intr_wrce         : std_logic_vector(INTR_LO to INTR_HI);

 signal ip2Bus_RdAck_intr_reg_hole      : std_logic;
 signal ip2Bus_RdAck_intr_reg_hole_d1   : std_logic;
 signal ip2Bus_WrAck_intr_reg_hole      : std_logic;
 signal ip2Bus_WrAck_intr_reg_hole_d1   : std_logic;
 signal intr_controller_rd_ce_or_reduce : std_logic;
 signal intr_controller_wr_ce_or_reduce : std_logic;

 signal wr_ce_or_reduce_core_reg        : std_logic;
 signal ip2Bus_WrAck_core_reg_d1        : std_logic;
 signal ip2Bus_WrAck_core_reg           : std_logic;

 signal rd_ce_or_reduce_core_reg        : std_logic;
 signal ip2Bus_RdAck_core_reg_d1        : std_logic;
 signal ip2Bus_RdAck_core_reg           : std_logic;
 
 signal SPI_MODE                        : std_logic;    -- when SPI_MODE = 0 then 4-wire mode else if SPI_MODE = 1 then 3-wire mode
 signal MISO_I_spi_module               : std_logic;
--------------------------------------------------------------------------------
begin
-----------------------------------
-- Combinatorial operations for SPI
-----------------------------------
-- A write to read only register wont have any effect on register.
-- The transaction is completed by generating WrAck only.

--------------------------------------------------------
-- IP2Bus_Error is generated under following conditions:
-- 1. If an full transmit register/FIFO is written into.
-- 2. If an empty receive register/FIFO is read from.
-- Due to software driver legacy, the register rule test is not applied to SPI.
--------------------------------------------------------
  ip2Bus_Error_int      <= intr_ip2bus_error     or
                           rst_ip2bus_error      or
                           transmit_ip2bus_error or
                           receive_ip2bus_error;

  IP2Bus_Error          <= ip2Bus_Error_int;


-- =============================================================================
 wr_ce_or_reduce_core_reg <= Bus2IP_WrCE(SPISR)  or -- read only register
                             Bus2IP_WrCE(SPIDRR) or -- read only register
                             Bus2IP_WrCE(SPIDTR) or -- common to
                                                    -- spi_fifo_ifmodule_1 and
                                                    -- spi_receive_reg_1
                                                    -- (FROM TRANSMITTER) module
                             Bus2IP_WrCE(SPICR)  or
                             Bus2IP_WrCE(SPISSR) or
                             Bus2IP_WrCE(SPITFOR)or -- locally generated
                             Bus2IP_WrCE(SPIRFOR)or -- locally generated
                             Bus2IP_WrCE(REG_HOLE); -- register hole

-- I_WRITE_ACK_CORE_REG   : The commong write ACK generation logic when FIFO is
-- ------------------------ not included in the design.
--------------------------------------------------
-- _____|-----|__________  wr_ce_or_reduce_fifo_no
-- ________|-----|_______  ip2Bus_WrAck_fifo_no_d1
-- ________|--|__________  ip2Bus_WrAck_fifo_no from common write ack register
--                         this ack will be used in register files for
--                         reference.
--------------------------------------------------
I_WRITE_ACK_CORE_REG: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset_int = RESET_ACTIVE) then
          ip2Bus_WrAck_core_reg_d1 <= '0';
          ip2Bus_WrAck_core_reg    <= '0';
      else
          ip2Bus_WrAck_core_reg_d1 <= wr_ce_or_reduce_core_reg;
          ip2Bus_WrAck_core_reg    <= wr_ce_or_reduce_core_reg and
                                                 (not ip2Bus_WrAck_core_reg_d1);
      end if;
    end if;
end process I_WRITE_ACK_CORE_REG;
-------------------------------------------------
-- internal logic uses this signal

wr_ce_reduce_ack_gen <= ip2Bus_WrAck_core_reg;
-------------------------------------------------
-- common WrAck to IPIF

ip2Bus_WrAck_int <= intr_ip2bus_wrack          or -- common
                    rst_ip2bus_wrack           or -- common
                    ip2Bus_WrAck_intr_reg_hole or -- 5/19/2010
                    ip2Bus_WrAck_core_reg;

IP2Bus_WrAck     <= ip2Bus_WrAck_int;
-------------------------------------------------

rd_ce_or_reduce_core_reg <= Bus2IP_RdCE(SWRESET) or --common locally generated
                            Bus2IP_RdCE(SPIDTR)  or --common locally generated
                            Bus2IP_RdCE(SPISR)   or --common from status register
                            Bus2IP_RdCE(SPIDRR)  or --common to
                                                    --spi_fifo_ifmodule_1
                                                    --and spi_receive_reg_1
                                                    --(FROM RECEIVER) module
                            Bus2IP_RdCE(SPICR)   or --common spi_cntrl_reg_1
                            Bus2IP_RdCE(SPISSR)  or --common spi_status_reg_1
                            Bus2IP_RdCE(SPITFOR) or --only for fifo_occu TX reg
                            Bus2IP_RdCE(SPIRFOR) or --only for fifo_occu RX reg
                            Bus2IP_RdCE(REG_HOLE);  --reg hole

-- I_READ_ACK_CORE_REG   : The commong write ACK generation logic
--------------------------------------------------
-- _____|-----|__________  wr_ce_or_reduce_fifo_no
-- ________|-----|_______  ip2Bus_WrAck_fifo_no_d1
-- ________|--|__________  ip2Bus_WrAck_fifo_no from common write ack register
--                         this ack will be used in register files for
--                         reference.
--------------------------------------------------
I_READ_ACK_CORE_REG: process(Bus2IP_Clk) is
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset_int = RESET_ACTIVE) then
          ip2Bus_RdAck_core_reg_d1 <= '0';
          ip2Bus_RdAck_core_reg    <= '0';
      else
          ip2Bus_RdAck_core_reg_d1 <= rd_ce_or_reduce_core_reg;
          ip2Bus_RdAck_core_reg    <= rd_ce_or_reduce_core_reg and
                                                 (not ip2Bus_RdAck_core_reg_d1);
      end if;
    end if;
end process I_READ_ACK_CORE_REG;
-------------------------------------------------
-- internal logic uses this signal

rd_ce_reduce_ack_gen <= ip2Bus_RdAck_core_reg;
-------------------------------------------------
-- common RdAck to IPIF

ip2Bus_RdAck_int     <= intr_ip2bus_rdack          or      -- common
                        ip2Bus_RdAck_intr_reg_hole or 
                        ip2Bus_RdAck_core_reg;

IP2Bus_RdAck         <= ip2Bus_RdAck_int;
------------------------------------------------- 
-- -- =============================================================================

--*****************************************************************************
ip2Bus_Data_occupancy_int(0 to (C_S_AXI_DATA_WIDTH-C_OCCUPANCY_NUM_BITS-1))
                         <= (others => '0');

ip2Bus_Data_occupancy_int((C_S_AXI_DATA_WIDTH-C_OCCUPANCY_NUM_BITS)
                                         to (C_S_AXI_DATA_WIDTH-1))
                         <= reg2SA_Data_RcOccupancy_int or
                            reg2SA_Data_TxOccupancy_int;

-------------------------------------------------------------------------------
-- SPECIAL_CASE_WHEN_SS_NOT_EQL_32 : The Special case is executed whenever
--                                   C_NUM_SS_BITS is less than 32
-------------------------------------------------------------------------------

  SPECIAL_CASE_WHEN_SS_NOT_EQL_32: if(C_NUM_SS_BITS /= 32) generate
  begin
     ip2Bus_Data_SS_int(0 to (C_S_AXI_DATA_WIDTH-C_NUM_SS_BITS-1))
                                                 <= (others => '0');
  end generate SPECIAL_CASE_WHEN_SS_NOT_EQL_32;


  ip2Bus_Data_SS_int((C_S_AXI_DATA_WIDTH-C_NUM_SS_BITS)
                     to (C_S_AXI_DATA_WIDTH-1))
                                                 <= reg2SA_Data_slvsel_int;

-------------------------------------------------------------------------------
  ip2Bus_Data_Reg_int(0 to C_S_AXI_DATA_WIDTH-C_NUM_BITS_REG-5)
                                                 <= (others => '0');
  
  ip2Bus_Data_Reg_int((C_S_AXI_DATA_WIDTH-C_NUM_BITS_REG-4)
                  to (C_S_AXI_DATA_WIDTH-C_NUM_BITS_REG-1))
               <= reg2SA_Data_cntrl_int(0 to 3);-- 4 Extra bit in control reg

  ip2Bus_Data_Reg_int((C_S_AXI_DATA_WIDTH-C_NUM_BITS_REG)
                  to (C_S_AXI_DATA_WIDTH-1))
               <= reg2SA_Data_cntrl_int( 4 to (C_NUM_BITS_REG+3)) or
                  reg2SA_Data_status_int;

-------------------------------------------------------------------------------
  -----------------------
  Receive_Reg_width_is_32: if(C_NUM_TRANSFER_BITS = 32) generate
  -----------------------
  begin
      reg2SA_Data_receive_plb_int <= reg2SA_Data_receive_int;
  end generate Receive_Reg_width_is_32;

  ---------------------------
  Receive_Reg_width_is_not_32: if(C_NUM_TRANSFER_BITS /= 32) generate
  ---------------------------
  begin
    reg2SA_Data_receive_plb_int(0 to C_S_AXI_DATA_WIDTH-C_NUM_TRANSFER_BITS-1)
                              <= (others => '0');
    reg2SA_Data_receive_plb_int(C_S_AXI_DATA_WIDTH-C_NUM_TRANSFER_BITS
                              to C_S_AXI_DATA_WIDTH-1)
                              <= reg2SA_Data_receive_int;
  end generate Receive_Reg_width_is_not_32;

-------------------------------------------------------------------------------

  ip2Bus_Data      <= ip2Bus_Data_occupancy_int or
                      ip2Bus_Data_SS_int        or
                      ip2Bus_Data_Reg_int       or
                      intr_ip2bus_data          or
                      reg2SA_Data_receive_plb_int;

-------------------------------------------------------------------------------
--------------------------------------
-- MAP_SIGNALS_AND_REG_WITHOUT_FIFOS : Signals initialisation and module
--                                     instantiation when C_FIFO_EXIST = 0
--------------------------------------

  MAP_SIGNALS_AND_REG_WITHOUT_FIFOS: if(C_FIFO_EXIST = 0) generate

  begin
     rc_FIFO_Full_strobe_int      <= '0';
     rc_FIFO_occ_Reversed_int     <= (others => '0');
     rc_FIFO_Data_Out_int         <= (others => '0');
     data_Exists_RcFIFO_int       <= '0';
     tx_FIFO_Empty_strobe_int     <= '0';
     tx_FIFO_occ_Reversed_int     <= (others => '0');
     data_Exists_TxFIFO_int       <= '0';
     data_From_TxFIFO_int         <= (others => '0');
     tx_FIFO_less_half_int        <= '0';
     reset_TxFIFO_ptr_int         <= '0';
     reset_RcFIFO_ptr_int         <= '0';
     reg2SA_Data_RcOccupancy_int  <= (others => '0');
     reg2SA_Data_TxOccupancy_int  <= (others => '0');
     sr_4_Tx_Full_int             <= not(sr_5_Tx_Empty_int);
     sr_6_Rx_Full_int             <= not(sr_7_Rx_Empty_int);
     --------------------------------------------------------------------------
     -- below code manipulates the bus2ip_data going towards interrupt control
     -- unit. In FIFO=0, case bit 23 and 25 of IPIER are not applicable.
     bus2IP_Data_processed(0 to 22) <= Bus2IP_Data(0 to 22);
     bus2IP_Data_processed(23)      <= '0';
     bus2IP_Data_processed(24)      <= Bus2IP_Data(24);
     bus2IP_Data_processed(25)      <= '0';
     bus2IP_Data_processed(26 to (C_S_AXI_DATA_WIDTH-1)) <=
                                  Bus2IP_Data(26 to (C_S_AXI_DATA_WIDTH-1));
     --------------------------------------------------------------------------

     -- Interrupt Status Register(IPISR) Mapping
     ip2Bus_IntrEvent_int(8)      <= '0';
     ip2Bus_IntrEvent_int(7)      <= spisel_pulse_o_int;
     ip2Bus_IntrEvent_int(6)      <= '0'; --
     ip2Bus_IntrEvent_int(5)      <= drr_Overrun_int;
     ip2Bus_IntrEvent_int(4)      <= spiXfer_done_int;
     ip2Bus_IntrEvent_int(3)      <= dtr_Underrun_strobe_int;
     ip2Bus_IntrEvent_int(2)      <= spiXfer_done_int;
     ip2Bus_IntrEvent_int(1)      <= slave_MODF_strobe_int;
     ip2Bus_IntrEvent_int(0)      <= modf_strobe_int;

-------------------------------------------------------------------------------
-- I_RECEIVE_REG : INSTANTIATE RECEIVE REGISTER
-------------------------------------------------------------------------------

       I_RECEIVE_REG: entity axi_spi_v2_01_a.spi_receive_transmit_reg
          generic map
               (
                C_DBUS_WIDTH            => C_S_AXI_DATA_WIDTH,
                C_NUM_TRANSFER_BITS     => C_NUM_TRANSFER_BITS
               )
          port map
               (
                Bus2IP_Clk              => Bus2IP_Clk,             -- in
                Reset                   => reset2ip_reset_int,     -- in

            --SPI Receiver signals
                Bus2IP_Receive_Reg_RdCE => Bus2IP_RdCE(SPIDRR),    -- in
                Receive_ip2bus_error    => receive_ip2bus_error,   -- out

            --SPI module ports
                Reg2SA_Data             => reg2SA_Data_receive_int,-- out
                DRR_Overrun             => drr_Overrun_int,        -- out
                SR_7_Rx_Empty           => sr_7_Rx_Empty_int,      -- out
                IP2Reg_Data             => receive_Data_int,       -- in vec
                SPIXfer_done            => spiXfer_done_int,       -- in

            --SPI Transmitter signals
                Bus2IP_Data_sa          => Bus2IP_Data,            -- in vec
                Bus2IP_Transmit_Reg_WrCE=> Bus2IP_WrCE(SPIDTR),    -- in
                transmit_ip2bus_error   => transmit_ip2bus_error,  -- out

            --SPI module ports
                Register_Data           => transmit_Data_int,      -- out vec
                SR_5_Tx_Empty           => sr_5_Tx_Empty_int,      -- out
                DTR_Underrun_strobe     => dtr_Underrun_strobe_int,-- out
                DTR_underrun            => dtr_underrun_int,       -- in
                Wr_ce_reduce_ack_gen    => wr_ce_reduce_ack_gen,   -- in
                Rd_ce_reduce_ack_gen    => rd_ce_reduce_ack_gen    -- in
               );

end generate MAP_SIGNALS_AND_REG_WITHOUT_FIFOS;

-------------------------------------------------------------------------------
-- MAP_SIGNALS_AND_REG_WITH_FIFOS : Signals initialisation and module
--                                  instantiation when C_FIFO_EXIST = 1
-------------------------------------------------------------------------------
MAP_SIGNALS_AND_REG_WITH_FIFOS: if(C_FIFO_EXIST /= 0) generate
------------------------------
signal IP2Bus_RdAck_receive_enable  : std_logic;
signal IP2Bus_WrAck_transmit_enable : std_logic;

signal data_Exists_RcFIFO_int_d1: std_logic;
signal data_Exists_RcFIFO_pulse : std_logic;

begin

     ----------------------------------------------------
     -- _____|-------------  data_Exists_RcFIFO_int
     -- ________|----------  data_Exists_RcFIFO_int_d1
     -- _____|--|__________  data_Exists_RcFIFO_pulse
     ----------------------------------------------------
     I_DRR_NOT_EMPTY_PULSE_P: process(Bus2IP_Clk) is
     begin
         if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
           if (reset2ip_reset_int = RESET_ACTIVE) then
               data_Exists_RcFIFO_int_d1 <= '0';
           else
               data_Exists_RcFIFO_int_d1 <= data_Exists_RcFIFO_int;
           end if;
         end if;
     end process I_DRR_NOT_EMPTY_PULSE_P;
     ------------------------------------
 -- when FIFO = 1, the all other the IPIER, IPISR interrupt bits are applicable.
 -- DRR_Not_Empty bit - available only in case of core is selected in slave mode
 --                 and control register mst_n_slv bit is '0'.
 -- Slave_select_mode bit-available only in case of core is selected in slave mode

     bus2IP_Data_processed(0 to 22) <= Bus2IP_Data(0 to 22);
     bus2IP_Data_processed(23)      <= Bus2IP_Data(23)     and
                                       ((not spisel_d1_reg) or
                                        (not Mst_N_Slv_mode));
     bus2IP_Data_processed(24)      <= Bus2IP_Data(24);
     bus2IP_Data_processed(25 to (C_S_AXI_DATA_WIDTH-1)) <=
                                  Bus2IP_Data(25 to (C_S_AXI_DATA_WIDTH-1));
     ------------------------------------------
     data_Exists_RcFIFO_pulse  <= data_Exists_RcFIFO_int and
                                 (not data_Exists_RcFIFO_int_d1);
     ---------------------------------------------------------------------------

     -- Interrupt Status Register(IPISR) Mapping
     ip2Bus_IntrEvent_int(8)  <= data_Exists_RcFIFO_pulse and
                                 ((not spisel_d1_reg)or(not Mst_N_Slv_mode));
     ip2Bus_IntrEvent_int(7)  <= spisel_pulse_o_int;

     ip2Bus_IntrEvent_int(6)  <= tx_FIFO_less_half_int;
     ip2Bus_IntrEvent_int(5)  <= drr_Overrun_int;
     ip2Bus_IntrEvent_int(4)  <= rc_FIFO_Full_strobe_int;
     ip2Bus_IntrEvent_int(3)  <= dtr_Underrun_strobe_int;
     ip2Bus_IntrEvent_int(2)  <= tx_FIFO_Empty_strobe_int;
     ip2Bus_IntrEvent_int(1)  <= slave_MODF_strobe_int;
     ip2Bus_IntrEvent_int(0)  <= modf_strobe_int;

     --Combinatorial operations
     reset_TxFIFO_ptr_int <= reset2ip_reset_int or register_Data_cntrl_int(6);
     reset_RcFIFO_ptr_int <= reset2ip_reset_int or register_Data_cntrl_int(5);
     sr_5_Tx_Empty_int    <= not data_Exists_TxFIFO_int;
     sr_7_Rx_Empty_int    <= not data_Exists_RcFIFO_int;

-------------------------------------------------------------------------------
-- I_RECEIVE_FIFO : INSTANTIATE RECEIVE FIFO
-------------------------------------------------------------------------------
 IP2Bus_RdAck_receive_enable  <= (rd_ce_reduce_ack_gen and
                                  Bus2IP_RdCE(SPIDRR))
                                  and (not sr_7_Rx_Empty_int);

     RECEIVE_FIFO_I: entity axi_spi_v2_01_a_proc_common_v3_00_a.srl_fifo
        generic map
             (
              C_DATA_BITS => C_NUM_TRANSFER_BITS,
              C_DEPTH     => C_FIFO_DEPTH
             )
        port map
             (
              Clk         => Bus2IP_Clk,                        -- in
              Reset       => reset_RcFIFO_ptr_int,              -- in
              FIFO_Write  => spiXfer_done_int,                  -- in
              Data_In     => receive_Data_int,                  -- in
              FIFO_Read   => IP2Bus_RdAck_receive_enable,       -- in

              Data_Out    => rc_FIFO_Data_Out_int,              -- out
              FIFO_Full   => sr_6_Rx_Full_int,                  -- out
              Data_Exists => data_Exists_RcFIFO_int,            -- out
              Addr        => rc_FIFO_occ_Reversed_int           -- out
             );

-------------------------------------------------------------------------------
-- TRANSMIT_FIFO_I : INSTANTIATE TRANSMIT REGISTER
-------------------------------------------------------------------------------
  IP2Bus_WrAck_transmit_enable <= (wr_ce_reduce_ack_gen and
                                 Bus2IP_WrCE(SPIDTR))
                                 and (not sr_4_Tx_Full_int);

     TRANSMIT_FIFO_I: entity axi_spi_v2_01_a_proc_common_v3_00_a.srl_fifo
        generic map
             (
              C_DATA_BITS => C_NUM_TRANSFER_BITS,
              C_DEPTH     => C_FIFO_DEPTH
             )
        port map
             (
              Clk         => Bus2IP_Clk,                                -- in
              Reset       => reset_TxFIFO_ptr_int,                      -- in
              FIFO_Write  => IP2Bus_WrAck_transmit_enable,              -- in
              Data_In     => Bus2IP_Data                                -- in
                             ((C_S_AXI_DATA_WIDTH-C_NUM_TRANSFER_BITS)
                              to (C_S_AXI_DATA_WIDTH-1)),

              FIFO_Read   => spiXfer_done_int,                          -- in
              Data_Out    => data_From_TxFIFO_int,                      -- out
              FIFO_Full   => sr_4_Tx_Full_int,                          -- out
              Data_Exists => data_Exists_TxFIFO_int,                    -- out
              Addr        => tx_FIFO_occ_Reversed_int                   -- out
             );

-------------------------------------------------------------------------------
-- I_FIFO_IF_MODULE : INSTANTIATE FIFO INTERFACE MODULE
-------------------------------------------------------------------------------
     FIFO_IF_MODULE_I: entity axi_spi_v2_01_a.spi_fifo_ifmodule
        generic map
             (
              C_NUM_TRANSFER_BITS   => C_NUM_TRANSFER_BITS
             )
        port map
             (
              Bus2IP_Clk            => Bus2IP_Clk,              -- in
              Reset                 => reset2ip_reset_int,      -- in

          --Slave attachment ports
              Bus2IP_RcFIFO_RdCE    => Bus2IP_RdCE(SPIDRR),     -- in
              Bus2IP_TxFIFO_WrCE    => Bus2IP_WrCE(SPIDTR),     -- in
              Receive_ip2bus_error  => receive_ip2bus_error,    -- out
              Transmit_ip2bus_error => transmit_ip2bus_error,   -- out

          --FIFO ports
              Data_From_TxFIFO      => data_From_TxFIFO_int,    -- in vec
              Tx_FIFO_Data_WithZero => transmit_Data_int,       -- out vec
              Rc_FIFO_Data_Out      => rc_FIFO_Data_Out_int,    -- in vec
              Rc_FIFO_Empty         => sr_7_Rx_Empty_int,       -- in
              Rc_FIFO_Full          => sr_6_Rx_Full_int,        -- in
              Rc_FIFO_Full_strobe   => rc_FIFO_Full_strobe_int, -- out
              Tx_FIFO_Empty         => sr_5_Tx_Empty_int,       -- in
              Tx_FIFO_Empty_strobe  => tx_FIFO_Empty_strobe_int,-- out
              Tx_FIFO_Full          => sr_4_Tx_Full_int,        -- in
              Tx_FIFO_Occpncy_MSB   => tx_FIFO_occ_Reversed_int -- in
                                       (C_OCCUPANCY_NUM_BITS-1),
              Tx_FIFO_less_half     => tx_FIFO_less_half_int,   -- out

          --SPI module ports
              Reg2SA_Data           => reg2SA_Data_receive_int, -- out vec
              DRR_Overrun           => drr_Overrun_int,         -- out
              SPIXfer_done          => spiXfer_done_int,        -- in
              DTR_Underrun_strobe   => dtr_Underrun_strobe_int, -- out
              DTR_underrun          => dtr_underrun_int,        -- in
              Wr_ce_reduce_ack_gen  => wr_ce_reduce_ack_gen,    -- in
              Rd_ce_reduce_ack_gen  => rd_ce_reduce_ack_gen     -- in

             );

-------------------------------------------------------------------------------
-- TX_OCCUPANCY_I : INSTANTIATE TRANSMIT OCCUPANCY REGISTER
-------------------------------------------------------------------------------

     TX_OCCUPANCY_I: entity axi_spi_v2_01_a.SPI_occupancy_reg
        generic map
             (
              C_OCCUPANCY_NUM_BITS => C_OCCUPANCY_NUM_BITS
             )
        port map
             (
          --Slave attachment ports
              Bus2IP_Reg_RdCE      => Bus2IP_RdCE(SPITFOR),        -- in

          --FIFO port
              IP2Reg_Data_Reversed => tx_FIFO_occ_Reversed_int,    -- in vec
              Reg2SA_Data          => reg2SA_Data_TxOccupancy_int  -- out vec
             );

-------------------------------------------------------------------------------
-- RX_OCCUPANCY_I : INSTANTIATE RECEIVE OCCUPANCY REGISTER
-------------------------------------------------------------------------------

     RX_OCCUPANCY_I: entity axi_spi_v2_01_a.SPI_occupancy_reg
        generic map
             (
              C_OCCUPANCY_NUM_BITS => C_OCCUPANCY_NUM_BITS--,
             )
        port map
             (
          --Slave attachment ports
              Bus2IP_Reg_RdCE      => Bus2IP_RdCE(SPIRFOR),        -- in

          --FIFO port
              IP2Reg_Data_Reversed => rc_FIFO_occ_Reversed_int,    -- in vec
              Reg2SA_Data          => reg2SA_Data_RcOccupancy_int  -- out vec
             );

  end generate MAP_SIGNALS_AND_REG_WITH_FIFOS;


-------------------------------------------------------------------------------
-- CONTROL_REG_I : INSTANTIATE CONTROL REGISTER
-------------------------------------------------------------------------------

 CONTROL_REG_I: entity axi_spi_v2_01_a.spi_cntrl_reg
          generic map
               (
                C_DBUS_WIDTH        => C_S_AXI_DATA_WIDTH,

                --Added bit for Mst_xfer_inhibit
                C_NUM_BITS_REG      => C_NUM_BITS_REG+4
               )
          port map
               (
                Bus2IP_Clk          => Bus2IP_Clk,                    -- in
                Reset               => reset2ip_reset_int,            -- in

            --Slave attachment ports
                Wr_ce_reduce_ack_gen        => wr_ce_reduce_ack_gen,  -- in
                Bus2IP_Control_Reg_WrCE     => Bus2IP_WrCE(SPICR),    -- in
                Bus2IP_Control_Reg_RdCE     => Bus2IP_RdCE(SPICR),    -- in
                Bus2IP_Control_Reg_Data     => Bus2IP_Data,           -- in vec

            --SPI module ports
                Reg2SA_Control_Reg_Data     => reg2SA_Data_cntrl_int, --out vec
                Control_Register_Data       => register_Data_cntrl_int,--out "
                control_bit_9_10             => control_bit_9_10_int    --out vec
                );

-------------------------------------------------------------------------------
-- STATUS_REG_I : INSTANTIATE STATUS REGISTER
-------------------------------------------------------------------------------

       STATUS_REG_I: entity axi_spi_v2_01_a.spi_status_slave_sel_reg
        generic map
             (
              C_NUM_BITS_REG      => C_NUM_BITS_REG,
              C_DBUS_WIDTH        => C_S_AXI_DATA_WIDTH,
              C_NUM_SS_BITS       => C_NUM_SS_BITS
             )
        port map
             (
              Bus2IP_Clk          => Bus2IP_Clk,                -- in
              Reset               => reset2ip_reset_int,        -- in

          --STATUS REGISTER SIGNALS
          --Slave attachment ports
              Bus2IP_Status_Reg_RdCE    => Bus2IP_RdCE(SPISR),  -- in
              Reg2SA_Status_Reg_Data    => reg2SA_Data_status_int,-- out vec

          --Reg/FIFO ports
              SR_2_SPISEL_slave         => spisel_d1_reg,

              SR_3_MODF                 => sr_3_MODF_int,       -- in
              SR_4_Tx_Full              => sr_4_Tx_Full_int,    -- in
              SR_5_Tx_Empty             => sr_5_Tx_Empty_int,   -- in
              SR_6_Rx_Full              => sr_6_Rx_Full_int,    -- in
              SR_7_Rx_Empty             => sr_7_Rx_Empty_int,   -- out

          --SPI module ports
              ModeFault_Strobe          => modf_strobe_int,     -- in

          --SLAVE SELECT SIGNALS
              Wr_ce_reduce_ack_gen      => wr_ce_reduce_ack_gen,-- in
              Rd_ce_reduce_ack_gen      => rd_ce_reduce_ack_gen,-- in
              Bus2IP_Slave_Sel_Reg_WrCE => Bus2IP_WrCE(SPISSR), -- in
              Bus2IP_Slave_Sel_Reg_RdCE => Bus2IP_RdCE(SPISSR), -- in
              Bus2IP_Data_slave_sel     => Bus2IP_Data,         -- in vec

              Reg2SA_Slave_Sel_Data     => reg2SA_Data_slvsel_int,-- out vec
              Slave_Sel_Register_Data   => register_Data_slvsel_int-- out vec
             );

-------------------------------------------------------------------------------


     SPI_MODULE_I: entity axi_spi_v2_01_a.spi_module
        generic map
             (
              C_SCK_RATIO           => C_SCK_RATIO,
              C_NUM_BITS_REG        => C_NUM_BITS_REG+4,
              C_NUM_SS_BITS         => C_NUM_SS_BITS,
              C_NUM_TRANSFER_BITS   => C_NUM_TRANSFER_BITS
             )
        port map
             (
              Bus2IP_Clk            => Bus2IP_Clk,              -- in
              Reset                 => reset2ip_reset_int,      -- in

              MODF_strobe           => modf_strobe_int,         -- out
              Slave_MODF_strobe     => slave_MODF_strobe_int,   -- out
              SR_3_MODF             => sr_3_MODF_int,           -- in
              SR_5_Tx_Empty         => sr_5_Tx_Empty_int,       -- in
              Control_Reg           => register_Data_cntrl_int, -- in vec
              Slave_Select_Reg      => register_Data_slvsel_int,-- in vec
              Transmit_Data         => transmit_Data_int,       -- in vec
              Receive_Data          => receive_Data_int,        -- out vec
              SPIXfer_done          => spiXfer_done_int,        -- out
              DTR_underrun          => dtr_underrun_int,        -- out

              SPISEL_pulse_op       => spisel_pulse_o_int,
              SPISEL_d1_reg         => spisel_d1_reg,

            --SPI Ports
              SCK_I                 => SCK_I,                   -- in
              SCK_O                 => SCK_O,                   -- out
              SCK_T                 => SCK_T,                   -- out

              MISO_I                => MISO_I_spi_module,       -- in
              MISO_O                => MISO_O,                  -- out
              MISO_T                => MISO_T,                  -- out

              MOSI_I                => MOSI_I,                  -- in
              MOSI_O                => MOSI_O,                  -- out
              MOSI_T                => MOSI_T,       -- out

              SPISEL                => SPISEL,                  -- in

              SS_I                  => SS_I,                    -- in
              SS_O                  => SS_O,                    -- out
              SS_T                  => SS_T,                    -- out

              control_bit_9_10       => control_bit_9_10_int,      -- in vec
              Mst_N_Slv_mode        => Mst_N_Slv_mode
             );
             
    SPI_MODE <= register_Data_cntrl_int(0);
    
    MISO_I_spi_module <= MISO_I when SPI_MODE = '0' else MOSI_I;
--------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- SOFT_RESET_I : INSTANTIATE SOFT RESET
-------------------------------------------------------------------------------
     SOFT_RESET_I: entity axi_spi_v2_01_a_proc_common_v3_00_a.soft_reset
        generic map
             (
              C_SIPIF_DWIDTH     => C_S_AXI_DATA_WIDTH,
              -- Width of triggered reset in Bus Clocks
              C_RESET_WIDTH      => 8
             )
        port map
             (
              -- Inputs From the PLBv46 Slave Single Bus
              Bus2IP_Clk         => Bus2IP_Clk,            -- in
              Bus2IP_Reset       => Bus2IP_Reset,          -- in

              Bus2IP_WrCE        => Bus2IP_WrCE(SWRESET),  -- in
              Bus2IP_Data        => Bus2IP_Data,           -- in
              Bus2IP_BE          => Bus2IP_BE,             -- in

              -- Final Device Reset Output
              Reset2IP_Reset     => reset2ip_reset_int,    -- out

              -- Status Reply Outputs to the Bus
              Reset2Bus_WrAck    => rst_ip2bus_wrack,      -- out
              Reset2Bus_Error    => rst_ip2bus_error,      -- out
              Reset2Bus_ToutSup  => open                   -- out
             );

-------------------------------------------------------------------------------
-- INTERRUPT_CONTROL_I : INSTANTIATE INTERRUPT CONTROLLER
-------------------------------------------------------------------------------

 bus2ip_intr_rdce <="0000000" & Bus2IP_RdCE(7) & Bus2IP_RdCE(8) & '0' 
                              & Bus2IP_RdCE(10) & "00000";
 bus2ip_intr_wrce <="0000000" & Bus2IP_WrCE(7) & Bus2IP_WrCE(8) & '0' 
                              & Bus2IP_WrCE(10) & "00000";
 ------------------------------------------------------------------------------
 intr_controller_rd_ce_or_reduce <= or_reduce(Bus2IP_RdCE(0 to 6)) or
                                    Bus2IP_RdCE(9)      or
                                    or_reduce(Bus2IP_RdCE(11 to 15));

 ------------------------------------------------------------------------------
 I_READ_ACK_INTR_HOLES: process(Bus2IP_Clk) is
 begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset_int = RESET_ACTIVE) then
          ip2Bus_RdAck_intr_reg_hole     <= '0';
          ip2Bus_RdAck_intr_reg_hole_d1  <= '0';
      else
          ip2Bus_RdAck_intr_reg_hole_d1 <= intr_controller_rd_ce_or_reduce;
          ip2Bus_RdAck_intr_reg_hole    <= intr_controller_rd_ce_or_reduce and
                                            (not ip2Bus_RdAck_intr_reg_hole_d1);
      end if;
    end if;
 end process I_READ_ACK_INTR_HOLES;
 ------------------------------------------------------------------------------
 intr_controller_wr_ce_or_reduce <= or_reduce(Bus2IP_WrCE(0 to 6)) or
                                    Bus2IP_WrCE(9)      or
                                    or_reduce(Bus2IP_WrCE(11 to 15));

 ------------------------------------------------------------------------------
 I_WRITE_ACK_INTR_HOLES: process(Bus2IP_Clk) is
 begin
    if (Bus2IP_Clk'event and Bus2IP_Clk = '1') then
      if (reset2ip_reset_int = RESET_ACTIVE) then
          ip2Bus_WrAck_intr_reg_hole     <= '0';
          ip2Bus_WrAck_intr_reg_hole_d1  <= '0';
      else
          ip2Bus_WrAck_intr_reg_hole_d1 <= intr_controller_wr_ce_or_reduce;
          ip2Bus_WrAck_intr_reg_hole    <= intr_controller_wr_ce_or_reduce and
                                            (not ip2Bus_WrAck_intr_reg_hole_d1);
      end if;
    end if;
 end process I_WRITE_ACK_INTR_HOLES;
 ------------------------------------------------------------------------------

     INTERRUPT_CONTROL_I: entity axi_spi_v2_01_a_interrupt_control_v2_01_a.interrupt_control
        generic map
             (
              C_NUM_CE               => 16,
              C_NUM_IPIF_IRPT_SRC    =>  1,  -- Set to 1 to avoid null array
              C_IP_INTR_MODE_ARRAY   => C_IP_INTR_MODE_ARRAY,

              -- Specifies device Priority Encoder function
              C_INCLUDE_DEV_PENCODER => false,

              -- Specifies device ISC hierarchy
              C_INCLUDE_DEV_ISC      => false,

              C_IPIF_DWIDTH          => C_S_AXI_DATA_WIDTH
             )
        port map
             (
              Bus2IP_Clk             =>  Bus2IP_Clk,
              Bus2IP_Reset           =>  reset2ip_reset_int,
              Bus2IP_Data            =>  bus2IP_Data_processed,
              Bus2IP_BE              =>  Bus2IP_BE,
              Interrupt_RdCE         =>  bus2ip_intr_rdce, --Bus2IP_RdCE(INTR_LO to INTR_HI),
              Interrupt_WrCE         =>  bus2ip_intr_wrce, --Bus2IP_WrCE(INTR_LO to INTR_HI),
              IPIF_Reg_Interrupts    =>  "00", -- Tie off the unused reg intrs
              IPIF_Lvl_Interrupts    =>  "0",  -- Tie off the dummy lvl intr
              IP2Bus_IntrEvent       =>  ip2Bus_IntrEvent_int,
              Intr2Bus_DevIntr       =>  IP2INTC_Irpt,
              Intr2Bus_DBus          =>  intr_ip2bus_data,
              Intr2Bus_WrAck         =>  intr_ip2bus_wrack,
              Intr2Bus_RdAck         =>  intr_ip2bus_rdack,
              Intr2Bus_Error         =>  intr_ip2bus_error,
              Intr2Bus_Retry         =>  open,
              Intr2Bus_ToutSup       =>  open
             );
--------------------------------------------------------------------------------
end imp;
--------------------------------------------------------------------------------
