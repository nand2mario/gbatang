if {$argc == 0} {
    puts "Usage: $argv0 <device>"
    puts "          device: console60k, console138k, mega60k, mega138k, mega138kpro"
    puts "Controllers: ds2 on all boards, and also usb on console boards"
    exit 1
}

set dev [lindex $argv 0]

if {$dev eq "console60k" || $dev eq "mega60k"} {
   set_device GW5AT-LV60PG484AC1/I0 -device_version B
   if {$dev eq "console60k"} {
      add_file -type cst "src/boards/console60k.cst"
      add_file "src/boards/console60k.v"
   } else {
      add_file -type cst "src/boards/mega.cst"
      add_file "src/boards/mega60k.v"
   }
   add_file -type sdc "src/gbatang_ddr.sdc"
   add_file -type verilog "src/plla/pll_27.v"
   add_file -type verilog "src/plla/pll_33.v"
   add_file -type verilog "src/plla/pll_12.v"
   # 60K uses DDR3 framebuffer
   add_file -type verilog "src/plla/pll_ddr3.v"
   add_file -type verilog "src/plla/pll_hdmi.v"
   add_file -type verilog "src/plla/pll_mDRP_intf.v"

   add_file -type verilog "src/usb_hid_host.v"
   add_file -type verilog "src/gba2hdmi_ddr3.sv"
   add_file -type verilog "src/ddr3_framebuffer.v"
   add_file -type verilog "src/ddr3_memory_interface/ddr3_memory_interface.v"
 } elseif {$dev eq "console138k" || $dev eq "mega138k" || $dev eq "mega138kpro"} {
   if {$dev eq "console138k"} {
      set_device GW5AST-LV138PG484AC1/I0 -device_version B
      add_file -type cst "src/boards/console138k.cst"
      add_file "src/boards/console138k.v"
   } elseif {$dev eq "mega138k"} {
      set_device GW5AST-LV138PG484AC1/I0 -device_version B
      add_file -type cst "src/boards/mega.cst"
      add_file "src/boards/mega138k.v"
   } else {
      set_device GW5AST-LV138FPG676AC1/I0 -device_version B
      add_file -type cst "src/boards/mega138kpro.cst"
      add_file "src/boards/mega138kpro.v"
   }
   add_file -type sdc "src/gbatang.sdc"

   add_file -type verilog "src/pll/pll_27.v"
   add_file -type verilog "src/pll/pll_33.v"
   add_file -type verilog "src/pll/pll_74.v"
   add_file -type verilog "src/pll/pll_12.v"

   add_file -type verilog "src/usb_hid_host.v"

   # 138K uses BRAM framebuffer
   add_file -type verilog "src/fb.v"
   add_file -type verilog "src/gba2hdmi.sv"
 } else {
    error "Unknown device $dev"
}

set_option -output_base_name gbatang_${dev}

add_file -type verilog "src/iosys/iosys_bl616.v"
add_file -type verilog "src/iosys/uart_fixed.v"

add_file -type verilog "src/iosys/textdisp.v"
add_file -type verilog "src/iosys/gowin_dpb_menu.v"

add_file -type verilog "src/common/dpram32_block.v"
add_file -type verilog "src/common/dpram_block.v"
add_file -type verilog "src/common/dual_clk_fifo.v"
add_file -type verilog "src/common/eprocreg_gba.sv"
add_file -type verilog "src/common/gba_bios.sv"
add_file -type verilog "src/cpu/gba_cpu.v"
add_file -type verilog "src/cpu/gba_cpu_thumbdecoder.v"
add_file -type verilog "src/cpu/gba_interrupts.v"
add_file -type verilog "src/gbatang_top.sv"
add_file -type verilog "src/gpu/gba_drawer_merge.v"
add_file -type verilog "src/gpu/gba_drawer_mode0.v"
add_file -type verilog "src/gpu/gba_drawer_mode2.v"
add_file -type verilog "src/gpu/gba_drawer_mode345.v"
add_file -type verilog "src/gpu/gba_drawer_obj.sv"
add_file -type verilog "src/gpu/gba_gpu.v"
add_file -type verilog "src/gpu/gba_gpu_colorshade.sv"
add_file -type verilog "src/gpu/gba_gpu_drawer.v"
add_file -type verilog "src/gpu/gba_gpu_timing.v"
add_file -type verilog "src/gpu/gba_timer.v"
add_file -type verilog "src/gpu/gba_timer_module.v"
add_file -type verilog "src/gpu/vram_hi.v"
add_file -type verilog "src/gpu/vram_lo.v"
add_file -type verilog "src/gpu/linebuffer.v"
add_file -type verilog "src/hdmi/audio_clock_regeneration_packet.sv"
add_file -type verilog "src/hdmi/audio_info_frame.sv"
add_file -type verilog "src/hdmi/audio_sample_packet.sv"
add_file -type verilog "src/hdmi/auxiliary_video_information_info_frame.sv"
add_file -type verilog "src/hdmi/hdmi.sv"
add_file -type verilog "src/hdmi/packet_assembler.sv"
add_file -type verilog "src/hdmi/packet_picker.sv"
add_file -type verilog "src/hdmi/serializer.sv"
add_file -type verilog "src/hdmi/source_product_description_info_frame.sv"
add_file -type verilog "src/hdmi/tmds_channel.sv"
add_file -type verilog "src/memory/gba_dma.v"
add_file -type verilog "src/memory/gba_dma_module.sv"
add_file -type verilog "src/memory/gba_eeprom.sv"
add_file -type verilog "src/memory/gba_flash_sram.sv"
add_file -type verilog "src/memory/gba_memory.sv"
add_file -type verilog "src/memory/mem_eeprom.v"
add_file -type verilog "src/memory/mem_iwram.v"
add_file -type verilog "src/memory/rv_sdram_adapter.v"
add_file -type verilog "src/memory/sdram_gba.v"
add_file -type verilog "src/peripherals/controller_ds2.sv"
add_file -type verilog "src/peripherals/dualshock_controller.v"
add_file -type verilog "src/peripherals/gba_joypad.v"
add_file -type verilog "src/sound/gba_sound.v"
add_file -type verilog "src/sound/gba_sound_ch1.v"
add_file -type verilog "src/sound/gba_sound_ch3.v"
add_file -type verilog "src/sound/gba_sound_ch4.v"
add_file -type verilog "src/sound/gba_sound_dma.v"

#add_file -type verilog "src/test_loader.v"

set_option -synthesis_tool gowinsynthesis
set_option -top_module gbatang_top
set_option -include_path {"src/common"}
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -ireg_in_iob 1
set_option -oreg_in_iob 1
set_option -ioreg_in_iob 1
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -use_cpu_as_gpio 1

# use the slower but timing-optimized place algorithm
set_option -place_option 2

run all
