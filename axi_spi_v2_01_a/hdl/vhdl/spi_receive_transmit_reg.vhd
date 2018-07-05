-------------------------------------------------------------------------------
--  SPI Receive Register Module - entity/architecture pair
-------------------------------------------------------------------------------
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
-- Filename:        spi_receive_reg.vhd
-- Version:         v1.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit AXI4 Bus.
--
-------------------------------------------------------------------------------
-- Structure:   This section shows the hierarchical structure of axi_spi.
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

library axi_spi_v2_01_a_proc_common_v3_00_a;
use axi_spi_v2_01_a_proc_common_v3_00_a.proc_common_pkg.RESET_ACTIVE;

-------------------------------------------------------------------------------
--                     Definition of Generics
-------------------------------------------------------------------------------

--  C_NUM_TRANSFER_BITS         --      SPI Serial transfer width.
--                                      Can be 8, 16 or 32 bit wide
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------
-- SYSTEM
--  Bus2IP_Clk                  --      Bus to IP clock
--  Reset                       --      Reset Signal

-- SLAVE ATTACHMENT INTERFACE

--  Bus2IP_Reg_RdCE             --      Read CE for receive register
--  IP2Bus_RdAck_sa             --      IP2Bus read acknowledgement
--  Reg2SA_Data                 --      Data to be send on the bus
--  Receive_ip2bus_error        --      Receive register error signal

-- SPI MODULE INTERFACE

--  DRR_Overrun                 --      DRR Overrun bit
--  SR_7_Rx_Empty               --      Receive register empty signal
--  IP2Reg_Data                 --      Data received from receive register
--  SPIXfer_done                --      SPI transfer done flag
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_receive_transmit_reg is
    generic
    (
        C_NUM_TRANSFER_BITS  : integer;      -- Number of bits to be transferred
        C_DBUS_WIDTH         : integer       -- 32 bits
    );
    port
    (
     Bus2IP_Clk              : in  std_logic;
     Reset                   : in  std_logic;
     ------------------------------------
     -- RECEIVER RELATED SIGNALS
     --=========================
     -- Slave attachment ports
     Bus2IP_Receive_Reg_RdCE : in  std_logic;
     Receive_ip2bus_error    : out std_logic;
     Reg2SA_Data             : out std_logic_vector
                                                 (0 to (C_NUM_TRANSFER_BITS-1));
     -- SPI module ports
     SPIXfer_done            : in  std_logic;
     IP2Reg_Data             : in  std_logic_vector
                                                 (0 to (C_NUM_TRANSFER_BITS-1));
     DRR_Overrun             : out std_logic;
     SR_7_Rx_Empty           : out std_logic;
     ------------------------------------
     -- TRANSMITTER RELATED SIGNALS
     --============================
     -- Slave attachment ports
     Bus2IP_Data_sa           : in  std_logic_vector(0 to (C_DBUS_WIDTH-1));
     Bus2IP_Transmit_Reg_WrCE : in  std_logic;
     Wr_ce_reduce_ack_gen     : in std_logic;
     Rd_ce_reduce_ack_gen     : in std_logic;

     Transmit_ip2bus_error    : out std_logic;
     
     -- SPI module ports
     DTR_underrun             : in  std_logic;
     SR_5_Tx_Empty            : out std_logic;
     DTR_Underrun_strobe      : out std_logic;
     Register_Data            : out std_logic_vector
                                               (0 to (C_NUM_TRANSFER_BITS-1))
    );
end spi_receive_transmit_reg;

-------------------------------------------------------------------------------
-- Architecture
---------------
architecture imp of spi_receive_transmit_reg is
---------------------------------------------------
-- Signal Declarations
----------------------
signal register_Data_r         : std_logic_vector(0 to (C_NUM_TRANSFER_BITS-1));
signal sr_7_Rx_Empty_i         : std_logic;
signal drr_Overrun_strobe      : std_logic;
--------------------------------------------
signal sr_5_Tx_Empty_i         : std_logic;
signal tx_Reg_Reset            : std_logic;
signal dtr_Underrun_strobe_i   : std_logic;
signal dtr_underrun_d1         : std_logic;
--------------------------------------------
begin
-----
-- RECEIVER LOGIC
--=================
--  Combinatorial operations
----------------------------
SR_7_Rx_Empty   <= sr_7_Rx_Empty_i;
DRR_Overrun     <= drr_Overrun_strobe;

-------------------------------------------------------------------------------
--  RECEIVE_REG_GENERATE : Receive Register Read Operation from IP2Reg_Data
--                         register
--------------------------
RECEIVE_REG_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
-----
    RECEIVE_REG_PROCESS_P:process(Bus2IP_Clk)
    begin
        if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
            if (Reset = RESET_ACTIVE) then
                register_Data_r(j) <= '0';
            elsif ((sr_7_Rx_Empty_i and SPIXfer_done) = '1') then
                register_Data_r(j) <= IP2Reg_Data(j);
            end if;
        end if;
    end process RECEIVE_REG_PROCESS_P;
-----
end generate RECEIVE_REG_GENERATE;

-------------------------------------------------------------------------------
--  RECEIVE_REG_RD_GENERATE : Receive Register Read Operation
-----------------------------
RECEIVE_REG_RD_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
     Reg2SA_Data(j) <= register_Data_r(j) and Bus2IP_Receive_Reg_RdCE;
end generate RECEIVE_REG_RD_GENERATE;

-------------------------------------------------------------------------------
--  RX_ERROR_ACK_REG_PROCESS_P : Strobe error when receive register is empty
--------------------------------
RX_ERROR_ACK_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        Receive_ip2bus_error <= sr_7_Rx_Empty_i and Bus2IP_Receive_Reg_RdCE;
    end if;
end process RX_ERROR_ACK_REG_PROCESS_P;

-------------------------------------------------------------------------------
--  SR_7_RX_EMPTY_REG_PROCESS_P : SR_7_Rx_Empty register
-------------------------------
SR_7_RX_EMPTY_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            sr_7_Rx_Empty_i <= '1';
        elsif (SPIXfer_done = '1') then
            sr_7_Rx_Empty_i <= '0';
        elsif ((rd_ce_reduce_ack_gen and Bus2IP_Receive_Reg_RdCE) = '1') then
            sr_7_Rx_Empty_i <= '1';
        end if;
    end if;
end process SR_7_RX_EMPTY_REG_PROCESS_P;

-------------------------------------------------------------------------------
--  OVERRUN_REG_PROCESS_P : Strobe to interrupt for receive data overrun
---------------------------
OVERRUN_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        drr_Overrun_strobe <= not(drr_Overrun_strobe or Reset) and
                                  SPIXfer_done and (not sr_7_Rx_Empty_i);
    end if;
end process OVERRUN_REG_PROCESS_P;
--******************************************************************************

-- TRANSMITTER LOGIC
--==================
--  Combinatorial operations
----------------------------
SR_5_Tx_Empty       <= sr_5_Tx_Empty_i;
DTR_Underrun_strobe <= dtr_Underrun_strobe_i;

tx_Reg_Reset <= SPIXfer_done or Reset;
--------------------------------------

-------------------------------------------------------------------------------
--  TRANSMIT_REG_GENERATE : Transmit Register Write
---------------------------
TRANSMIT_REG_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
-----
    TRANSMIT_REG_PROCESS_P:process(Bus2IP_Clk)
    begin
        if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
            if (tx_Reg_Reset = RESET_ACTIVE) then
                Register_Data(j) <= '0';
            elsif ((wr_ce_reduce_ack_gen and Bus2IP_Transmit_Reg_WrCE) = '1')then
                Register_Data(j) <=
                            Bus2IP_Data_sa(C_DBUS_WIDTH-C_NUM_TRANSFER_BITS+j);
            end if;
        end if;
    end process TRANSMIT_REG_PROCESS_P;
-----
end generate TRANSMIT_REG_GENERATE;
-----------------------------------

--  TX_ERROR_ACK_REG_PROCESS_P : Strobe error when transmit register is full
--------------------------------
TX_ERROR_ACK_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        Transmit_ip2bus_error <= not(sr_5_Tx_Empty_i) and 
                                                      Bus2IP_Transmit_Reg_WrCE;
    end if;
end process TX_ERROR_ACK_REG_PROCESS_P;

-------------------------------------------------------------------------------
--  SR_5_TX_EMPTY_REG_PROCESS_P : Tx Empty generate
-------------------------------
SR_5_TX_EMPTY_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            sr_5_Tx_Empty_i <= '1';
        elsif ((wr_ce_reduce_ack_gen and Bus2IP_Transmit_Reg_WrCE) = '1') then
            sr_5_Tx_Empty_i <= '0';
        elsif (SPIXfer_done = '1') then
            sr_5_Tx_Empty_i <= '1';
        end if;
    end if;
end process SR_5_TX_EMPTY_REG_PROCESS_P;

-------------------------------------------------------------------------------
--  DTR_UNDERRUN_REG_PROCESS_P : Strobe to interrupt for transmit data underrun
--                           which happens only in slave mode
-----------------------------
DTR_UNDERRUN_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            dtr_underrun_d1 <= '0';
        else
            dtr_underrun_d1 <= DTR_underrun;
        end if;
    end if;
end process DTR_UNDERRUN_REG_PROCESS_P;
---------------------------------------

dtr_Underrun_strobe_i <= DTR_underrun and (not dtr_underrun_d1);

--******************************************************************************

end imp;
--------------------------------------------------------------------------------
