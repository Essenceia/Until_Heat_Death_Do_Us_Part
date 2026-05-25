# MAC testing utils library
#
# Julia Desmazes, 2026, human made code

import cocotb
from cocotb.triggers import ClockCycles
import random 
from array import array
from typing import NamedTuple, Optional

class dot1q(NamedTuple):
	tpid: bytes = b'\x81\x00'
	tci: bytes = bytes(2)
	def __init__(self, tci):
		self.tci = tci
	
class MAC_header(NamedTuple):
	dst : bytes = bytes(6)	
	src : bytes = bytes(6)
	vlan_tag: Optional[dot1q]
	ethtype: bytes = bytes(2)

class eth_frame(NamedTuple):
	sfd: bytes = b'\xab'
	header: MAC_header
	body: bytes
	fcs: bytes = b'\xff\xff\xff\xff'
	
	def random_body(self):
		l = random.randint(48,2000)
		for i in range(0,l):
			self.body.append(random.randint(0,255))
		self.header.ethtype = struct.pack('!p', l)
 
	def __init__(self, dst, src, vlan_tag = None):
		self.header.dst = dst	
		self.header.src = src
		if vlan_tag is not None: 
			self.header.vlan_tag = dot1q(vlan_tag)
	
	def calc_fcs(self):
		pass # TODO

	def raw_frame(self):
		self.calc_fcs()
		return struct.pack('!p', self)
