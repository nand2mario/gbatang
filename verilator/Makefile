N=gbatang_top
D=../src
SRCS=$D/boards/verilator_sim.v $D/gbatang_top.sv $D/cpu/gba_cpu.v $D/cpu/gba_cpu_thumbdecoder.v \
	$D/memory/gba_dma.v $D/memory/gba_dma_module.sv $D/gpu/gba_drawer_merge.v $D/gpu/gba_drawer_mode0.v \
	$D/gpu/gba_drawer_mode2.v \
	$D/gpu/gba_drawer_mode345.v $D/gpu/gba_drawer_obj.sv $D/gpu/gba_gpu_colorshade.sv $D/gpu/gba_gpu_drawer.v \
	$D/gpu/gba_gpu_timing.v $D/gpu/gba_gpu.v $D/gpu/gba_timer_module.v $D/gpu/gba_timer.v $D/gpu/linebuffer.v $D/common/sim_dpram_be.sv \
	$D/memory/gba_memory.sv $D/memory/gba_flash_sram.sv $D/common/sim_spram_be.sv $D/common/eprocreg_gba.sv \
	$D/common/syncramdual.v $D/common/dpram32_block.v $D/memory/gba_eeprom.sv $D/memory/mem_eeprom_sim.v \
	$D/common/syncramdualnotpow2.v $D/peripherals/gba_joypad.v $D/memory/sdram_sim.v \
	$D/sound/gba_sound.v $D/common/dual_clk_fifo.v $D/cpu/gba_interrupts.v\
	$D/sound/gba_sound_ch1.v $D/sound/gba_sound_ch3.v $D/sound/gba_sound_ch4.v $D/sound/gba_sound_dma.v

DEPS=
INCLUDES=-I$D -I$D/arm -I$D/common

CFLAGS_SDL=$(shell sdl2-config --cflags) -g -O3
LIBS_SDL=$(shell sdl2-config --libs) -g

# Fast build: no trace, higher opt, multi-threaded.
# Usage:  make fast   (builds obj_dir_fast/Vgbatang_top)
#         make build  (normal build with --trace-fst for gtkwave)
CFLAGS_FAST=$(shell sdl2-config --cflags) -O3 -DNDEBUG -DVERILATOR_FAST
LIBS_FAST=$(shell sdl2-config --libs)
VL_THREADS?=4

.PHONY: build sim verilate clean gtkwave audio fast verilate-fast build-fast

build: ./obj_dir/V$N

verilate: ./obj_dir/V$N.cpp

./obj_dir/V$N.cpp: sim_main.cpp $(SRCS) $(DEPS)
	@echo
	@echo "### VERILATE ####"
	mkdir -p obj_dir
	verilator --top-module $N +define+CONFIG_H --trace-fst -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -Wno-BLKLOOPINIT -Wno-MULTIDRIVEN -cc --exe -CFLAGS "$(CFLAGS_SDL)" -LDFLAGS "$(LIBS_SDL)" $(INCLUDES) $(SRCS) sim_main.cpp
#	verilator --top-module $N +define+CONFIG_H --timing --trace-fst -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -Wno-BLKLOOPINIT -Wno-MULTIDRIVEN -cc --exe -CFLAGS "$(CFLAGS_SDL)" -LDFLAGS "$(LIBS_SDL)" $(INCLUDES) $(SRCS) sim_main.cpp

./obj_dir/V$N: verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$N.mk V$N

# --- fast path (no tracing, -O3, threaded) -----------------------------------

fast: ./obj_dir_fast/V$N

verilate-fast: ./obj_dir_fast/V$N.cpp

./obj_dir_fast/V$N.cpp: sim_main.cpp $(SRCS) $(DEPS)
	@echo
	@echo "### VERILATE (fast: no trace, -O3, threads=$(VL_THREADS)) ###"
	mkdir -p obj_dir_fast
	verilator --top-module $N +define+CONFIG_H +define+VERILATOR_FAST \
		-O3 --threads $(VL_THREADS) --Mdir obj_dir_fast \
		-Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -Wno-BLKLOOPINIT -Wno-MULTIDRIVEN \
		-cc --exe -CFLAGS "$(CFLAGS_FAST)" -LDFLAGS "$(LIBS_FAST)" \
		$(INCLUDES) $(SRCS) sim_main.cpp

./obj_dir_fast/V$N: verilate-fast
	@echo
	@echo "### BUILDING SIM (fast) ###"
	make -j$(VL_THREADS) -C obj_dir_fast -f V$N.mk V$N OPT_FAST="-O3 -DNDEBUG"

sim: ./obj_dir/V$N
	@echo
	@echo "### SIMULATION (GUI) ###"
	@cd obj_dir && ./V$N -c 10000000

trace: ./obj_dir/V$N
	@echo
	@echo "### SIMULATION (trace) ###"
	@cd obj_dir && ./V$N -t -c 5000000 2> stderr.log

gtkwave:
	gtkwave obj_dir/waveform.fst

audio:
	ffmpeg -y -f s16le -ar 48k -ac 2 -i gba.aud gba.wav

clean:
	rm -rf obj_dir obj_dir_fast
