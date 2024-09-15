
# GBATang - GBA for Sipeed Tang FPGA boards

<img src='doc/gbatang0.1.jpg' width=300 />

This is a working but early-stage Game Boy Advance FPGA core for Sipeed [Tang Mega 138K](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k.html), [Mega 138K Pro](https://wiki.sipeed.com/hardware/en/tang/tang-mega-138k/mega-138k-pro.html) and the upcoming portable Sipeed Tang 60K board/handheld. 

The core outputs 720p HDMI video, accepts DS2 controller input, and supports all ROM sizes (up to 32MB). An open source BIOS is used so it can be used out of the box. ROMs are loaded from the SD card through a convenient menu system.  Some games do not work yet. The following are some that are verified to work,

* Super Mario Advance and 2, 3, 4 
* F-ZERO Maximum Velocity
* Donkey Kong Country
* Bomberman Tournament
* Metroid Fusion, Metroid - Zero Mission
* and many more

Missing things that I expect to implement include cartridge backup, SNES controller input, and game compatibility fixes.

Follow [me](https://x.com/nand2mario) on X to get updates. Also check out other cores in the series: [SNESTang](https://github.com/nand2mario/snestang) and [NESTang](https://github.com/nand2mario/nestang).

## Instructions

You need the Tang Mega 138K or Tang Mega 138K Pro board. Or you can wait for the Tang retro handheld. You also need a [Tang DS2 Pmod](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html), a [Tang SDRAM Pmod](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD.html), a [DS2 controller](https://en.wikipedia.org/wiki/DualShock), and finally a MicroSD card. Then assemble the parts as shown in the picture above.

Then follow these steps to install the core (for detailed instructions, for now refer to [SNESTang installation](https://github.com/nand2mario/snestang/blob/main/doc/installation.md)),

1. Download and install [Gowin IDE 1.9.10.02](https://cdn.gowinsemi.com.cn/Gowin_V1.9.10.02_x64_win.zip).

2. Download a [GBATang release](https://github.com/nand2mario/gbatang/releases).

3. Use Gowin programmer to program `firmware.bin` to on-board flash, at starting address **0x500000**.

4. Again use Gowin programmer. Program `gbatang_m138k.fs` or `gbatang_m138kpro.fs` to on-board flash at starting address 0x000000.

5. Put GBA roms and GBA BIOS on the MicroSD card. The 16KB GBA BIOS ROM should be named `gba_bios.bin` and placed at the root dir. Then insert the card into the on-board MicroSD slot and power up the board.

## About this project

The project started as a port of the MiSTer GBA core to Tang FPGAs in June 2024. However, it quickly turned into a half-rewrite. By September 2024 it finally reached a usable state and about half of the code is different. Here are the main differences.

* The overall design is a more traditional "FPGA replica" approach, as opposed to the "cycle counting" approach in the MiSTer core. Most modules work at 16Mhz, the GBA main frequency. The MiSTer main frequency is 100Mhz. 
* The CPU is [replaced](https://github.com/risclite/ARM9-compatible-soft-CPU-core), with missing features like 16-bit instructions added. The processor uses a similar pipelined design as the original GBA CPU.
* The memory system is also completely rewritten, as required by the overall design change.
* Timing accuracy could use a lot of improvements. However, as a more "modern" console, GBA mostly uses interrupts and timers to keep time. So cycle-accuracy is not as important as previous consoles.
* A softcore-based menu system is provided, similar to SNESTang and NESTang.

## Acknowledgements
* [MiSTer GBA core](https://github.com/MiSTer-devel/GBA_MiSTer)
* [risclite's CPU core](https://github.com/risclite/ARM9-compatible-soft-CPU-core)

