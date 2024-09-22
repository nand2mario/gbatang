#include <cstdio>
#include <iostream>
#include <cstdlib>
#include <climits>
#include <cstring>
#include <vector>
#include <cctype>
#include <SDL.h>

#include "Vgbatang_top.h"
#include "Vgbatang_top___024root.h"
#include "Vgbatang_top_gbatang_top.h"
#include "Vgbatang_top_gba_gpu.h"
#include "Vgbatang_top_gba_cpu.h"
#include "Vgbatang_top_gba_gpu_drawer.h"
#include "Vgbatang_top_dpram32_block.h"
#include "Vgbatang_top_sim_dpram_be__D4000.h"
#include "Vgbatang_top_sim_dpram_be__D2000.h"

#include "verilated.h"
#include <verilated_fst_c.h>

#define TRACE_ON

using namespace std;

// See: https://projectf.io/posts/verilog-sim-verilator-sdl/
const int H_RES = 240;
const int V_RES = 160;

typedef struct Pixel
{			   // for SDL texture
	uint8_t a; // transparency
	uint8_t b; // blue
	uint8_t g; // green
	uint8_t r; // red
} Pixel;

Pixel screenbuffer[H_RES * V_RES];

long long max_sim_time = 0LL;

bool trace_toggle;				// -t or "t" key
bool trace_loading;				// -tl option
long long start_trace_time;		// -tt option
int start_trace_frame;			// -tf option
bool showFrameCount = true;

void usage()
{
	printf("Usage: sim [options] <rom_file>\n");
	printf("  -t     start tracing once GBA is on (to waveform.fst)\n");
	printf("  -tt T  start tracing from time T\n");
	printf("  -tf F  start tracing from frame F\n");
	printf("  -tl    start tracing from game loading (i.e. before GBA is turned on)\n");
	printf("  -s T   stop simulation at time T\n");
	printf("  -m     print all memory writes (after BIOS initialization)");
	printf("  -f     print flash related memory accesses\n");
}

void help() {
	printf("ROM loaded. Use these keys in the simulation window for controls:\n");
	printf("SPC: Start/stop simulation.      ESC: Quit.\n");
	printf("P: view sprites.                 M: view BG0 tilemap      T: toggle tracing on/off\n");
	printf("Arrow keys: D-pad, A: B button, S: A button, Z: L button, X: R button, Q: Select, W: Start\n");
	// printf("V: dump VRAM.\n");
	// printf("I: show additional info like frame count.\n");
}

VerilatedFstC *m_trace;
Vgbatang_top *top = new Vgbatang_top;
Vgbatang_top_gbatang_top *gba = top->gbatang_top;
uint64_t sim_time;
uint8_t clkcnt;

Vgbatang_top_sim_dpram_be__D4000 *ivram_lo = gba->gpu->drawer->ivram_lo;
Vgbatang_top_sim_dpram_be__D2000 *ivram_hi = gba->gpu->drawer->ivram_hi;
Vgbatang_top_dpram32_block *palette_bg = gba->gpu->drawer->paletteram_bg;
Vgbatang_top_dpram32_block *palette_oam = gba->gpu->drawer->paletteram_oam;
Vgbatang_top_dpram32_block *oam = gba->gpu->drawer->oamram;

// split by spaces
vector<string> tokenize(string s);
long long parse_num(string s);
void trace_on();
void trace_off();

static bool posedge;
static int clk16_last;

static void loading_step()
{
	Vgbatang_top_gbatang_top *gba = top->gbatang_top;
	clkcnt = clkcnt == 5 ? 0 : clkcnt + 1;
	top->clk50 = clkcnt & 1;
	top->clk16 = clkcnt >= 3;
	top->eval();
	if (trace_toggle && trace_loading) {
		m_trace->dump(sim_time);
	}
	sim_time++; // advance simulation time
	posedge = (top->clk16 == 1 && clk16_last == 0);
	clk16_last = top->clk16;
}

const int BACKUP_NONE = 0;
const int BACKUP_FLASH = 1;
const int BACKUP_SRAM = 2;
const int BACKUP_EEPROM = 3;
// const int BACKUP_EEPROM_64K = 4;

const char *backup_type_name(int t) {
	if (t == 0) return "NONE";
	if (t == 1) return "FLASH";
	if (t == 2) return "SRAM";
	if (t == 3) return "EEPROM";
	if (t == 4) return "EEPROM_64K";
	return "UNKNOWN";
} 

// load a GBA ROM
// size: number of bytes
void gba_load(uint8_t *rom, int size, int backup_type)
{
	Vgbatang_top_gbatang_top *gba = top->gbatang_top;
	int clk16_last = 0;

	while (sim_time < 10 || !posedge)
		loading_step();

	top->loading = 1; // reset GBA and start loading ROM
	loading_step();

	for (int i = 0; i < size; i++)
	{ // send the bytes
		do loading_step(); while (!posedge);

		top->loader_do = rom[i];
		top->loader_do_valid = 1;

		for (int j = 0; j < 3; j++)	{	// wait 3 cycles for SDRAM
			do loading_step(); while (!posedge);
			top->loader_do_valid = 0;
		}
	}

	for (int i = 0; i < 100; i++) {
		loading_step();
		if (posedge) {
			top->loader_do_valid = 0;
			if (i > 50)
				top->loading = 2;
		}
	}

	// loading 128KB of cartram (all 0xff for now)
	printf("Start loading cartram\n");
	for (int i = 0; i < 128*1024; i++) {
		do loading_step(); while (!posedge);

		top->loader_do_valid = 1;
		if (backup_type == BACKUP_SRAM | backup_type == BACKUP_FLASH)
			top->loader_do = 0xff;
		else
			top->loader_do = 0x00;

		for (int j = 0; j < 4; j++)	{	// cartram is 4 cycles wait
			do loading_step(); while (!posedge);
			top->loader_do_valid = 0;
		}
	}
	printf("Finished loading cartram\n");

	printf("Configure backup type\n");
	do loading_step(); while (!posedge);
	top->loading = 3;
	do loading_step(); while (!posedge);
	top->loader_do_valid = 1;
	top->loader_do = backup_type == BACKUP_FLASH;	// bit 0 is FLASH
	do loading_step(); while (!posedge);
	printf("Finished configuring backup type\n");

	for (int i = 0; i < 40; i++)
	{
		loading_step();
		if (posedge)
		{
			top->loader_do_valid = 0;

			if (i >= 30) // finished loading and start GBA
				top->loading = 0;
		}
	}
}

int detect_backup_type(uint8_t *rom, int size) {
	for (int i = 0; i < size-4; i+=4) {
		char *p = (char *)rom+i;
		if (strncmp(p, "EEPROM_V", 8) == 0)
			return BACKUP_EEPROM;
		// if (strncmp(p, "EEPROM_V12", 10) == 0)
		// 	return BACKUP_EEPROM_64K;
		if (strncmp(p, "FLASH_V", 7) == 0)
			return BACKUP_FLASH;
		if (strncmp(p, "FLASH512_V", 10) == 0)
			return BACKUP_FLASH;
		if (strncmp(p, "FLASH1M_V", 9) == 0)
			return BACKUP_FLASH;
		if (strncmp(p, "SRAM_V", 6) == 0)
			return BACKUP_SRAM;
		if (strncmp(p, "SRAM_F_V", 8) == 0)
			return BACKUP_SRAM;
	}
	return BACKUP_NONE;
}

void load_rom(char *filename)
{
	FILE *f = fopen(filename, "rb");
	if (!f)
	{
		printf("Cannot open file %s\n", filename);
		exit(1);
	}
	fseek(f, 0, SEEK_END);
	long size = ftell(f);
	fseek(f, 0, SEEK_SET); // return to start of file
	uint8_t *rom = (uint8_t *)malloc(size);
	size_t r = fread(rom, 1, size, f);
	if (r != size)
	{
		printf("Cannot read file %s (%ld / %ld)\n", filename, r, size);
		exit(1);
	}
	fclose(f);

	int backup_type = detect_backup_type(rom, size);
	printf("Backup type: %d (%s)\n", backup_type, backup_type_name(backup_type));
	gba_load(rom, size, backup_type);
	free(rom);
}

SDL_Window *sdl_sprites_window = NULL;
SDL_Renderer *sdl_sprites_renderer = NULL;
SDL_Texture *sdl_sprites_texture = NULL;
SDL_Window *sdl_tilemap_window = NULL;
SDL_Renderer *sdl_tilemap_renderer = NULL;
SDL_Texture *sdl_tilemap_texture = NULL;

void createSpritesWindow();
void showSpritesWindow();
void createTilemapWindow();
void showTilemapWindow();

// memory logging
bool memlog_en, flashlog_en;
uint32_t memlog_addr, memlog_wdata;
uint8_t memlog_be;
bool memlog_wr;
bool memlog_bios_done;
void memlog(const char *hdr, uint32_t addr, uint32_t wdata, uint8_t be, bool wr);
void memlog_acc(const char *hdr, uint32_t addr, uint32_t wdata, uint8_t be, bool wr);
const char * register_name(uint32_t addr);
uint8_t cpu_en_r, ram_be_r, ram_cen_r, ram_wen_r;
uint32_t ram_addr_r;
int bgn = 0;			// BG number to show in tilemap window

int main(int argc, char **argv, char **env)
{
	Verilated::commandArgs(argc, argv);
	Vgbatang_top_gbatang_top *gba = top->gbatang_top;
	bool frame_updated = false;
	uint64_t start_ticks = SDL_GetPerformanceCounter();
	int frame_count = 0;

	if (argc == 1)
	{
		usage();
		exit(1);
	}

	// parse options
	bool loaded = false;
	for (int i = 1; i < argc; i++)
	{
		char *eptr;
		if (strcmp(argv[i], "-t") == 0)
		{
			trace_toggle = true;
			printf("Tracing ON\n");
			trace_on();
		}
		else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc)
		{
			max_sim_time = strtoll(argv[++i], &eptr, 10);
			if (max_sim_time == 0)
				printf("Simulating forever.\n");
			else
				printf("Simulating %lld steps\n", max_sim_time);
		}
		else if (strcmp(argv[i], "-tt") == 0 && i + 1 < argc) {
			start_trace_time = strtoll(argv[++i], &eptr, 10);
			printf("Start tracing from %lld\n", start_trace_time);
		}
		else if (strcmp(argv[i], "-tf") == 0 && i + 1 < argc) {
			start_trace_frame = atoi(argv[++i]);
			printf("Start tracing from frame %d\n", start_trace_frame);
		}
		else if (strcmp(argv[i], "-tl") == 0) {
			trace_loading = true;
			trace_on();
			trace_toggle = true;
			printf("Include loading in tracing\n");
		}
		else if (strcmp(argv[i], "-m") == 0) {
			memlog_en = true;
			printf("Printing memory log\n");
		} 
		else if (strcmp(argv[i], "-f") == 0) {
			flashlog_en = true;
			printf("Printing flash log\n");
		}
		else if (argv[i][0] == '-') {
			printf("Unrecognized option: %s\n", argv[i]);
			usage();
			exit(1);
		}
		else
		{
			// load ROM
			load_rom(argv[i]);
			loaded = true;

			if (!trace_loading)
				sim_time = 0;		// return sim_time to 0 when we are not tracing loading
		}
	}
	if (!loaded)
	{
		usage();
		exit(1);
	}

	if (SDL_Init(SDL_INIT_VIDEO) < 0)
	{
		printf("SDL init failed.\n");
		return 1;
	}

	SDL_Window *sdl_window = NULL;
	SDL_Renderer *sdl_renderer = NULL;
	SDL_Texture *sdl_texture = NULL;

	sdl_window = SDL_CreateWindow("GBATang Sim", SDL_WINDOWPOS_CENTERED,
								  SDL_WINDOWPOS_CENTERED, H_RES * 2, V_RES * 2, SDL_WINDOW_SHOWN);
	if (!sdl_window)
	{
		printf("Window creation failed: %s\n", SDL_GetError());
		return 1;
	}
	sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
									  SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	if (!sdl_renderer)
	{
		printf("Renderer creation failed: %s\n", SDL_GetError());
		return 1;
	}

	sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
									SDL_TEXTUREACCESS_TARGET, H_RES, V_RES);
	if (!sdl_texture)
	{
		printf("Texture creation failed: %s\n", SDL_GetError());
		return 1;
	}

	FILE *f = fopen("gba.aud", "w");
	long long samples = 0;
	bool sample_valid = false;

	bool sim_on = true; // max_sim_time > 0;
	bool done = false;
	uint64_t cnt = 0;

	SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES * sizeof(Pixel));
	SDL_RenderClear(sdl_renderer);
	SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
	SDL_RenderPresent(sdl_renderer);
	SDL_StopTextInput(); // for SDL_KEYDOWN

	createSpritesWindow();
	createTilemapWindow();

	// (R L X A RT LT DN UP START SELECT Y B)
	// top->joy_btns = 1 << 6;	// left button is on

	help();

	while (!done)
	{
		cnt++;

		if (sim_on && max_sim_time > 0 && sim_time >= max_sim_time) {
			printf("Simulation time is up: sim_time=%llu\n", sim_time);
			sim_on = false;
		}

		if (sim_on) {

			sim_time++;

			// if (sim_time == 3 * 1000 * 1000)
			// 	// top->joy_btns = 1 << 11;	// right shoulder button is on
			// 	top->joy_btns = 1 << 10; // left shoulder button is on
			clkcnt = clkcnt == 5 ? 0 : clkcnt + 1;
			top->clk50 = clkcnt & 1;
			top->clk16 = clkcnt >= 3;
			top->eval();
			posedge = (top->clk16 == 1 && clk16_last == 0);
			clk16_last = top->clk16;

			if (	trace_toggle ||
					start_trace_time != 0 && sim_time == start_trace_time ||
					start_trace_frame != 0 && frame_count == start_trace_frame) 
			{
				trace_toggle = true;
				trace_on();
				m_trace->dump(sim_time);
			}

			// collect on-demand memory samples
			if (gba->rom_addr == 0x8000000 && memlog_en) 
				memlog_bios_done = true;
			if (gba->ram_cen & gba->ram_wen & memlog_bios_done) 
				memlog("CPU", gba->ram_addr, gba->ram_wdata, gba->ram_be, true);
			if (gba->dma_on & gba->dma_bus_ena & gba->dma_rnw == 0 & memlog_bios_done) {
				memlog_acc("DMA", gba->dma_addr, gba->dma_wdata, gba->dma_bus_acc, true);
			}

			// collect flash memory samples
			if (posedge) {
				if (gba->ram_cen & gba->ram_wen & (gba->ram_addr >> 25 == 7) & flashlog_en)
					memlog("Write flash", gba->ram_addr, gba->ram_wdata, gba->ram_be, true);
				
				if (cpu_en_r & ram_cen_r & ~ram_wen_r & (ram_addr_r >> 25 == 7) & flashlog_en) {		// region E and F
					memlog("Read flash", ram_addr_r, gba->ram_rdata, ram_be_r, false);
				}
				cpu_en_r = gba->cpu_en;
				ram_addr_r = gba->ram_addr;
				ram_be_r = gba->ram_be;
				ram_cen_r = gba->ram_cen;
				ram_wen_r = gba->ram_wen;
			} 


			// collect audio samples @ 48Khz
			if (sim_time % (16780000 * 4 / 48000) == 0 && top->gba_on) {
				uint16_t ar, al;
				ar = gba->sound_out_right;
				al = gba->sound_out_left;
				if (al != 0 || ar != 0)
					sample_valid = true;
				fwrite(&ar, sizeof(ar), 1, f);
				fwrite(&al, sizeof(al), 1, f);
				samples++;
				if (samples % 1000 == 0 && sample_valid)
				{
					printf("%lld sound samples\n", samples);
					sample_valid = false;
				}
			}

			if (gba->pixel_out_we && gba->pixel_out_x < H_RES && gba->pixel_out_y < V_RES)
			{
				Pixel *p = &screenbuffer[gba->pixel_out_y * H_RES + gba->pixel_out_x];
				int rgb = gba->pixel_out_data;
				p->a = 0xff;
				p->r = (rgb >> 12) << 2; // convert 6-bit RGB to 8-bit RGB
				p->g = ((rgb >> 6) & 0x3f) << 2;
				p->b = (rgb & 0x3f) << 2;
			}

			// update texture once per frame (in blanking)
			if (gba->pixel_out_we && gba->pixel_out_y == V_RES - 1 && gba->pixel_out_x == H_RES - 1)
			{
				if (!frame_updated)
				{
					// check for quit event
					frame_updated = true;
					SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES * sizeof(Pixel));
					SDL_RenderClear(sdl_renderer);
					SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
					SDL_RenderPresent(sdl_renderer);
					frame_count++;

					if (frame_count % 5 == 0 || m_trace)
						printf("Frame #%d\n", frame_count);

					if (showFrameCount) {
						SDL_SetWindowTitle(sdl_window, ("GBATang Sim - frame " + to_string(frame_count) + 
											(trace_toggle ? " tracing" : "")).c_str());
					} else {
						SDL_SetWindowTitle(sdl_window, "GBATang Sim");
					}
				}
			}
			else
				frame_updated = false;
		}

		if (cnt % 100 == 0)
		{
			// check for SDL events
			SDL_Event e;
			if (SDL_PollEvent(&e))
			{
				// printf("Event type: %d, SDL_KEYDOWN=%d\n", e.type, SDL_KEYDOWN);
				switch (e.type) {
				
				case SDL_QUIT:
					done = true;
					break;
				case SDL_KEYDOWN:
					// printf("Key pressed: %d\n", e.key.keysym.sym);
					switch (e.key.keysym.sym) {
					case SDLK_SPACE: 
						sim_on = !sim_on;
						max_sim_time = 0;
						if (sim_on)
							printf("Simulation started\n");
						else
							printf("Simulation stopped: sim_time=%llu\n", sim_time);
						break;
					case SDLK_ESCAPE: 	done = true; break;
					case SDLK_p:		showSpritesWindow(); break;
					case SDLK_m:        showTilemapWindow(); break;
					case SDLK_t:		trace_toggle = !trace_toggle; break;
					case SDLK_v: {
						FILE *f = fopen("vram.bin", "wb");
						if (!f)
						{
							cout << "Cannot open vram.bin for writing" << endl;
							continue;
						}
						uint8_t *vram = (uint8_t *)malloc(96 * 1024); // 96KB
						for (int i = 0; i < 64 * 1024; i += 4)
							((uint32_t *)vram)[i / 4] = ivram_lo->mem[i / 4];
						for (int i = 0; i < 32 * 1024; i += 4)
							((uint32_t *)vram)[16384 + i / 4] = ivram_hi->mem[i / 4];
						fwrite(vram, 1, 96 * 1024, f);
						free(vram);
						fclose(f);
						cout << "VRAM dumped to vram.bin" << endl;
						break;
					}
					case SDLK_i:	showFrameCount = !showFrameCount; break;
					}
					// FALL THROUGH				
				case SDL_KEYUP:
					// (R L X A RT LT DN UP START SELECT Y B)
					int bit;
					switch (e.key.keysym.sym) {
					case SDLK_UP:		bit = 4; break;
					case SDLK_DOWN:		bit = 5; break;
					case SDLK_LEFT:		bit = 6; break;
					case SDLK_RIGHT:	bit = 7; break;
					case SDLK_a:		bit = 0; break;
					case SDLK_s:		bit = 8; break;
					case SDLK_z:		bit = 10; break;
					case SDLK_x:		bit = 11; break;
					case SDLK_q:		bit = 2; break;
					case SDLK_w:		bit = 3; break;
					default: 			bit = -1; break;
					} 
					if (bit >= 0) {
						if (e.type == SDL_KEYDOWN) 
							top->joy_btns |= 1 << bit;
						else
							top->joy_btns &= ~(1 << bit);
					}

					// switch BG number in tilemap window
					if (e.window.windowID == SDL_GetWindowID(sdl_tilemap_window)) {
						bool show = false;
						switch (e.key.keysym.sym) {
						case SDLK_0: bgn = 0; show = true; break;
						case SDLK_1: bgn = 1; show = true; break;
						case SDLK_2: bgn = 2; show = true; break;
						case SDLK_3: bgn = 3; show = true; break;
						}
						if (show) showTilemapWindow();
					}

					break;
				case SDL_WINDOWEVENT:
					if (e.window.event == SDL_WINDOWEVENT_CLOSE) {
						if (e.window.windowID == SDL_GetWindowID(sdl_sprites_window))
							SDL_HideWindow(sdl_sprites_window);
						else if (e.window.windowID == SDL_GetWindowID(sdl_tilemap_window))
							SDL_HideWindow(sdl_tilemap_window);
						else if (e.window.windowID == SDL_GetWindowID(sdl_window))
							done = true;
					}
					break;
				}
			}
		}
	}

	fclose(f);
	printf("Audio output to gba.aud done.\n");

	if (m_trace)
		m_trace->close();
	delete top;

	// calculate frame rate
	uint64_t end_ticks = SDL_GetPerformanceCounter();
	double duration = ((double)(end_ticks - start_ticks)) / SDL_GetPerformanceFrequency();
	double fps = (double)frame_count / duration;
	printf("Frames per second: %.1f. Total frames=%d\n", fps, frame_count);

	SDL_DestroyTexture(sdl_texture);
	SDL_DestroyRenderer(sdl_renderer);
	SDL_DestroyWindow(sdl_window);
	SDL_Quit();

	return 0;
}

// 128 sprites, each up to 64x64 pixels
Pixel spritesScreen[65 * 16 * 65 * 8]; // 16 sprites per row, 8 rows

void createSpritesWindow()
{
	SDL_DisplayMode DM;
	SDL_GetCurrentDisplayMode(0, &DM);
	int ypos = DM.h / 2 + 200;
	sdl_sprites_window = SDL_CreateWindow("Sprite Viewer", SDL_WINDOWPOS_CENTERED,
								ypos, 65 * 16, 65 * 8, SDL_WINDOW_HIDDEN);
	sdl_sprites_renderer = SDL_CreateRenderer(sdl_sprites_window, -1,
								SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	sdl_sprites_texture = SDL_CreateTexture(sdl_sprites_renderer, SDL_PIXELFORMAT_RGBA8888,
								SDL_TEXTUREACCESS_TARGET, 65 * 16, 65 * 8);
	if (!sdl_sprites_renderer || !sdl_sprites_window || !sdl_sprites_texture)
	{
		printf("Sprites window creation failed: %s\n", SDL_GetError());
		exit(1);
	}
}

struct OAM
{
	uint16_t attr0;
	uint16_t attr1;
	uint16_t attr2;
	uint16_t affine;
	int xs, ys;
	int xsize()	{
		return xs;
	}
	int ysize()	{
		return ys;
	}
	bool hflip() {
		return attr1 & 0x1000;
	}
	bool vflip() {
		return attr1 & 0x2000;
	}
	bool hicolor() {
		return attr0 & 0x2000;
	}
	int palette() {
		return (attr2 >> 12) & 0xf;
	}
	// tile id in VRAM starting 0x6001000 (32-byte tiles)
	int tile() {
		return attr2 & 0x3ff;
	}
	OAM(int idx) {
		int off = idx * 2;
		attr0 = oam->ram[off] & 0xffff;
		attr1 = oam->ram[off] >> 16;
		attr2 = oam->ram[off + 1] & 0xffff;;
		affine = oam->ram[off + 1] >> 16;
		int s = ((attr0 >> 14) << 2) + (attr1 >> 14);
		switch (s) {
			case 0x0: xs = 8; ys = 8; break;
			case 0x1: xs = 16; ys = 16; break;
			case 0x2: xs = 32; ys = 32; break;
			case 0x3: xs = 64; ys = 64; break;
			case 0x4: xs = 16; ys = 8; break;
			case 0x5: xs = 32; ys = 8; break;
			case 0x6: xs = 32; ys = 16; break;
			case 0x7: xs = 64; ys = 32; break;
			case 0x8: xs = 8; ys = 16; break;
			case 0x9: xs = 8; ys = 32; break;
			case 0xa: xs = 16; ys = 32; break;
			case 0xb: xs = 32; ys = 64; break;
			default: xs = 0; ys = 0; break;		// not used
		}
	}
};

Pixel getSpritePixel(int sprite, int x, int y)
{
	Vgbatang_top_gbatang_top *gba = top->gbatang_top;
	Pixel p = {255, 0, 0, 0};
	// look up OAM, 128 sprites, each 8 bytes
	// https://gbadev.net/gbadoc/sprites.html
	OAM oam(sprite);
	bool is1d = gba->gpu->drawer->REG_DISPCNT_OBJ_Char_VRAM_Map; // 1D or 2D mapping: https://gbadev.net/gbadoc/sprites.html#sprite-tile-data
	int xsize = oam.xsize();
	int ysize = oam.ysize();
	if (x >= xsize || y >= ysize){
		return p;
	}
	int tile = oam.tile();
	int xoff = x & 7;
	int yoff = y & 7;
	int tile_step = oam.hicolor() ? 2 : 1;
	int t;
	int vram_addr;
	if (is1d) 
		t = tile + (x/8 + y/8*(xsize/8)) * tile_step;		// 1D mapping
	else
		t = tile + (x/8 * tile_step + y/8*32);				// 2D mapping
	if (oam.hicolor()) {
		// 8-bit color
		// 8 bytes per line, 64 bytes per tile, vram_hi is 32-bit
		vram_addr = t * 32 + yoff * 8 + (xoff / 4) * 4;
		uint8_t color = (ivram_hi->mem[vram_addr / 4] >> ((x & 3) * 8)) & 0xff;
		// palette 256 entries, 16-bit each
		uint16_t bgr5 = (color & 1) ? 
				(palette_oam->ram[color >> 1] >> 16) :
				(palette_oam->ram[color >> 1] & 0xffff);
		if (sprite == 0) {
			printf("x=%d, y=%d, vram_addr=%x, color=%x, bgr5=%x\n", x, y, vram_addr, color, bgr5);
		}
		p.r = (bgr5 & 0x1f) << 3;
		p.g = ((bgr5 >> 5) & 0x1f) << 3;
		p.b = ((bgr5 >> 10) & 0x1f) << 3;
	} else {
		// 4-bit color
		vram_addr = t * 32 + yoff * 4;
		uint8_t color = (ivram_hi->mem[vram_addr / 4] >> (xoff * 4)) & 0xf;
		int pal_addr = oam.palette() * 16 + color;
		uint16_t bgr5 = (pal_addr & 1) ? 
				(palette_oam->ram[pal_addr >> 1] >> 16) :
				(palette_oam->ram[pal_addr >> 1] & 0xffff);
		p.r = (bgr5 & 0x1f) << 3;
		p.g = ((bgr5 >> 5) & 0x1f) << 3;
		p.b = ((bgr5 >> 10) & 0x1f) << 3;
		if (sprite == 1) {
			printf("x=%d, y=%d, vram_addr=%x, color=%x, bgr5=%x\n", x, y, vram_addr, color, bgr5);
		}
	}

	return p;
}

void showSpritesWindow()
{
	printf("Showing sprites window\n");
	// draw to the spritesScreen buffer
	for (int y = 0; y < 65 * 8 - 1; y++)
		for (int x = 0; x < 65 * 16; x++)
		{
			Pixel *p = &spritesScreen[y * 65 * 16 + x];
			p->a = 0xff;
			if (y % 65 == 64 || x % 65 == 64)
			{
				p->r = 0x80;
				p->g = 0x80;
				p->b = 0x80;
			}
			else
			{
				int sprite = (y / 65) * 16 + x / 65;
				int x0 = x % 65;
				int y0 = y % 65;
				*p = getSpritePixel(sprite, x0, y0);
			}
		}

	SDL_UpdateTexture(sdl_sprites_texture, NULL, spritesScreen, 65 * 16 * sizeof(Pixel));
	SDL_RenderClear(sdl_sprites_renderer);
	SDL_RenderCopy(sdl_sprites_renderer, sdl_sprites_texture, NULL, NULL);
	SDL_RenderPresent(sdl_sprites_renderer);
	SDL_ShowWindow(sdl_sprites_window);
	printf("Done showing sprites window\n");
}

void destroySpritesWindow()
{
	SDL_DestroyTexture(sdl_sprites_texture);
	SDL_DestroyRenderer(sdl_sprites_renderer);
	SDL_DestroyWindow(sdl_sprites_window);
}

// rendered tilemap background
Pixel bg[512][512];

void createTilemapWindow()
{
	SDL_DisplayMode DM;
	SDL_GetCurrentDisplayMode(0, &DM);
	int ypos = DM.h / 2 - 300;
	int xpos = DM.w / 2 + 250;
	sdl_tilemap_window = SDL_CreateWindow("Tilemap Viewer", xpos,
								ypos, 512, 512, SDL_WINDOW_HIDDEN);
	sdl_tilemap_renderer = SDL_CreateRenderer(sdl_tilemap_window, -1,
								SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	sdl_tilemap_texture = SDL_CreateTexture(sdl_tilemap_renderer, SDL_PIXELFORMAT_RGBA8888,
								SDL_TEXTUREACCESS_TARGET, 512, 512);
	if (!sdl_tilemap_renderer || !sdl_tilemap_window || !sdl_tilemap_texture)
	{
		printf("Tilemap window creation failed: %s\n", SDL_GetError());
		exit(1);
	}
}

void showTilemapWindow() {
	printf("Showing tilemap windows for BG%d\n", bgn);
	int charBase, screenBase, screenSize, hicolor;
	switch (bgn) {
		case 1:
			charBase   = gba->gpu->drawer->REG_BG1CNT_Character_Base_Block;	
			screenBase = gba->gpu->drawer->REG_BG1CNT_Screen_Base_Block;	
			screenSize = gba->gpu->drawer->REG_BG1CNT_Screen_Size;			
			hicolor    = gba->gpu->drawer->REG_BG1CNT_Colors_Palettes;			
			break;
		case 2:
			charBase   = gba->gpu->drawer->REG_BG2CNT_Character_Base_Block;	
			screenBase = gba->gpu->drawer->REG_BG2CNT_Screen_Base_Block;	
			screenSize = gba->gpu->drawer->REG_BG2CNT_Screen_Size;			
			hicolor    = gba->gpu->drawer->REG_BG2CNT_Colors_Palettes;			
			break;
		case 3:
			charBase   = gba->gpu->drawer->REG_BG3CNT_Character_Base_Block;	
			screenBase = gba->gpu->drawer->REG_BG3CNT_Screen_Base_Block;	
			screenSize = gba->gpu->drawer->REG_BG3CNT_Screen_Size;			
			hicolor    = gba->gpu->drawer->REG_BG3CNT_Colors_Palettes;			
			break;
		default: 
			printf("Invalid BG number\n");
			// fall through
		case 0:
			charBase   = gba->gpu->drawer->REG_BG0CNT_Character_Base_Block;	// tile data, in 16KB
			screenBase = gba->gpu->drawer->REG_BG0CNT_Screen_Base_Block;	// map data, in 2KB 
			screenSize = gba->gpu->drawer->REG_BG0CNT_Screen_Size;			// 0=256x256, 1=512x256, 2=256x512, 3=512x512
			hicolor    = gba->gpu->drawer->REG_BG0CNT_Colors_Palettes;		// 0=16 colors, 1=256 colors
			break;
	}	

	int sc_count = 1;
	int w, h;
	if (screenSize == 1 || screenSize == 2) sc_count = 2;
	if (screenSize == 3) sc_count = 4;

	string title("Tilemap Viewer - BG");
	title += to_string(bgn);
	if (screenSize == 0) {
		title += " 256x256";
		w = 256; h = 256;
	}
	if (screenSize == 1) {
		title += " 512x256";
		w = 512; h = 256;
	}
	if (screenSize == 2) {
		title += " 256x512";
		w = 256; h = 512;
	}
	if (screenSize == 3) {
		title += " 512x512";
		w = 512; h = 512;
	}
	title += " (press num to switch)";

	SDL_SetWindowTitle(sdl_tilemap_window, title.c_str());

	for (int sc = 0; sc < sc_count; sc++) {
		int screen = (screenBase + sc) * 2048;
		int y0 = 0, x0 = 0;
		if (screenSize == 1) {
			if (sc == 1) x0 = 256;
		} else if (screenSize == 2) {
			if (sc == 1) y0 = 256;
		} else if (screenSize == 3) {
			if (sc == 1) x0 = 256;
			if (sc == 2) y0 = 256;
			if (sc == 3) x0 = 256, y0 = 256;
		}
		for (int sy = 0; sy < 32; sy++)
			for (int sx = 0; sx < 32; sx++) {
				int map = screen + (sy * 32 + sx) * 2;
				uint16_t data = (ivram_lo->mem[map / 4] >> ((map % 4 != 0) * 16)) & 0xffff;
				int tile = data & 0x3ff;
				int hflip = data & 0x400;
				int vflip = data & 0x800;
				int palette = (data >> 12) & 0xf;

				// draw the tile to bg
				for (int y = 0; y < 8; y++)
					for (int x = 0; x < 8; x++) {
						Pixel *p = &bg[y0 + sy * 8 + y][x0 + sx * 8 + x];
						uint16_t bgr5;
						int xx = hflip ? 7 - x : x;
						int yy = vflip ? 7 - y : y;
						if (hicolor) {
							// 1 pixel per byte, 4 pixels per word
							int vram = charBase * 16384 + tile * 64 + yy * 8 + xx;
							uint8_t color = (ivram_lo->mem[vram / 4] >> (xx % 4 * 8)) & 0xff;
							bgr5 = (color & 1) ? 
									(palette_bg->ram[color >> 1] >> 16) :
									(palette_bg->ram[color >> 1] & 0xffff);

						} else {
							// 2 pixels per byte, 8 pixels per word
							int vram = charBase * 16384 + tile * 32 + yy * 4 + xx / 2;		
							uint8_t color = (ivram_lo->mem[vram / 4] >> (xx * 4)) & 0xf;
							int pal_addr = color ? palette * 16 + color : 0;		// color 0 is "backdrop" (palette 0 color 0)
							bgr5 = (pal_addr & 1) ? 
									(palette_bg->ram[pal_addr >> 1] >> 16) :
									(palette_bg->ram[pal_addr >> 1] & 0xffff);
						}
						p->r = (bgr5 & 0x1f) << 3;
						p->g = ((bgr5 >> 5) & 0x1f) << 3;
						p->b = ((bgr5 >> 10) & 0x1f) << 3;
					}
			}
	}

	// update texture
	SDL_UpdateTexture(sdl_tilemap_texture, NULL, bg, 512 * sizeof(Pixel));
	SDL_RenderClear(sdl_tilemap_renderer);
	SDL_SetWindowSize(sdl_tilemap_window, w*2, h*2);
	SDL_Rect rect = {0, 0, w, h};
	SDL_RenderCopy(sdl_tilemap_renderer, sdl_tilemap_texture, &rect, NULL);
	SDL_RenderPresent(sdl_tilemap_renderer);
	SDL_ShowWindow(sdl_tilemap_window);
	printf("Done showing tilemap window\n");
}

void destroyTilemapWindow()
{
	SDL_DestroyTexture(sdl_tilemap_texture);
	SDL_DestroyRenderer(sdl_tilemap_renderer);
	SDL_DestroyWindow(sdl_tilemap_window);
}


bool is_space(char c)
{
	return c == ' ' || c == '\t';
}

vector<string> tokenize(string s)
{
	string w;
	vector<string> r;

	for (int i = 0; i < s.size(); i++)
	{
		char c = s[i];
		if (is_space(c) && w.size() > 0)
		{
			r.push_back(w);
			w = "";
		}
		if (!is_space(c))
			w += c;
	}
	if (w.size() > 0)
		r.push_back(w);
	return r;
}

// parse something like 100m or 10k
// return -1 if there's an error
long long parse_num(string s)
{
	long long times = 1;
	if (s.size() == 0)
		return -1;
	char last = tolower(s[s.size() - 1]);
	if (last >= 'a' && last <= 'z')
	{
		s = s.substr(0, s.size() - 1);
		if (last == 'k')
			times = 1000LL;
		else if (last == 'm')
			times = 1000000LL;
		else if (last == 'g')
			times = 1000000000LL;
		else
			return -1;
	}
	return atoll(s.c_str()) * times;
}

void trace_on()
{
	if (!m_trace)
	{
		m_trace = new VerilatedFstC;
		top->trace(m_trace, 5);
		Verilated::traceEverOn(true);
		m_trace->open("waveform.fst");
	}
}

void trace_off()
{
	if (m_trace)
	{
		top->trace(m_trace, 0);
	}
}

void memlog(const char *hdr, uint32_t addr, uint32_t wdata, uint8_t be, bool wr) {
	const char *d = wr ? "<=" : "=>";
	if (addr != memlog_addr || be != memlog_be || wdata != memlog_wdata) {
		printf("%s", hdr);
		switch (be) {
			case 0x1: { printf("[%07x].b%s      %02x", addr & ~3    ,d ,  wdata        &   0xff); break; }
			case 0x2: { printf("[%07x].b%s      %02x", addr & ~3 | 1,d , (wdata >>  8) &   0xff); break; }
			case 0x4: { printf("[%07x].b%s      %02x", addr & ~3 | 2,d , (wdata >> 16) &   0xff); break; }
			case 0x8: { printf("[%07x].b%s      %02x", addr & ~3 | 3,d , (wdata >> 24) &   0xff); break; }
			case 0x3: { printf("[%07x].h%s    %04x",   addr & ~3    ,d ,  wdata        & 0xffff); break; }
			case 0xc: { printf("[%07x].h%s    %04x",   addr & ~3 | 2,d , (wdata >> 16) & 0xffff); break; }
			case 0xf: { printf("[%07x]  %s%08x",       addr         ,d ,  wdata                ); break; }
			default: printf("  =%08x, bad be value %x", wdata, be); break;
		}
		printf(", PC=%07x", gba->cpu->rf);
		if (addr >> 24 == 4) {
			const char *name = register_name(addr);
			if (name) printf(", %s", name);
			else      printf(", UNKNOWN");
		}
		printf("\n");
		memlog_addr = addr;
		memlog_wdata = wdata;
		memlog_be = be;
		memlog_wr = wr;
	}
}

void memlog_acc(const char *hdr, uint32_t addr, uint32_t wdata, uint8_t acc, bool wr) {
	uint8_t be;
	if (acc == 0) {	// byte
		be = 1 << (addr & 3);
	} else if (acc == 1) {
		be = 3 << (addr & 2);
	} else if (acc == 2) {
		be = 0xf;
	} else
		printf("Bad acc %d\n", acc);
	memlog(hdr, addr, wdata, be, wr);
}

// return register name, or NULL if not a register
const char * register_name(uint32_t addr) {
	switch(addr) {
  		case 0x4000000:  return "DISPCNT"   ; 
  		case 0x4000004:  return "DISPSTAT"  ; 
  		case 0x4000006:  return "VCOUNT"    ; 
  		case 0x4000008:  return "BG0CNT"    ; 
  		case 0x400000A:  return "BG1CNT"    ; 
  		case 0x400000C:  return "BG2CNT"    ; 
  		case 0x400000E:  return "BG3CNT"    ; 
  		case 0x4000010:  return "BG0HOFS"   ; 
  		case 0x4000012:  return "BG0VOFS"   ; 
  		case 0x4000014:  return "BG1HOFS"   ; 
  		case 0x4000016:  return "BG1VOFS"   ; 
  		case 0x4000018:  return "BG2HOFS"   ; 
  		case 0x400001A:  return "BG2VOFS"   ; 
  		case 0x400001C:  return "BG3HOFS"   ; 
  		case 0x400001E:  return "BG3VOFS"   ; 
  		case 0x4000020:  return "BG2PA"     ; 
  		case 0x4000022:  return "BG2PB"     ; 
  		case 0x4000024:  return "BG2PC"     ; 
  		case 0x4000026:  return "BG2PD"     ; 
  		case 0x4000028:  return "BG2X"      ; 
  		case 0x400002C:  return "BG2Y"      ; 
  		case 0x4000030:  return "BG3PA"     ; 
  		case 0x4000032:  return "BG3PB"     ; 
  		case 0x4000034:  return "BG3PC"     ; 
  		case 0x4000036:  return "BG3PD"     ; 
  		case 0x4000038:  return "BG3X"      ; 
  		case 0x400003C:  return "BG3Y"      ; 
  		case 0x4000040:  return "WIN0H"     ; 
  		case 0x4000042:  return "WIN1H"     ; 
  		case 0x4000044:  return "WIN0V"     ; 
  		case 0x4000046:  return "WIN1V"     ; 
  		case 0x4000048:  return "WININ"     ; 
  		case 0x400004A:  return "WINOUT"    ; 
  		case 0x400004C:  return "MOSAIC"    ; 
  		case 0x4000050:  return "BLDCNT"    ; 
  		case 0x4000052:  return "BLDALPHA"  ; 
  		case 0x4000054:  return "BLDY"      ; 
  		case 0x4000060:  return "UND1CNT_L" ; 
  		case 0x4000062:  return "UND1CNT_H" ; 
  		case 0x4000064:  return "UND1CNT_X" ; 
  		case 0x4000068:  return "UND2CNT_L" ; 
  		case 0x400006C:  return "UND2CNT_H" ; 
  		case 0x4000070:  return "UND3CNT_L" ; 
  		case 0x4000072:  return "UND3CNT_H" ; 
  		case 0x4000074:  return "UND3CNT_X" ; 
  		case 0x4000078:  return "UND4CNT_L" ; 
  		case 0x400007C:  return "UND4CNT_H" ; 
  		case 0x4000080:  return "UNDCNT_L"  ; 
  		case 0x4000082:  return "UNDCNT_H"  ; 
  		case 0x4000084:  return "UNDCNT_X"  ; 
  		case 0x4000088:  return "UNDBIAS"   ; 
  		case 0x4000090:  return "WAVE_RAM"  ; 
  		case 0x40000A0:  return "FIFO_A"    ; 
  		case 0x40000A4:  return "FIFO_B"    ; 
  		case 0x40000B0:  return "DMA0SAD"   ; 
  		case 0x40000B4:  return "DMA0DAD"   ; 
  		case 0x40000B8:  return "DMA0CNT_L" ; 
  		case 0x40000BA:  return "DMA0CNT_H" ; 
  		case 0x40000BC:  return "DMA1SAD"   ; 
  		case 0x40000C0:  return "DMA1DAD"   ; 
  		case 0x40000C4:  return "DMA1CNT_L" ; 
  		case 0x40000C6:  return "DMA1CNT_H" ; 
  		case 0x40000C8:  return "DMA2SAD"   ; 
  		case 0x40000CC:  return "DMA2DAD"   ; 
  		case 0x40000D0:  return "DMA2CNT_L" ; 
  		case 0x40000D2:  return "DMA2CNT_H" ; 
  		case 0x40000D4:  return "DMA3SAD"   ; 
  		case 0x40000D8:  return "DMA3DAD"   ; 
  		case 0x40000DC:  return "DMA3CNT_L" ; 
  		case 0x40000DE:  return "DMA3CNT_H" ; 
  		case 0x4000100:  return "TM0CNT_L"  ; 
  		case 0x4000102:  return "TM0CNT_H"  ; 
  		case 0x4000104:  return "TM1CNT_L"  ; 
  		case 0x4000106:  return "TM1CNT_H"  ; 
  		case 0x4000108:  return "TM2CNT_L"  ; 
  		case 0x400010A:  return "TM2CNT_H"  ; 
  		case 0x400010C:  return "TM3CNT_L"  ; 
  		case 0x400010E:  return "TM3CNT_H"  ; 
  		case 0x4000120:  return "SIODATA32" ; 
  		// case 0x4000120:  return "SIOMULTI0" ; 
  		case 0x4000122:  return "SIOMULTI1" ; 
  		case 0x4000124:  return "SIOMULTI2" ; 
  		case 0x4000126:  return "SIOMULTI3" ; 
  		case 0x4000128:  return "SIOCNT"    ; 
  		case 0x400012A:  return "SIOMLT_SEND";
  		// case 0x400012A:  return "SIODATA8"  ; 
  		case 0x4000130:  return "KEYINPUT"  ; 
  		case 0x4000132:  return "KEYCNT"    ; 
  		case 0x4000134:  return "RCNT"      ; 
  		case 0x4000136:  return "IR"        ; 
  		case 0x4000140:  return "JOYCNT"    ; 
  		case 0x4000150:  return "JOY_RECV"  ; 
  		case 0x4000154:  return "JOY_TRANS" ; 
  		case 0x4000158:  return "JOYSTAT"   ; 
  		case 0x4000200:  return "IE"        ; 
  		case 0x4000202:  return "IF"        ; 
  		case 0x4000204:  return "WAITCNT"   ; 
  		case 0x4000208:  return "IME"       ; 
  		case 0x4000300:  return "POSTFLG"   ; 
  		case 0x4000301:  return "HALTCNT"   ; 
		default: 		 return 0;
	}
}
