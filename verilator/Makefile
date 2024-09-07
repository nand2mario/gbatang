N=gbatang_top
D=../src
SRCS=$D/gbatang_top.sv $D/cpu/gba_cpu.v $D/cpu/gba_cpu_thumbdecoder.v \
	$D/memory/gba_dma.v $D/memory/gba_dma_module.sv $D/gpu/gba_drawer_merge.v $D/gpu/gba_drawer_mode0.v \
	$D/gpu/gba_drawer_mode2.v \
	$D/gpu/gba_drawer_mode345.v $D/gpu/gba_drawer_obj.sv $D/gpu/gba_gpu_colorshade.sv $D/gpu/gba_gpu_drawer.v \
	$D/gpu/gba_gpu_timing.v $D/gpu/gba_gpu.v $D/gpu/gba_timer_module.v $D/gpu/gba_timer.v $D/common/sim_dpram_be.sv \
	$D/memory/gba_memory.sv $D/memory/gba_flash_sram.sv $D/common/sim_spram_be.sv $D/common/eprocreg_gba.sv \
	$D/common/syncramdual.v $D/common/dpram32_block.v $D/memory/gba_eeprom.sv \
	$D/common/syncramdualnotpow2.v $D/peripherals/gba_joypad.v $D/memory/sdram_sim.v $D/test_loader.v \
	$D/sound/gba_sound.v $D/common/dual_clk_fifo.v $D/cpu/gba_interrupts.v\
	$D/sound/gba_sound_ch1.v $D/sound/gba_sound_ch3.v $D/sound/gba_sound_ch4.v $D/sound/gba_sound_dma.v

DEPS=
INCLUDES=-I$D -I$D/arm -I$D/common

CFLAGS_SDL=$(shell sdl2-config --cflags) -g -O2
LIBS_SDL=$(shell sdl2-config --libs) -g

.PHONY: build sim verilate clean gtkwave audio
	
build: ./obj_dir/V$N

verilate: ./obj_dir/V$N.cpp

./obj_dir/V$N.cpp: sim_main.cpp $(SRCS) $(DEPS)
	@echo
	@echo "### VERILATE ####"
	mkdir -p obj_dir
	verilator --top-module $N --timing --trace-fst -Wno-WIDTH -Wno-PINMISSING -Wno-UNOPTFLAT -cc --exe -CFLAGS "$(CFLAGS_SDL)" -LDFLAGS "$(LIBS_SDL)" $(INCLUDES) $(SRCS) sim_main.cpp

./obj_dir/V$N: verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$N.mk V$N
	cp -a $D/roms obj_dir

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
	rm -rf obj_dir
