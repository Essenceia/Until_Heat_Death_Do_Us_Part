# Cocotb testbench for testing the MAC and JTAG functions of this ASIC design
#
# Julia Desmazes, 2026, human made code


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, ClockCycles, with_timeout

import random 
import asyncio
from array import array 

import coldbrew_mac_utils

import os

if "TEST_ITER" in os.environ:
	TEST_ITER = int(os.environ["TEST_ITER"].lower().strip())
else:
	TEST_ITER = 10

# send only, used to test config frames where no response is expected
async def send_frame(dut, rx: coldbrew_mac_utils.eth_frame, phy_idx: str):
	await coldbrew_mac_utils.phy_stream_frame(dut, rx.raw(), phy_idx)

async def read_app_frame(dut, phy_idx: str) -> int: 
	tx_frame = await coldbrew_mac_utils.read_tx_frame(dut, phy_idx)
	gotten = tx_frame.tobytes()
	exp_len = 8+2*6+2+2+48+4
	assert len(tx_frame) == exp_len, f"unexpected app frame, got {exp_len}/{len(tx_frame)}"
	cnt = int.from_bytes(gotten[24:32], byteorder='little',signed=False)
	cocotb.log.info(f"cnt 0x{hex(cnt)} tx {gotten.hex()}")
	return cnt

# Simple test 
async def simple_tx_test_sequence(dut, phy_idx: str = ""):
	cnt = 0
	for _ in range(0,TEST_ITER):
		new_cnt = await read_app_frame(dut, phy_idx)
		assert new_cnt > cnt, f"Counter expected to be strickly incrementing, old value {cnt} new value {new_cnt}"
		cnt = new_cnt

async def update_eth_config_sequence(dut, module, phy_idx: str = ""):
	# get default device mac, set by module parameter
	device_mac = int(module.DEFAULT_MAC.value).to_bytes(6, byteorder='big')
	for _ in range(0,TEST_ITER):
		new_mac = random.randbytes(6)
		frame, config = coldbrew_mac_utils.simple_config(dst_mac = device_mac, new_mac = new_mac)
		await send_frame(dut, frame, phy_idx)
		dut_mac = int(module.mac_addr.value).to_bytes(6, byteorder='big')
		dut_vid = int(module.vid.value).to_bytes(2, byteorder='big')
		assert dut_mac == config.addr, f"missmatch mac config, config sent {config} got addr {dut_mac.hex()}"
		assert dut_vid == config.vid, f"missmatch vid config, config sent {config} got vid {dut_vid.hex()} raw {module.vid.value}"
		device_mac = new_mac
	await ClockCycles(dut.clk, 10)

