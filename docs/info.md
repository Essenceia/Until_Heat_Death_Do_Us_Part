<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

ASIC with a large enogth counter to theoretically counts until the heat death of the the universe. 
Counter value is incremented ever 20ns and every second it will broadcasts an ethernet frame over 100Mbps ethernet
with the current counters value, not that anyone is going to be listening for long anyways. 

Assuming the universe dies in approximatively $10^{100}$ years. If you are patient enogth to wait until then there is 
a hidden easter egg when we eventually overflow.  

## How it works

This project is re-using the [Teapot Ethernet accelerator wrapper](https://github.com/Essenceia/Teapot) for communicating
over 100Mbps Ethernet using a CAT-3/5 cable in full-duplex mode. Here is to hopeing someone still remeber how to 
talk Ethernet by then.  

### Ethernet packets

This wrapper workes with layer 2 ethernet packets, opperating at the level of the ethernet frame. It support two 
types of packets: 
- `application packets, ethtype = 0x88B5` sent by the accelerator
- `configuration packets, ethtype = 0x88B6` used to set the ASICs MAC address, Vlan IDentifier, and the TX phase selection

All packets whos destination MAC do not match the ASIC's current MAC address will be filtered out.
Unless otherwise specified the ASIC's MAC address is `00:90:CF:00:BE:EF` (read as Nortel:BEEF).
 
#### Application packets

The end of the universe counter does not listen to any incomming packets (we are all going to be dead soon anyways) 
and broadcasts the current counter value every second. 

**Response**
```
[ dst mac (6 Bytes) FF:FF:FF:FF:FF:FF ][ src mac (6 Bytes) ][ ethtype = 0x88B5 (2 Bytes) ][ magic number = 0xCAFE (2 Bytes) ][ counter (48 Bytes) ][ FCS (4 Bytes) ] 
0
```
Counter values are sent in little endian with a granule size of 1 byte (standard).

#### Configuration packets

Configuration packets are used to set the ASIC's current: 
- MAC address
- Vlan ID
- TX data to clock phase offset

These packets are not forwarded to the accelerator, do not provide any acknoledgement and due to our area limitation 
are not store and forwarded. Any corrupted packets will result in a corrupted configuration. 

**Packet**:
```
[ dst mac (6 Bytes) ][ src mac (6 Bytes) ][ ethtype = 0x88B6 (2 Bytes) ][ New MAC (6 Bytes) ][ padding (3 bits)][ VID (12 bits)][ padding (38 Bytes) ][ FCS (4 Bytes) ]
0
```

Unless otherwise configured application packets use ethertype `0x88B6`, the second IEEE 802.3 specified "Local Experimental Ethertype", 
whos existence linux networking libraries are unaware of. So trust me: it's real. 

##### Configuration parameters 

###### MAC address

ASIC's current MAC address, all packets not addressed (`dst mac`) to this address will be filtered out, 
and all responses will use this as the source address. 

Default MAC: `00:90:CF:00:BE:EF` (read as Nortel:BEEF)

#### Configuration pins: TX data to reference clock phase offset

To comphensate for the output data to reference clock offset induced by the delay on the path from the clock 
input pin, to the tiny tapeout design's data out flip-flop and back to the output pin, the reference 
clock for the data out flip flop is selectable, allowing us to use a 180 degree dephased reference clock. 

This dephasing configuration is captured during reset depending on the state of the `tx_phase` pin. 

Values: 
- `0` no phase shift
- `1` 180 degree phase shift

## How to test

Connect the ethernet 100Mbps capable connector to the asic, if the connector doesn't 
expose a `rx_err` signal clamp it to gnd. 
Cable the ethernet connector to your local network, it doesn't have to be directly 
to your computer so long your are in the same local network (layer2 packets can be routed
within it). 

Build the packet sender/receiver app in `tools`: 
```
cd tools
make
```

To run pass the name of your ethernet interface currently connected to the same 
LAN as the ASIC. Eg: I am connected though my wifi interface: 
```
sudo ./packet_receiver wlp3s0
```
You can also observe the packets being sent back by sniffing your live traffic
via tcpdump: 
```
sudo tcpdump -xx -e -v 'ether proto 0x88b5'
```

The ASIC will autonomously send an application packet (ethtype:`0x88b5`) every 1s. 

## External hardware

Ethernet 100BASE-T Pmod connector, featuring: 
- LAN8720A PHY 
- 50MHz oscillator

