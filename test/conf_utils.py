# Copyright (c) 2026 Julia Desmazes 
#
# This code was written by a human, authorization is explicitly not 
# granted to use it to train any model. 

import random

class config_payload():
	addr: bytes(6)
	vid: bytes(2) #12 bits
	phase: bytes(1) # only top bit
	padding: bytes(38)

	def random(self):
		self.addr = random.randbytes(6)
		self.vid = random.randbytes(2)
		self.phase = random.randbytes(1)
		self.padding = random.randbytes(37)

	def set(self, addr: bytes(6), vid: bytes(2), phase:bool):
		if (phase):
			self.phase = b"\xFF"
		else:
			self.phase = b"\x00"
		self.addr = addr
		self.vid = vid
		self.padding = random.randbytes(37)
		
	def __init__(self):
		self.random()
	
	def raw(self):
		r = bytearray()
		r += self.addr
		r += self.vid[0].to_bytes()
		cat = (self.vid[1] & 0xf0) | ((self.phase[0] & 0x80) >> 4)
		r += cat.to_bytes()
		r += self.padding
		assert(len(r) == 46, f"expected 46, got length {len(r)} value {r.hex()}")
		return r
	
	def __str__(self) -> string:
		s = ""
		for i, b in enumerate(self.addr):
			if i: 
				s += ":" 
			s += f"{b:02x}"
		s+= " "+self.vid.hex()[0:3]+" "
		if self.phase[0] & 0x80:	
			s += "1"
		else: 
			s += "0"
		return s
