# MAC testing utils library
#
# Julia Desmazes, 2026, human made code
import struct
import dataclasses
from dataclasses import dataclass

import cocotb
from cocotb.triggers import ClockCycles
import random 
from array import array
from typing import NamedTuple, Optional

class dot1q(NamedTuple):
	tpid: bytes = b'\x81\x00'
	tci: bytes = bytes(2)
	
class MAC_header(NamedTuple):
	dst : bytes = bytes(6)	
	src : bytes = bytes(6)
	vlan_tag: Optional[dot1q] = None
	ethtype: bytes = bytes(2)

	def raw(self):
		r = bytearray()
		r+= self.dst
		r+= self.src
		if self.vlan_tag is not None:
			r += self.vlan_tag.tpid
			r += self.vlan_tag.tci
		r+= self.ethtype
		return r

@dataclass
class eth_frame:
	sfd: bytes = b'\xab'
	header: MAC_header = MAC_header()
	body: bytes = bytes(48)
	fcs: bytes = b'\xff\xff\xff\xff'
	
	def random_body(self):
		l = random.randint(48,60)
		body = bytearray(0)
		for i in range(0,l):
			body.append(0)
			#body.append(random.randint(0,255))
		self.body = body
		#self.header = self.header._replace(ethtype = struct.pack('!H', l))
		self.header = self.header._replace(ethtype = b'\xFF\xFF')
 
	def __init__(self, dst, src, vlan_tag = None):
		if self.header.vlan_tag is not None: 
			self.header = MAC_header(dst,src,vlan_tag = dot1q(tci=vlan_tag))
		else:
			self.header = MAC_header(dst, src) 
	
	def calc_fcs(self):
		pass # TODO

	def raw(self):
		self.calc_fcs()
		r = bytearray()
		r += self.sfd
		r += self.header.raw()
		r += self.body
		r += self.fcs
		return r

async def phy_stream_frame(dut, raw):
	cocotb.log.info(f"raw frame {raw}")
	preamble = random.randint(1,10)
	dut.phy_rx_err.value = 0
	for _ in range(1, preamble):
		dut.phy_rx_v.value = 1
		dut.phy_rx.value = 0
		await ClockCycles(dut.clk,1)
	for x in raw:
		cocotb.log.info(f"x {hex(x)}") 
		for _ in range(0,4):
			dut.phy_rx_v.value = 1
			dut.phy_rx.value = (x & 0xc0) >> 6
			await ClockCycles(dut.clk,1)
			cocotb.log.info(f"{dut.phy_rx.value}")
			x = x << 2
	# IPG
	ipg = random.randint(1,10)
	for _ in range(0, ipg):
		dut.phy_rx_v.value = 0
		dut.phy_rx_err.value = "X"
		dut.phy_rx.value = "X"*2
		await ClockCycles(dut.clk,1)
	
async def send_simple_frame(dut):
	frame = eth_frame(b"\xFF\xFF\x00\xFF\x00\xFF",b"\x00\x11\x22\x33\x44\x00")
	frame.random_body()
	await phy_stream_frame(dut,frame.raw())
