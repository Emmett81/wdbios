# WD1002A-WX1 Super-BIOS

## Overview

This is a modified version of the Western Digital WD1002A-WX1 controller BIOS ROM that I added
to my custom bios rom. 

## Modifications

### Primary vs Secondary Controller

The ROM decides if it's the primary or secondary controller based on where the ROM is loaded from.
I changed the segment checks so it acts as the primary controller when loaded from segment **F000H**.

### Modified IRQ Selection Logic

**The IRQ selection logic has been reversed from the original WD ROM behavior.**

I wanted to use IRQ5 for something else and IRQ 2 is not in use by VGA in my system.
My card is however hardwired for IRQ5. I rewired it for IRQ2 but S1-7 jumper on my 
card has no effect on the configuration register. So reversed the logic.

#### Original Behavior:
- S1-7 jumper **CLOSED** → IRQ 2
- S1-7 jumper **OPEN** → IRQ 5

#### **Modified Behavior:**
- S1-7 jumper **CLOSED** → **IRQ 5**
- S1-7 jumper **OPEN** → **IRQ 2**

## Building the ROM

### Prerequisites

- NASM (Netwide Assembler)
- Perl (for checksum calculation)
- Make utility

### Build Process

```bash
make clean
make all
```

This will generate `wdbios.bin` - an 8KB ROM image ready for burning to an EPROM.