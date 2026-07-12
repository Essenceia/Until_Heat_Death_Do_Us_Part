# Cocotb testbench for testing the MAC and JTAG functions of this ASIC design
#
# Julia Desmazes, 2026, human made code


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout

import random 
import asyncio
from array import array 

import coldbrew_test

import time
import os

if "GATES" in os.environ:
	GATES = os.environ["GATES"].lower().strip()
else:
	GATES = ""

CLK_UNIT="ns"
CLK_PERIOD=20

def set_random_seed():
	if "SEED" in os.environ:
		seed = int(os.environ["SEED"].lower().strip())
	else:
		seed = time.time_ns()
	cocotb.log.info(f"random seed {seed}")
	random.seed(seed)

def start_clk(dut):
	clock = Clock(dut.clk, CLK_PERIOD, CLK_UNIT)
	clk_task = cocotb.start_soon(clock.start()) #runs the clock "in the background" 
	return clk_task

# Reset sequence
async def rst(dut, ena=1 ):
	dut.rst_n.value = 0
	dut.tx_phase.value = 0
	clk_task = start_clk(dut)
	await ClockCycles(dut.clk, 2)
	# set default phy rx
	dut.phy_rx_v.value = "0"
	dut.phy_rx.value = "X"*2
	dut.phy_rx_err.value = "X"
	dut.ena.value = 0
	await ClockCycles(dut.clk, 30)
	dut.rst_n.value = 1
	dut.ena.value = ena
	await ClockCycles(dut.clk, 20)

# Simple test 
@cocotb.test(skip=True if GATES == "yes" else False)
async def simple_tx_test(dut):
	set_random_seed()
	await rst(dut) 
	await coldbrew_test.simple_tx_test_sequence(dut)	

@cocotb.test(skip=True if GATES == "yes" else False)
async def update_eth_config(dut):
	set_random_seed()
	await rst(dut)
	await coldbrew_test.update_eth_config_sequence(dut)
