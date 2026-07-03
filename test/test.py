# Cocotb testbench for testing the MAC and JTAG functions of this ASIC design
#
# Julia Desmazes, 2026, human made code


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout

import random 
import asyncio
from array import array 

import mac_utils

import os
if "GATES" in os.environ:
	GATES = os.environ["GATES"].lower().strip()
else:
	GATES = ""

if "TEST_ITER" in os.environ:
	TEST_ITER = int(os.environ["TEST_ITER"].lower().strip())
else:
	TEST_ITER = 2


CLK_UNIT="ns"
CLK_PERIOD=20
TCK_UNIT=CLK_UNIT 
TCK_PERIOD=77
CLK_TIMEOUT_PERIOD=(CLK_PERIOD*1000)

SC_CLK_DELAY=2

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

# send only, used to test config frames where no response is expected
async def send_frame(dut, rx: mac_utils.eth_frame):
	await mac_utils.phy_stream_frame(dut, rx.raw())

async def read_app_frame(dut): 
	tx_frame = await mac_utils.read_tx_frame(dut)
	gotten = tx_frame.tobytes().hex()
	exp_len = 8+2*6+2+2+48+4
	assert len(tx_frame) == exp_len, f"unexpected app frame, got {exp_len}/{len(tx_frame)}"
	cocotb.log.info(f"tx {gotten}")


async def send_and_check_frames(dut, rx: mac_utils.eth_frame, device_mac = mac_utils.DEFAULT_DEVICE_MAC):
	tx_sent, tx = mac_utils.expected_response(rx, device_mac)
	if tx_sent: 
		read_tx_thread = cocotb.start_soon(mac_utils.read_tx_frame(dut))
	else:
		read_tx_thread = cocotb.start_soon(mac_utils.check_no_tx_frame(dut))
	await mac_utils.phy_stream_frame(dut,rx.raw())
	tx_frame = await read_tx_thread
	if tx_sent:
		tx_raw = tx.raw(is_rmii_tx = True)
		expected = tx_raw.hex()
		gotten = tx_frame.tobytes().hex()
		cocotb.log.info(f"tx {gotten}")
		if (expected != gotten): 
			cocotb.log.error(f"Error, missmatch between expected and gotten tx ethernet frame\nexp {expected}\ngot {gotten}")
			debug_string = 4*" "
			for (e, g) in zip(expected, gotten):
				debug_string += "^" if (e != g) else " "
			cocotb.log.error(debug_string)
			assert(0)

# Simple test 
@cocotb.test(skip=True if GATES == "yes" else False)
async def simple_tx_test(dut):
	random.seed(0)
	await rst(dut) 
	for _ in range(0,TEST_ITER):
		await read_app_frame(dut)

@cocotb.test(skip=True if GATES == "yes" else False)
async def update_eth_config(dut):
	random.seed(0)
	await rst(dut)
	device_mac = mac_utils.DEFAULT_DEVICE_MAC
	for _ in range(0,TEST_ITER):
		new_mac = random.randbytes(6)
		frame, config = mac_utils.simple_config(dst_mac = device_mac, new_mac = new_mac)
		await send_frame(dut, frame)
		dut_mac = int(dut.m_dut.mac_addr.value).to_bytes(6, byteorder='big')
		dut_vid = int(dut.m_dut.vid.value).to_bytes(2, byteorder='big')
		assert dut_mac == config.addr, f"missmatch mac config, config sent {config} got addr {dut_mac.hex()}"
		assert dut_vid == config.vid, f"missmatch vid config, config sent {config} got vid {dut_vid.hex()} raw {dut.m_dut.vid.value}"
		device_mac = new_mac
	await ClockCycles(dut.clk, 10)

