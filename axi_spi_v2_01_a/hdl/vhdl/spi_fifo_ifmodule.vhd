-------------------------------------------------------------------------------
--  SPI FIFO read/write Module -- entity/architecture pair
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
-- Filename:        spi_fifo_ifmodule.vhd
-- Version:         v1.02.a
-- Description:     Serial Peripheral Interface (SPI) Module for interfacing
--                  with a 32-bit axi Bus. FIFO Interface module
--
-------------------------------------------------------------------------------
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
--  C_NUM_TRANSFER_BITS         --  SPI Serial transfer width.
--                                  Can be 8, 16 or 32 bit wide
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--                  Definition of Ports
-------------------------------------------------------------------------------
-- SYSTEM
--  Bus2IP_Clk                  --      Bus to IP clock
--  Reset                       --      Reset Signal

-- SLAVE ATTACHMENT INTERFACE
--  Bus2IP_RcFIFO_RdCE          --      Bus2IP receive FIFO read CE
--  Bus2IP_TxFIFO_WrCE          --      Bus2IP transmit FIFO write CE
--  Rd_ce_reduce_ack_gen         --     commong logid to generate the write ACK
--  Wr_ce_reduce_ack_gen        --      commong logid to generate the write ACK
--  Reg2SA_Data                 --      Data to send on the bus
--  Transmit_ip2bus_error       --      Transmit FIFO error signal
--  Receive_ip2bus_error        --      Receive FIFO error signal

-- FIFO INTERFACE
--  Data_From_TxFIFO            --      Data from transmit FIFO
--  Tx_FIFO_Data_WithZero       --      Components to put zeros on input
--                                      to Shift Register when FIFO is empty
--  Rc_FIFO_Data_Out            --      Receive FIFO data output
--  Rc_FIFO_Empty               --      Receive FIFO empty
--  Rc_FIFO_Full                --      Receive FIFO full
--  Rc_FIFO_Full_strobe         --      1 cycle wide receive FIFO full strobe
--  Tx_FIFO_Empty               --      Transmit FIFO empty
--  Tx_FIFO_Empty_strobe        --      1 cycle wide transmit FIFO full strobe
--  Tx_FIFO_Full                --      Transmit FIFO full
--  Tx_FIFO_Occpncy_MSB         --      Transmit FIFO occupancy register
--                                      MSB bit
--  Tx_FIFO_less_half           --      Transmit FIFO less than half empty

-- SPI MODULE INTERFACE

--  DRR_Overrun                 --      DRR Overrun bit
--  SPIXfer_done                --      SPI transfer done flag
--  DTR_Underrun_strobe         --      DTR Underrun Strobe bit
--  DTR_underrun                --      DTR underrun generation signal
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- Entity Declaration
-------------------------------------------------------------------------------
entity spi_fifo_ifmodule is
    generic
    (
        C_NUM_TRANSFER_BITS   : integer
    );
    port
    (
        Bus2IP_Clk           : in  std_logic;
        Reset                : in  std_logic;

        -- Slave attachment ports
        Bus2IP_RcFIFO_RdCE   : in  std_logic;
        Bus2IP_TxFIFO_WrCE   : in  std_logic;

        Reg2SA_Data          : out std_logic_vector
	                                         (0 to (C_NUM_TRANSFER_BITS-1));
        Transmit_ip2bus_error: out std_logic;
        Receive_ip2bus_error : out std_logic;

	-- FIFO ports
        Data_From_TxFIFO     : in  std_logic_vector
	                                         (0 to (C_NUM_TRANSFER_BITS-1));
        Tx_FIFO_Data_WithZero: out std_logic_vector
	                                         (0 to (C_NUM_TRANSFER_BITS-1));
        Rc_FIFO_Data_Out     : in  std_logic_vector
	                                         (0 to (C_NUM_TRANSFER_BITS-1));
        Rc_FIFO_Empty        : in  std_logic;
        Rc_FIFO_Full         : in  std_logic;

        Rc_FIFO_Full_strobe  : out std_logic;
        Tx_FIFO_Empty        : in  std_logic;

	Tx_FIFO_Empty_strobe : out std_logic;
        Tx_FIFO_Full         : in  std_logic;

	Tx_FIFO_Occpncy_MSB  : in  std_logic;
        Tx_FIFO_less_half    : out std_logic;

	-- SPI module ports
        DRR_Overrun          : out std_logic;
        SPIXfer_done         : in  std_logic;
        DTR_Underrun_strobe  : out std_logic;
        DTR_underrun         : in  std_logic;
        Wr_ce_reduce_ack_gen : in  std_logic;
        Rd_ce_reduce_ack_gen : in std_logic
    );
end spi_fifo_ifmodule;

-------------------------------------------------------------------------------
-- Architecture
---------------
architecture imp of spi_fifo_ifmodule is
---------------------------------------------------
-- Signal Declarations
----------------------
signal drr_Overrun_i            :  std_logic;
signal rc_FIFO_Full_d1          :  std_logic;
signal dtr_Underrun_strobe_i    :  std_logic;
signal tx_FIFO_Empty_d1         :  std_logic;
signal tx_FIFO_Occpncy_MSB_d1   :  std_logic;
signal dtr_underrun_d1          :  std_logic;
---------------------------------------------

begin
-----
--  Combinatorial operations
-------------------------------------------------------------------------------
    DRR_Overrun         <= drr_Overrun_i;
    DTR_Underrun_strobe <= dtr_Underrun_strobe_i;

-------------------------------------------------------------------------------
--  I_DRR_OVERRUN_REG_PROCESS : DRR overrun strobe
-------------------------------
DRR_OVERRUN_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        drr_Overrun_i <= not(drr_Overrun_i or Reset) and
                                                 Rc_FIFO_Full and SPIXfer_done;
    end if;
end process DRR_OVERRUN_REG_PROCESS_P;

-------------------------------------------------------------------------------
--  SPI_RECEIVE_FIFO_RD_GENERATE : Read of SPI receive FIFO
----------------------------------
SPI_RECEIVE_FIFO_RD_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
     Reg2SA_Data(j) <= Rc_FIFO_Data_Out(j) and(rd_ce_reduce_ack_gen and
                                                           Bus2IP_RcFIFO_RdCE);
end generate SPI_RECEIVE_FIFO_RD_GENERATE;

-------------------------------------------------------------------------------
--  I_RX_ERROR_ACK_REG_PROCESS : Strobe error when receive FIFO is empty
--------------------------------
RX_ERROR_ACK_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
    	    Receive_ip2bus_error <= '0';
	else
	    Receive_ip2bus_error <= Rc_FIFO_Empty and Bus2IP_RcFIFO_RdCE;
	end if;
    end if;
end process RX_ERROR_ACK_REG_PROCESS_P;
-------------------------------------------------------------------------------
--  RX_FIFO_STROBE_REG_PROCESS_P : Strobe when receive FIFO is full
----------------------------------
RX_FIFO_STROBE_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            rc_FIFO_Full_d1 <= '0';
        else
            rc_FIFO_Full_d1 <= Rc_FIFO_Full;
        end if;
    end if;
end process RX_FIFO_STROBE_REG_PROCESS_P;
-----------------------------------------
Rc_FIFO_Full_strobe <= (not rc_FIFO_Full_d1) and Rc_FIFO_Full;

-------------------------------------------------------------------------------
--  TX_ERROR_ACK_REG_PROCESS_P : Strobe error when transmit FIFO is full
--------------------------------
TX_ERROR_ACK_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        Transmit_ip2bus_error <= Tx_FIFO_Full and Bus2IP_TxFIFO_WrCE;
    end if;
end process TX_ERROR_ACK_REG_PROCESS_P;
-------------------------------------------------------------------------------

--  PUT_ZEROS_IN_SR_GENERATE : Put zeros on input to SR when FIFO is empty.
--                             Requested by software designers
------------------------------
PUT_ZEROS_IN_SR_GENERATE: for j in 0 to C_NUM_TRANSFER_BITS-1 generate
begin
    Tx_FIFO_Data_WithZero(j) <= Data_From_TxFIFO(j) and (not Tx_FIFO_Empty);
end generate PUT_ZEROS_IN_SR_GENERATE;
-------------------------------------------------------------------------------

-- TX_FIFO_STROBE_REG_PROCESS_P : Strobe when transmit FIFO is empty
----------------------------------
TX_FIFO_STROBE_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            tx_FIFO_Empty_d1 <= '1';
        else
            tx_FIFO_Empty_d1 <= Tx_FIFO_Empty;
        end if;
    end if;
end process TX_FIFO_STROBE_REG_PROCESS_P;
-----------------------------------------
Tx_FIFO_Empty_strobe <= (not tx_FIFO_Empty_d1) and Tx_FIFO_Empty;

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

-------------------------------------------------------------------------------
--  TX_FIFO_HALFFULL_STROBE_REG_PROCESS_P : Strobe for when transmit FIFO is
--                                          less than half full
-------------------------------------------
TX_FIFO_HALFFULL_STROBE_REG_PROCESS_P:process(Bus2IP_Clk)
begin
    if (Bus2IP_Clk'event and Bus2IP_Clk='1') then
        if (Reset = RESET_ACTIVE) then
            tx_FIFO_Occpncy_MSB_d1 <= '0';
        else
            tx_FIFO_Occpncy_MSB_d1 <= Tx_FIFO_Occpncy_MSB;
        end if;
    end if;
end process TX_FIFO_HALFFULL_STROBE_REG_PROCESS_P;
--------------------------------------------------

Tx_FIFO_less_half <= tx_FIFO_Occpncy_MSB_d1 and (not Tx_FIFO_Occpncy_MSB);
--------------------------------------------------------------------------
end imp;
--------------------------------------------------------------------------------
