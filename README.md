# Counting until the heat death of the universe

ASIC with a large enogth counter to theoretically counts until the heat death of the the universe. 
Counter value is incremented ever 20ns and every second it will broadcasts an ethernet frame over 100Mbps ethernet
with the current counters value, not that anyone is going to be listening for long anyways. 

Assuming the universe dies in approximatively $10^{100}$ years. If you are patient enogth to wait until then there is 
a hidden easter egg when we eventually overflow.  

![floorplan](/docs/floorplan_lazy.png) 

Quickstart can be found [in the documentation](/docs/info.md).

# Doomsday counter 

No need to be scared, the sun will have engulfed our feable planet long before the counter overflows. 

Assuming the big freeze arrives in $10^{100}$ years and we are operating at 50Mhz, we have: 
- $`50*10^{6}`$ ticks per second
- $`50*10^{6}*60*60*24`$ ticks per day
- $`50*10^{6}*60*60*24*365.25`$ ticks per year
- $`50*10^{6}*60*60*24*365.25*10^{100}`$ ticks until the big freeze

So we need a $`\log_2(50*10^{6}*60*60*24*365.25*10^{100}) = 382.679718 \approx 383`$ sized counter ... at the very least.

# 100Mbps Ethernet 

This project is re-using the [Teapot Ethernet accelerator wrapper](https://github.com/Essenceia/Teapot) for communicating
over 100Mbps Ethernet using a CAT-3/5 cable in full-duplex mode. Here is to hopeing someone still remeber how to 
talk Ethernet by then.  

## Ethernet packets

This wrapper workes with layer 2 ethernet packets, opperating at the level of the ethernet frame. It support two 
types of packets: 
- `application packets, ethtype = 0x88B5` sent by the accelerator
- `configuration packets, ethtype = 0x88B6` used to set the ASICs MAC address, Vlan IDentifier, and the TX phase selection

All packets whos destination MAC do not match the ASIC's current MAC address will be filtered out.
Unless otherwise specified the ASIC's MAC address is `00:90:CF:00:BE:EF` (read as Nortel:BEEF).
 
### Application packets

The end of the universe counter does not listen to any incomming packets (we are all going to be dead soon anyways) 
and broadcasts the current counter value every second. 

**Response**
```
[ dst mac (6 Bytes) FF:FF:FF:FF:FF:FF ][ src mac (6 Bytes) ][ ethtype = 0x88B5 (2 Bytes) ][ magic number (2 Bytes) 0xCAFE ][ counter (48 Bytes) ][ FCS (4 Bytes) ] 
0
```
Counter values and magic numbers are sent in little endian with a granule size of 1 byte (standard).

### Configuration packets

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

#### Configuration parameters 

##### MAC address

ASIC's current MAC address, all packets not addressed (`dst mac`) to this address will be filtered out, 
and all responses will use this as the source address. 

Default MAC: `00:90:CF:00:BE:EF` (read as Nortel:BEEF)

##### VLAN ID
In the event a packet is vlan tagged, packets not matching the VLAN ID will be filtered out. 
If a packet isn't vlan tagged, it is assumed to belong to our current VLAN. 

Default VLAN ID: `0xDAD`

## Configuration pins

##### TX data to reference clock phase offset

To comphensate for the output data to reference clock offset induced by the delay on the path from the clock 
input pin, to the tiny tapeout design's data out flip-flop and back to the output pin, the reference 
clock for the data out flip flop is selectable, allowing us to use a 180 degree dephased reference clock. 

This dephasing configuration is captured during reset depending on the state of the `tx_phase` pin. 

Values: 
- `0` no phase shift
- `1` 180 degree phase shift

## Assumptions 

Desgin will be using the [official microchip LAN8720A daughter board](https://www.microchip.com/en-us/development-tool/AC320004-3#Overview) for testing.

This ASIC will be supporting 100Mbps ethernet using the following assumptions: 
- PHY will be implemented used the microchip LAN8720A(I) chips
- External network is full duplex 
		- dropping CRS support in asic 
- No 10Mbps support
	- dissabling auto-negociation
- LAN8720A clk is provided by an external clocks that is shared with the ASIC.
- Stream from LAN8720A is assumed gapeless, any packet gaps will trigger the ongoing packet to be tagged as containing an error

## MAC behavior 

This MAC supports: 
- jumbo frames upto 9000 bytes 
- VLAN tagging (802.21Q) 

The MAC will filter out all unicast packets not matching the configured
destination MAC address. This implies that all broadcast and multicast 
packets will be forwarded. 

# Software support

To help you sniff your local network traffic and parse the ethernet frame I am providing 
the `packet_receiver` program under the tools folder in case we have all forgotten how to code by then. 
In case compilers are still a thing you can build it with: 
```
cd tools
make
```

To run specify the network interface you want to sniff as the first argument, also yes, you need sudo mode.

Eg:
```
sudo ./packet_receiver wlp3s0
```

Now technically it is parsing the counter value as a `uint64_t` so technically this will only work correctly 
for the next 11680 years. Now I know this is converning and you must be shoked at such sloppy engineering 
practice of knowingly releasing buggy software, I hear you. But let us first let humanity survive the [Epochalypse](https://en.wikipedia.org/wiki/Year_2038_problem)
before we start fighting over this one. 

Just open an issue when you encounter the bug, I will fix it if I'm available. 

## Credits

Thanks to `thegreatpotatogod` on reddit for inspiring me with such a terrible ides, the Tiny Tapeout project, its contributors, and all the community working on open source silicon tools for making this possible.
