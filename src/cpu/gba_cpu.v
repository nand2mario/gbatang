// From: https://github.com/risclite/ARM9-compatible-soft-CPU-core
// Thumb support added by nand2mario, July 2024
//
// Overview of the GBA cpu core:
//
// 1. This is a modified 3-stage pipeline design, optimized for FPGAs in the sense that it makes
// good use of the FPGA's multiplier hardware block. Instead of the original "fetch-decode-execute"
// design, the execution stage is split into two, with the muliplication operation done in the second
// stage. This allows better timing as the original execution stage is the obvious bottleneck,
// while at the same time keeping most of the simplicity of the 3-stage pipeline.
//
// 2. The overall structure, along with major signals, are as follows,
//
//    fetch            decode/multiply        execute/addition
//    --------------------------------------------------------
//                     code_flag              cmd_flag
//                                            cmd_ok
//
//    rom_addr  -->    code (rom_data)  -->   cmd
//                     code_is_b              cmd_is_b
//                     code_is_dp0            cmd_is_dp0
//                     ...                    ...
//
//                     Rm -> +---------+
//                           |   MULT  | -->  operand2 --> +---------+
//                     Rs -> +---------+                   |   ADD   | -->  result
//                                            Rn       --> +---------+
//                                           
//    - All signals named code_* belong to the "decode/multiply" stage. `code_flag` marks the validity of
//      the current instruction. `code_is_b` indicates that the instruction is a `branch` instruction.
//    - All signals named cmd_* belong to the "execute/addition" stage，with `cmd_flag` marking validity.
//      In addition, `cmd_ok` indicates whether conditional execution is met.
//    - One clever design point is the multiplier doubles as a shifter, with Rs set as:
//      code_rs = 1'b1 << code_rot_num
// 
// 3. The above diagram is missing the RAM access path. The core uses separate instruction (ROM) and
// data (RAM) memory buses (this is referred to as Harvard Architecture). The buses could be active
// in the same cycle. So in the case when there's only one memory module, like in our case, memory
// accesses need to be multiplexed to two cycles. This is done by pausing the CPU (signal: cpu_en),
// controlled by the gba_memory module.
//
// 4. One complication of moving the multiplication earlier, is that this introduces hazards, as we 
// now need input data one cycle earlier. So for instances where we use the result of the last instruction,
// we need to stall the pipeline for one cycle (signal: wait_en).
//
// 5. The original design only supports 32-bit instructions. 16-bit instruction support was added with
// instruction-to-instruction decoding (the ThumbDecoder module). A few necessary modifications (e.g. 
// PC increment logic) were made to other parts of the core to make this work.
//

module gba_cpu (

input                clk,
input                cpu_en,
input                cpu_restart,
input                fiq,
input                irq,
input                ram_abort,
input      [31:0]    ram_rdata,
input                rom_abort,
input      [31:0]    rom_data,
input                rst,
    
output     [31:0]    ram_addr,
output               ram_cen,
output reg [3:0]     ram_flag,
output reg [31:0]    ram_wdata,
output               ram_wen,
output     [31:0]    rom_addr,
output               rom_en,
output               thumb

);

/******************************************************/
//register definition area
/******************************************************/
reg              add_flag;
reg              all_code;
reg    [3:0]     cha_num;
reg              cha_vld;
reg    [31:0]    cmd;
reg    [31:0]    cmd_addr;
reg              cmd_flag;
reg              code_abort;
reg              code_flag;
reg    [31:0]    code_rm;
reg    [31:0]    code_rma;
reg    [4:0]     code_rot_num;
reg    [31:0]    code_rs;
reg    [2:0]     code_rs_flag;
reg    [31:0]    code_rsa;
reg              code_und;
reg              cond_satisfy;
reg              cpsr_c, cpsr_f, cpsr_i, cpsr_n, cpsr_v, cpsr_z;
reg              cpsr_t;        // thumb flag
reg    [4:0]     cpsr_m;
reg    [31:0]    dp_ans;
reg              extra_num;
reg              fiq_flag;
reg    [31:0]    go_data;
reg    [5:0]     go_fmt;
reg    [3:0]     go_num;
reg              go_vld;
reg              hold_en_dly;
reg              irq_flag;
reg              ldm_change;
reg    [3:0]     ldm_num;
reg    [3:0]     ldm_sel;
reg              ldm_usr;
reg              ldm_vld;
reg              multl_extra_num;
reg    [31:0]    r0, r1, r2, r3, r4, r5, r6, r7;
reg    [31:0]    r8_fiq, r8_usr;
reg    [31:0]    r9_fiq, r9_usr;
reg    [31:0]    ra_fiq, ra_usr;
reg    [31:0]    rb_fiq, rb_usr;
reg    [31:0]    rc_fiq, rc_usr;
reg    [31:0]    rd, rd_abt, rd_fiq, rd_irq, rd_svc, rd_und, rd_usr;
reg    [31:0]    re, re_abt, re_fiq, re_irq, re_svc, re_und, re_usr;
reg    [63:0]    reg_ans;
reg    [31:0]    rf /* verilator public */;
reg              rm_msb;
reg    [31:0]    rn, rn_register, rna, rnb;
reg              rs_msb;
reg    [31:0]    sec_operand;
reg    [11:0]    spsr, spsr_abt, spsr_fiq, spsr_irq, spsr_svc, spsr_und;    // T N Z C V I F M[4:0]
reg    [4:0]     sum_m;
reg    [31:0]    to_data;
reg    [3:0]     to_num;
reg              basereg_in_list;       // LDM/STM: base register is in the register list

/******************************************************/
//wire definition area
/******************************************************/
wire   [31:0]    and_ans;
wire   [31:0]    bic_ans;
wire             bit_cy, bit_ov;
wire             cha_rf_vld;
wire             cmd_is_b, cmd_is_bx, cmd_is_dp0, cmd_is_dp1, cmd_is_dp2, cmd_is_ldm;
wire             cmd_is_ldr0, cmd_is_ldr1, cmd_is_ldrh0, cmd_is_ldrh1, cmd_is_ldrsb0;
wire             cmd_is_ldrsb1, cmd_is_ldrsh0, cmd_is_ldrsh1, cmd_is_mrs, cmd_is_msr0;
wire             cmd_is_msr1, cmd_is_mult, cmd_is_multl, cmd_is_multlx, cmd_is_swi, cmd_is_swp, cmd_is_swpx;
wire             cmd_ok;
wire   [4:0]     cmd_sum_m;
wire   [31:0]    code;
wire             code_is_b, code_is_bx, code_is_dp0, code_is_dp1, code_is_dp2, code_is_ldm;
wire             code_is_ldr0, code_is_ldr1, code_is_ldrh0, code_is_ldrh1, code_is_ldrsb0;
wire             code_is_ldrsb1, code_is_ldrsh0, code_is_ldrsh1, code_is_mrs, code_is_msr0;
wire             code_is_msr1, code_is_mult, code_is_multl, code_is_swi, code_is_swp;
wire   [3:0]     code_rm_num;
wire             code_rm_vld;
wire   [3:0]     code_rn_num;
wire             code_rn_vld;
wire   [3:0]     code_rnhi_num;
wire             code_rnhi_vld;
reg    [3:0]     code_stm_num;      // LDR then STM hazard: this is the first register to be stored
wire             code_stm_vld;
wire   [3:0]     code_rs_num;
wire             code_rs_vld;
wire   [4:0]     code_sum_m;
wire   [11:0]    cpsr;
wire   [1:0]     cy_high_bits;
wire   [31:0]    eor_ans;
wire             fiq_en;
wire             go_rf_vld;
wire             high_bit;
wire             hold_en;
wire             hold_en_rising;
wire             int_all;
wire             irq_en;
wire   [31:0]    ldm_data;
wire             ldm_rf_vld;
wire   [63:0]    mult_ans;
wire   [31:0]    or_ans;
wire   [31:0]    r8;
wire   [31:0]    r9;
wire   [31:0]    ra;
wire   [31:0]    rb;
wire   [31:0]    rc;
wire   [31:0]    rf_b;
wire   [31:0]    sum_middle;
wire   [31:0]    sum_rn_rm;
wire             to_rf_vld;
wire             to_vld;
wire             wait_en;

//////////////////////////////////////////////////
// nand2mario: added thumb support
//////////////////////////////////////////////////

wire [31:0] thumb_decoded_inst;
reg  thumb_addr;                // which half-word to decode
wire thumb_load_addr_fix;       // load address instruction fix
assign thumb = cpsr_t;
wire code_is_bll, code_is_blh;  // code is BLL / BLH 
reg  cmd_thumb, cmd_thumb_load_addr_fix;
reg cmd_is_bll, cmd_is_blh;

ThumbDecoder thumb_decoder (
    .CLK(clk), .nRESET(~rst), .CLKEN(cpu_en),
    .InstForDecode(rom_data), .HalfWordAddress(thumb_addr),   
    .ThumbDecoderEn(cpsr_t), .ExpandedInst(thumb_decoded_inst),
    .ThADR(thumb_load_addr_fix), .ThBLL(code_is_bll), .ThBLH(code_is_blh)
);

always @(posedge clk) begin
    if (cpu_en) begin
        if (rom_en)
            thumb_addr <= rom_addr[1];
    end
end

// cpsr_t is the thumb flag
always @ ( posedge clk or posedge rst )
if ( rst )
    cpsr_t <= 1'd0;
else if ( cpu_en ) begin
    if (cpu_restart | fiq_en | ram_abort | irq_en | rom_abort | 
            cmd_flag & ( code_abort|code_und|(cond_satisfy & cmd_is_swi)))
        cpsr_t <= 1'd0;                                 // arm mode for all exceptions
    else if ( cmd_ok) begin
        if (cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
            if ( cmd[20] & cmd[15:12]==4'hf  )          // movs pc, ...
                cpsr_t <= spsr[11];
        end else if ( cmd_is_msr0|cmd_is_msr1 ) begin   // msr cpsr_c, ...
            if ( ~cmd[22] & cmd[19] )
                cpsr_t <= sec_operand[5];
        end else if ( cmd_is_bx )                       // bx ...
            cpsr_t <= sum_rn_rm[0];     // for BX, sum_rn_rm is branch address 
    end
end

//////////////////////////////////////////////////
// end of thumb
//////////////////////////////////////////////////

assign code = thumb_decoded_inst; //rom_data;

assign code_is_b      = code[27:25]==3'b101;
assign code_is_bx     = {code[27:23],code[20],code[7],code[4]}==8'b00010001;
assign code_is_dp0    = code[27:25]==3'b0 & ~code[4] & (code[24:23]!=2'b10 | code[20]);	            // Op2 reg shifted by immediate
assign code_is_dp1    = code[27:25]==3'b0 & ~code[7] & code[4] & (code[24:23]!=2'b10 | code[20]);   // Op2 reg shifted by reg
assign code_is_dp2    = code[27:25]==3'b001 & (code[24:23]!=2'b10 | code[20]);                      // Op2 is immediate
assign code_is_ldm    = code[27:25]==3'b100;        // this is LDM/STM
assign code_is_ldr0   = code[27:25]==3'b010;
assign code_is_ldr1   = code[27:25]==3'b011;
assign code_is_ldrh0  = code[27:25]==3'b0 & code[7:4]==4'b1011 & ~code[22];
assign code_is_ldrh1  = code[27:25]==3'b0 & code[7:4]==4'b1011 & code[22];	
assign code_is_ldrsb0 = code[27:25]==3'b0 & code[7:4]==4'b1101 & ~code[22];
assign code_is_ldrsb1 = code[27:25]==3'b0 & code[7:4]==4'b1101 & code[22];		
assign code_is_ldrsh0 = code[27:25]==3'b0 & code[7:4]==4'b1111 & ~code[22];
assign code_is_ldrsh1 = code[27:25]==3'b0 & code[7:4]==4'b1111 & code[22];
assign code_is_mrs    = {code[27:23],code[21:20],code[7],code[4]}==9'b00010_0000;
assign code_is_msr0   = {code[27:23],code[21:20],code[7],code[4]}==9'b00010_1000;
assign code_is_msr1   = code[27:25]==3'b001 & code[24:23]==2'b10 & ~code[20];
assign code_is_mult   = code[27:25]==3'b0 & code[7:4]==4'b1001 & code[24:23]==2'b00;
assign code_is_multl  = code[27:25]==3'b0 & code[7:4]==4'b1001 & code[24:23]==2'b01;
assign code_is_swi    = code[27:25]==3'b111;
assign code_is_swp    = code[27:25]==3'b0 & code[7:4]==4'b1001 & code[24:23]==2'b10;

always @ ( code )
if ( code[27:25]==3'b0 )
    if ( ~code[4] )
	    if ( ( code[24:23]==2'b10 ) & ~code[20] )
            if ( ~code[21] )
                all_code = code[19:16]==4'hf & code[11:0] == 12'b0;
            else
                all_code = /*code[18:17] == 2'b0 &*/ code[15:12]==4'hf & code[11:4]==8'h0;  // MSR
        else
            all_code = code[24:23]!=2'b10 | code[20];
    else if ( ~code[7] )
        if ( code[24:20]==5'b10010 )
            all_code = code[19:4]==16'hfff1;
        else
            all_code = code[24:23]!=2'b10 | code[20];
    else if ( code[6:5]==2'b0 )
        if ( code[24:22]==3'b0 )
            all_code = 1'b1;
        else if ( code[24:23]==2'b01 )
            all_code = 1'b1;
        else if ( code[24:23]==2'b10 )
            all_code = code[21:20]==2'b0 & code[11:8]==4'b0;
        else
            all_code = 1'b0;
    else if ( code[6:5]==2'b01 )
        if ( ~code[22] )
            all_code = code[11:8]==4'b0;
        else
            all_code = 1'b1;
	else //if ( ( code[6:5]==2'b10 )|(code[6:5]==2'b11) )
	    if ( code[20] )
		    if ( ~code[22] )
			    all_code = code[11:8]==4'b0;
			else
			    all_code = 1'b1;
		else
		    all_code = 1'b0;
else if ( code[27:25]==3'b001 )
    if ( (code[24:23]==2'b10) & ~code[20] )
        all_code = code[21] & code[18:17]==2'b0 & code[15:12]==4'hf |       // MSR
                   code[22:21] == 2'b0;                                     // Tak and power of Juju: 0x030042A0
    else
	    all_code = code[24:23]!=2'b10 | code[20];
else if ( code[27:25]==3'b010 )
    all_code = 1'b1;
else if ( code[27:25]==3'b011 )
    all_code = ~code[4];
else if ( code[27:25]==3'b100 )
    all_code = 1'b1;
else if ( code[27:25]==3'b101 )
    all_code = 1'b1;
else if ( code[27:25]==3'b111 )
    all_code = code[24];
else 
    all_code = 1'b0;	

always @ ( code or r0 or r1 or r2 or r3 or r4 or r5 or r6 or r7 or r8 or r9 or ra or rb or rc or rd or re or rf )
case ( code[3:0] )
4'h0 : code_rma = r0;
4'h1 : code_rma = r1;	
4'h2 : code_rma = r2;
4'h3 : code_rma = r3;
4'h4 : code_rma = r4;
4'h5 : code_rma = r5;	
4'h6 : code_rma = r6;
4'h7 : code_rma = r7;	
4'h8 : code_rma = r8;
4'h9 : code_rma = r9;	
4'ha : code_rma = ra;
4'hb : code_rma = rb;
4'hc : code_rma = rc;
4'hd : code_rma = rd;	
4'he : code_rma = re;
// ARM7TDMA datasheet 4.5.5: If a register is used to specify the shift amount 
// the PC will be **12** bytes ahead.
// 4'hf : code_rma = rf + 3'b100;
4'hf : if (code_is_dp1) code_rma = rf + (thumb ? 4'd4 : 4'd8);   // a register is used to specify shift amount
       else             code_rma = rf + (thumb ? 3'd2 : 3'd4);   
endcase

assign code_sum_m = code[0]+code[1]+code[2]+code[3]+code[4]+code[5]+code[6]+code[7]+
                    code[8]+code[9]+code[10]+code[11]+code[12]+code[13]+code[14]+code[15];

always @ (cpsr_t or code_is_ldrh1 or code_is_ldrsb1 or code_is_ldrsh1 or code or code_is_b or code_is_ldm or code_sum_m or code_is_ldr0 or code_is_msr1 or code_is_dp2 or code_is_multl or code_rma or code_is_dp0 or code_is_dp1 or code_is_ldr1)
if ( code_is_ldrh1|code_is_ldrsb1|code_is_ldrsh1 )
   	code_rm = {code[11:8], code[3:0]};
else if (code_is_b)	
    code_rm = cpsr_t ? {{7{code[23]}}, code[23:0], 1'b0} :  // thumb B/BLL/BLH, the imm24 contains offset in half-words
              {{6{code[23]}}, code[23:0], 2'b0};            // arm B/BL, imm24 contains offset in words
else if (code_is_ldm)
    case (code[24:23])
    2'd0 : code_rm = {(code_sum_m - 1'b1), 2'b0};
    2'd1 : code_rm = 0;
	2'd2 : code_rm = {code_sum_m, 2'b0};
	2'd3 : code_rm = 3'b100;
	endcase
else if (code_is_ldr0)
    code_rm = code[11:0];	
else if (code_is_msr1 | code_is_dp2)
    code_rm = code[7:0];
else if (code_is_multl & code[22] & code_rma[31])
    code_rm = ~code_rma + 1'b1;
else if ((code[6:5] == 2'b10 & code_rma[31]) & (code_is_dp0 | code_is_dp1 | code_is_ldr1))
    code_rm = ~code_rma;
else
    code_rm = code_rma;

always @ ( code or r0 or r1 or r2 or r3 or r4 or r5 or r6 or r7 or r8 or r9 or ra or rb or rc or rd or re or rf )
case ( code[11:8] )
4'h0 : code_rsa = r0;
4'h1 : code_rsa = r1;	
4'h2 : code_rsa = r2;
4'h3 : code_rsa = r3;
4'h4 : code_rsa = r4;
4'h5 : code_rsa = r5;	
4'h6 : code_rsa = r6;
4'h7 : code_rsa = r7;	
4'h8 : code_rsa = r8;
4'h9 : code_rsa = r9;	
4'ha : code_rsa = ra;
4'hb : code_rsa = rb;
4'hc : code_rsa = rc;
4'hd : code_rsa = rd;	
4'he : code_rsa = re;
// same as code_rma (datasheet 4.5.5)
// 4'hf : code_rsa = rf + 3'b100;
4'hf : if (code_is_dp1) code_rsa = rf + (thumb ? 4'd4 : 4'd8);   // a register is used to specify shift amount
       else             code_rsa = rf + (thumb ? 4'd2 : 4'd4);
endcase	 

always @ ( code_is_dp0 or code_is_ldr1 or code or code_is_dp1 or code_rsa or code_is_msr1 or code_is_dp2 )
if (code_is_dp0 | code_is_ldr1)
    code_rot_num = code[6:5] == 2'b00 ? code[11:7] : ~code[11:7]+1'b1;
else if (code_is_dp1)
    code_rot_num = code[6:5] == 2'b00 ? code_rsa[4:0] : ~code_rsa[4:0]+1'b1;
else if (code_is_msr1|code_is_dp2)
    code_rot_num = {~code[11:8]+1'b1, 1'b0};
else
    code_rot_num = 5'b0;

always @ ( code_is_multl or code or code_rsa or code_is_mult or code_rot_num )
if ( code_is_multl )
    if ( code[22] & code_rsa[31] )
	    code_rs = ~code_rsa + 1'b1;
	else
	    code_rs = code_rsa;
else if ( code_is_mult )
    code_rs = code_rsa;
else begin
    code_rs = 32'b0;
	code_rs[code_rot_num] = 1'b1;
end
	
assign mult_ans = code_rm * code_rs;	

assign code_rm_vld = code_flag & (code_is_msr0|code_is_dp0|code_is_bx|code_is_dp1|code_is_mult|
                code_is_multl|code_is_swp|code_is_ldrh0|code_is_ldrsb0|code_is_ldrsh0|code_is_ldr1);
assign code_rm_num = code[3:0];
assign code_rs_vld = code_flag & (code_is_dp1|code_is_mult|code_is_multl);
assign code_rs_num = code[11:8];
assign code_rn_vld = code_flag & (code_is_dp0|code_is_dp1|code_is_multl|code_is_swp|code_is_ldrh0|
                code_is_ldrh1|code_is_ldrsb0|code_is_ldrsb1|code_is_ldrsh0|code_is_ldrsh1|code_is_dp2|
                code_is_ldr0|code_is_ldr1|code_is_ldm);
assign code_rn_num = code[19:16];
assign code_rnhi_vld = code_flag & ( code_is_mult|code_is_multl| ((code_is_ldrh0|code_is_ldrh1|
                code_is_ldr0|code_is_ldr1) & ~code[20]) );
assign code_rnhi_num = code[15:12];	
assign code_stm_vld = code_flag & code_is_ldm & ~code[20];      // STM instruction

always @(code) begin
    // this is a bit faster thank cascading if-else
    casez(code[15:0])
    16'b????_????_????_???1:  code_stm_num = 0;
    16'b????_????_????_??10:  code_stm_num = 1;
    16'b????_????_????_?100:  code_stm_num = 2;
    16'b????_????_????_1000:  code_stm_num = 3;
    16'b????_????_???1_0000:  code_stm_num = 4;
    16'b????_????_??10_0000:  code_stm_num = 5;
    16'b????_????_?100_0000:  code_stm_num = 6;
    16'b????_????_1000_0000:  code_stm_num = 7;
    16'b????_???1_0000_0000:  code_stm_num = 8;
    16'b????_??10_0000_0000:  code_stm_num = 9;
    16'b????_?100_0000_0000:  code_stm_num = 10;
    16'b????_1000_0000_0000:  code_stm_num = 11;
    16'b???1_0000_0000_0000:  code_stm_num = 12;
    16'b??10_0000_0000_0000:  code_stm_num = 13;
    16'b?100_0000_0000_0000:  code_stm_num = 14;
    default:                  code_stm_num = 15;
    endcase
end

always @(posedge clk)
if ( rst )
    sum_m <= 5'd0;
else if ( cpu_en )
    if ( ~hold_en )
	    sum_m <= code_sum_m;

always @(posedge clk)
if ( rst )
    reg_ans <= 64'd0;
else if ( cpu_en )
    if ( ~hold_en )
	    reg_ans <= mult_ans;
	else if ( cmd_is_ldm ) begin
	    if ( cmd_sum_m==5'b1 )
		    reg_ans[6:2] <= sum_m;	
	    else if ( cmd[23] )
		    reg_ans[6:2] <= reg_ans[6:2] + 1'b1;
		else
		    reg_ans[6:2] <= reg_ans[6:2] - 1'b1;
    end

always @(posedge clk)
if ( rst )
    code_rs_flag <= 3'd0;
else if ( cpu_en )
    if ( ~hold_en ) begin
	    if ( code_is_dp1 )
		    code_rs_flag <= {(code_rsa[7:0]>6'd32),(code_rsa[7:0]==6'd32),(code_rsa[7:0]==8'd0)};
		else
		    code_rs_flag <= 0;
    end

always @(posedge clk)
if ( rst )
    rm_msb <= 1'd0;
else if ( cpu_en )
    if ( ~hold_en )
        rm_msb <= code_rma[31];

always @(posedge clk)
if ( rst )
    rs_msb <= 1'd0;
else if ( cpu_en )
    if ( ~hold_en )
        rs_msb <= code_rsa[31];

always @(posedge clk)
if ( rst )
    code_abort <= 1'd0;
else if ( cpu_en )
    if ( ~hold_en )
	    code_abort <= rom_abort;

always @(posedge clk)
if ( rst )
    code_und <= 1'd0;
else if ( cpu_en )
    if ( ~hold_en )
	    code_und <= ~all_code;

always @(posedge clk)
if ( rst )
    cmd <= 32'd0;
else if ( cpu_en )
    if ( ~hold_en ) begin
	    cmd <= code;
        cmd_thumb <= thumb;
        cmd_thumb_load_addr_fix <= thumb_load_addr_fix;
        cmd_is_bll <= thumb & code_is_bll;
        cmd_is_blh <= thumb & code_is_blh;
        if (code_is_ldm & code[15:0] == 16'b0)     // emtpy ldm rlist equals {PC}
            cmd[15] <= 1'b1;
    end else if ( cmd_is_swp ) begin
	    cmd[27:25] <= 3'b110;
		cmd[15:12] <= cmd[3:0];
	end	else if ( cmd_is_multl )
	    cmd[27:25] <= 3'b110;	   
    else if ( cmd_is_ldm ) begin
	    cmd[0] <= 1'b0;
		cmd[1] <= cmd[0] ? cmd[1] : 1'b0;
		cmd[2] <= (|(cmd[1:0])) ? cmd[2] : 1'b0;
		cmd[3] <= (|(cmd[2:0])) ? cmd[3] : 1'b0;		
		cmd[4] <= (|(cmd[3:0])) ? cmd[4] : 1'b0;
		cmd[5] <= (|(cmd[4:0])) ? cmd[5] : 1'b0;	
		cmd[6] <= (|(cmd[5:0])) ? cmd[6] : 1'b0;
		cmd[7] <= (|(cmd[6:0])) ? cmd[7] : 1'b0;		
		cmd[8] <= (|(cmd[7:0])) ? cmd[8] : 1'b0;
		cmd[9] <= (|(cmd[8:0])) ? cmd[9] : 1'b0;	
		cmd[10] <= (|(cmd[9:0])) ? cmd[10] : 1'b0;	
		cmd[11] <= (|(cmd[10:0])) ? cmd[11] : 1'b0;	    
		cmd[12] <= (|(cmd[11:0])) ? cmd[12] : 1'b0;	 
		cmd[13] <= (|(cmd[12:0])) ? cmd[13] : 1'b0;	
		cmd[14] <= (|(cmd[13:0])) ? cmd[14] : 1'b0;	 
		cmd[15] <= (|(cmd[14:0])) ? cmd[15] : 1'b0;	 		
    end	

always @(posedge clk)
if (rst)
    basereg_in_list <= 0;
else begin
    if (cpu_en & ~hold_en & code_is_ldm) 
        basereg_in_list <= code[code[19:16]];
end

assign cmd_is_b      = cmd[27:25]==3'b101;
assign cmd_is_bx     = {cmd[27:23],cmd[20],cmd[7],cmd[4]}==8'b00010001;
assign cmd_is_dp0    = cmd[27:25]==3'b0 & ~cmd[4] & (cmd[24:23]!=2'b10 | cmd[20]);	
assign cmd_is_dp1    = cmd[27:25]==3'b0 & ~cmd[7] & cmd[4] & (cmd[24:23]!=2'b10 | cmd[20]);
assign cmd_is_dp2    = cmd[27:25]==3'b001 & (cmd[24:23]!=2'b10 | cmd[20]);
assign cmd_is_ldm    = cmd[27:25]==3'b100;
assign cmd_is_ldr0   = cmd[27:25]==3'b010;          // single transfer with immediate offset
assign cmd_is_ldr1   = cmd[27:25]==3'b011;          // single transfer with register offset
assign cmd_is_ldrh0  = cmd[27:25]==3'b0 & cmd[7:4]==4'b1011 & ~cmd[22];
assign cmd_is_ldrh1  = cmd[27:25]==3'b0 & cmd[7:4]==4'b1011 & cmd[22];	
assign cmd_is_ldrsb0 = cmd[27:25]==3'b0 & cmd[7:4]==4'b1101 & ~cmd[22];
assign cmd_is_ldrsb1 = cmd[27:25]==3'b0 & cmd[7:4]==4'b1101 & cmd[22];		
assign cmd_is_ldrsh0 = cmd[27:25]==3'b0 & cmd[7:4]==4'b1111 & ~cmd[22];
assign cmd_is_ldrsh1 = cmd[27:25]==3'b0 & cmd[7:4]==4'b1111 & cmd[22];	
assign cmd_is_mrs    = {cmd[27:23],cmd[21:20],cmd[7],cmd[4]}==9'b000100000;
assign cmd_is_msr0   = {cmd[27:23],cmd[21:20],cmd[7],cmd[4]}==9'b000101000;
assign cmd_is_msr1   = cmd[27:25]==3'b001 & cmd[24:23]==2'b10 & ~cmd[20];
assign cmd_is_mult   = cmd[27:25]==3'b0 & cmd[7:4]==4'b1001 & cmd[24:23]==2'b00;
assign cmd_is_multl  = cmd[27:25]==3'b0 & cmd[7:4]==4'b1001 & cmd[24:23]==2'b01;	
assign cmd_is_multlx = cmd[27:24]==4'b1100;
assign cmd_is_swi    = cmd[27:25]==3'b111;
assign cmd_is_swp    = cmd[27:25]==3'b0 & cmd[7:4]==4'b1001 & cmd[24:23]==2'b10;	
assign cmd_is_swpx   = cmd[27:24]==4'b1101;

always @ ( cmd_is_dp0 or cmd_is_ldr1 or reg_ans or rm_msb or cmd or cpsr_c or cmd_is_dp1 or code_rs_flag or cmd_is_msr1 or cmd_is_dp2 or cmd_is_multlx )
if ( cmd_is_dp0|cmd_is_ldr1 )
    case(cmd[6:5])
	2'b00 : sec_operand = reg_ans[31:0];
	2'b01 : sec_operand = reg_ans[63:32];
	2'b10 : sec_operand = rm_msb ? ~reg_ans[63:32] : reg_ans[63:32];
    2'b11 : sec_operand = cmd[11:7] == 5'b0 ? {cpsr_c, reg_ans[31:1]} : 
                          reg_ans[63:32] | reg_ans[31:0];
	endcase
else if ( cmd_is_dp1 )
    case(cmd[6:5])
	2'b00 : sec_operand = code_rs_flag[2:1] != 2'b0 ? 32'b0: reg_ans[31:0];
	2'b01 : sec_operand = code_rs_flag[2:1] != 2'b0 ? 32'b0: 
                          code_rs_flag[0] ? reg_ans[31:0] : 
                          reg_ans[63:32];
	2'b10 : sec_operand = code_rs_flag[2:1]!=2'b0 ? {32{rm_msb}} : 
                          code_rs_flag[0] ? (rm_msb ? ~reg_ans[31:0] : reg_ans[31:0]) : 
                          rm_msb ? ~reg_ans[63:32] :
                          reg_ans[63:32];
	2'b11 : sec_operand = code_rs_flag[1] | code_rs_flag[0] ? reg_ans[31:0] : 
                          reg_ans[63:32] | reg_ans[31:0];
	endcase
else if ( cmd_is_msr1 | cmd_is_dp2 )
    sec_operand = reg_ans[63:32] | reg_ans[31:0];
else if ( cmd_is_multlx )
    sec_operand = reg_ans[63:32];
else 
	sec_operand = reg_ans[31:0];	


always @ ( cmd or r0 or r1 or r2 or r3 or r4 or r5 or r6 or r7 or r8 or r9 or ra or rb or rc or rd or re or rf )
case ( cmd[15:12] )
4'h0 : rna = r0;
4'h1 : rna = r1;	
4'h2 : rna = r2;
4'h3 : rna = r3;
4'h4 : rna = r4;
4'h5 : rna = r5;	
4'h6 : rna = r6;
4'h7 : rna = r7;	
4'h8 : rna = r8;
4'h9 : rna = r9;	
4'ha : rna = ra;
4'hb : rna = rb;
4'hc : rna = rc;
4'hd : rna = rd;	
4'he : rna = re;
// 4'hf : rna = rf;
4'hf : if (  cmd_is_dp1     // a register is used to specify shift amount
           | cmd[27:26] == 2'b01 & ~cmd[20])    // STR r15 into memory (datasheet 4.9.4)
           rna = rf + (thumb ? 3'd2 : 3'd4);
       else                   
           rna = rf;
endcase	

always @ ( cmd or r0 or r1 or r2 or r3 or r4 or r5 or r6 or r7 or r8 or r9 or ra or rb or rc or rd or re or rf ) begin
    case ( cmd[19:16] )
    4'h0 : rnb = r0;
    4'h1 : rnb = r1;	
    4'h2 : rnb = r2;
    4'h3 : rnb = r3;
    4'h4 : rnb = r4;
    4'h5 : rnb = r5;	
    4'h6 : rnb = r6;
    4'h7 : rnb = r7;	
    4'h8 : rnb = r8;
    4'h9 : rnb = r9;	
    4'ha : rnb = ra;
    4'hb : rnb = rb;
    4'hc : rnb = rc;
    4'hd : rnb = rd;	
    4'he : rnb = re;
    4'hf : begin
        if (cmd_is_dp1)                     // operand2 is a shifted register
            rnb = rf + (thumb ? 3'd2 : 3'd4);
        else if (cmd_thumb_load_addr_fix)   // thumb load address instruction, PC must be word-aligned
            rnb = {rf[31:2], 2'b0};
        else
            rnb = rf;
    end
    endcase	 	
end

always @(posedge clk)
if ( rst )
    hold_en_dly <= 1'd0;
else if ( cpu_en )
    hold_en_dly <= hold_en;

assign hold_en_rising = hold_en & ~hold_en_dly;

always @(posedge clk)
if ( rst )
    rn_register <= 32'd0;
else if ( cpu_en )
    if ( hold_en_rising )
	    rn_register <= rnb;


always @*
if (cmd_is_bx | (cmd_is_multlx & ~cmd[21]) |
  ((cmd_is_dp0 | cmd_is_dp1 | cmd_is_dp2) & (cmd[24:21] == 4'b1101 | cmd[24:21]==4'b1111)))
    rn = 0;
else if ( cmd_is_mult | cmd_is_multl )
    if ( cmd[21] )
        rn = rna;
	else
	    rn = 0;
else if ( cmd_is_b ) begin
    if (thumb & cmd_is_blh)
        rn = re;            // BLH jumps to LR + offset
    else
        rn = rf;            // all other B/BL jumps to PC + offset
end else if ( hold_en & hold_en_dly )
    rn = rn_register;
else
    rn = rnb;


always @ ( cmd_is_mult or cmd_is_b or cmd_is_bx or cmd_is_multl or cmd_is_multlx or cmd or rm_msb or rs_msb or cmd_is_dp0 or cmd_is_dp1 or cmd_is_dp2  )
if ( cmd_is_mult|cmd_is_b|cmd_is_bx )
    add_flag = 1'b1;
else if ( cmd_is_multl|cmd_is_multlx )
    add_flag = cmd[22] ? ~( rm_msb^rs_msb ) : 1'b1;
else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 )
    add_flag = (cmd[24:21]==4'b0100) | (cmd[24:21]==4'b0101) | (cmd[24:21]==4'b1011) | 
                (cmd[24:21]==4'b1101);
else
    add_flag = cmd[23];
	
always @(posedge clk)
if ( rst )
    multl_extra_num <= 1'd0;
else if ( cpu_en )
    if ( cmd_ok & cmd_is_multl )
        multl_extra_num <= bit_cy;
    else
        multl_extra_num <= 0;
		

always @ ( cmd_is_mult or cmd_is_multl or cmd_is_dp0 or cmd_is_dp1 or cmd_is_dp2 or cmd or cpsr_c or cmd_is_multlx or multl_extra_num )
if ( cmd_is_mult | cmd_is_multl )
    extra_num = 1'b0;
else if ( cmd_is_dp0 | cmd_is_dp1 | cmd_is_dp2 )
    case ( cmd[24:21])
	4'b0010 : extra_num = 1'b0;
    4'b0011 : extra_num = 1'b1;
    4'b0100 : extra_num = 1'b0;
    4'b0101 : extra_num = cpsr_c;
    4'b0110 : extra_num = ~cpsr_c;
    4'b0111 : extra_num = cpsr_c;
	4'b1111 : extra_num = 1'b1;
    default: extra_num = 1'b0;
    endcase
else if ( cmd_is_multlx )
    extra_num = multl_extra_num;
else
    extra_num = 1'b0;

assign sum_middle   = add_flag ? rn[30:0] + sec_operand[30:0] + extra_num : 
                        rn[30:0] - sec_operand[30:0] - extra_num;	
assign cy_high_bits = add_flag ? rn[31] + sec_operand[31] + sum_middle[31] : 
                        rn[31] - sec_operand[31] - sum_middle[31];
assign bit_cy       = cy_high_bits[1];
assign high_bit     = cy_high_bits[0];	
assign bit_ov       = bit_cy ^ sum_middle[31];		
assign sum_rn_rm    = {high_bit,sum_middle[30:0]};

assign and_ans = rn & sec_operand;
assign eor_ans = rn ^ sec_operand;
assign or_ans  = rn | sec_operand;
assign bic_ans = rn & ~sec_operand;

always @ ( cmd or and_ans or eor_ans or sum_rn_rm or or_ans or bic_ans )
case ( cmd[24:21] )
4'h0 : dp_ans = and_ans;
4'h1 : dp_ans = eor_ans;
4'h2 : dp_ans = sum_rn_rm;
4'h3 : dp_ans = ~sum_rn_rm;
4'h4 : dp_ans = sum_rn_rm;
4'h5 : dp_ans = sum_rn_rm;
4'h6 : dp_ans = sum_rn_rm;
4'h7 : dp_ans = ~sum_rn_rm;
4'h8 : dp_ans = and_ans;
4'h9 : dp_ans = eor_ans;
4'ha : dp_ans = sum_rn_rm;
4'hb : dp_ans = sum_rn_rm;
4'hc : dp_ans = or_ans;
4'hd : dp_ans = sum_rn_rm;
4'he : dp_ans = bic_ans;
4'hf : dp_ans = sum_rn_rm;
endcase
	
always @(posedge clk)
if ( rst )
    code_flag <= 1'd0;
else if ( cpu_en )
    if ( int_all | to_rf_vld | cha_rf_vld | go_rf_vld | ldm_rf_vld )
	    code_flag <= 0;
	else
	    code_flag <= 1;
	
always @(posedge clk)
if ( rst )
    cmd_flag <= 1'd0;
else if ( cpu_en )
    if ( int_all )
	    cmd_flag <= 0;
	else if ( ~hold_en )
	    if ( wait_en | to_rf_vld | cha_rf_vld | go_rf_vld )
		    cmd_flag <= 0;
		else
		    cmd_flag <= code_flag;
	
always @*
case ( cmd[31:28] )
4'h0 : cond_satisfy = cpsr_z==1'b1;
4'h1 : cond_satisfy = cpsr_z==1'b0;
4'h2 : cond_satisfy = cpsr_c==1'b1;
4'h3 : cond_satisfy = cpsr_c==1'b0;
4'h4 : cond_satisfy = cpsr_n==1'b1;
4'h5 : cond_satisfy = cpsr_n==1'b0;
4'h6 : cond_satisfy = cpsr_v==1'b1;
4'h7 : cond_satisfy = cpsr_v==1'b0;
4'h8 : cond_satisfy = cpsr_c==1'b1 & cpsr_z==1'b0;
4'h9 : cond_satisfy = cpsr_c==1'b0 | cpsr_z==1'b1;
4'ha : cond_satisfy = cpsr_n==cpsr_v;
4'hb : cond_satisfy = cpsr_n!=cpsr_v;
4'hc : cond_satisfy = cpsr_z==1'b0 & cpsr_n==cpsr_v;
4'hd : cond_satisfy = cpsr_z==1'b1 | cpsr_n!=cpsr_v;
4'he : cond_satisfy = 1'b1;
4'hf : cond_satisfy = 1'b0;
endcase

assign cmd_ok = ~int_all & cmd_flag & cond_satisfy;	
	
assign cmd_sum_m = cmd[0]+cmd[1]+cmd[2]+cmd[3]+cmd[4]+cmd[5]+cmd[6]+cmd[7]+
                   cmd[8]+cmd[9]+cmd[10]+cmd[11]+cmd[12]+cmd[13]+cmd[14]+cmd[15];

assign hold_en = cmd_ok & ( cmd_is_swp | cmd_is_multl | ( cmd_is_ldm & (cmd_sum_m !=5'b0) ) );


always @(posedge clk)
if ( rst )
    irq_flag <= 1'b0;
else if ( cpu_en )
    // if ( irq & (~thumb | ~thumb_bl_fix))        // do not interrupt thumb BL
    // if (irq)
    if (irq & ~hold_en)         // nand2mario: do not interrupt LDM or SWP (doom)
        irq_flag <= 1'b1;
    else if ( cmd_flag )
        irq_flag <= 1'b0;


always @(posedge clk)
if ( rst )
    fiq_flag <= 1'b0;
else if ( cpu_en )
	if ( fiq )
	     fiq_flag <= 1'b1;
    else if ( cmd_flag )
	   fiq_flag <= 1'b0;

assign irq_en = irq_flag & cmd_flag & ~cpsr_i;
assign fiq_en = fiq_flag & cmd_flag & ~cpsr_f;

assign int_all = cpu_restart|ram_abort|fiq_en|irq_en|( cmd_flag & ( code_abort|code_und|(cond_satisfy & cmd_is_swi)));

always @(posedge clk)
if ( rst )
    ldm_change <= 1'd0;
else if ( cpu_en )
    if ( ~hold_en )
	    ldm_change <= code[22] & code[20] & code[15];

always @(posedge clk)
if ( rst )
    cpsr_n <= 1'd0;
else if ( cpu_en )
    if ( cmd_ok )
	    if ( cmd_is_msr0|cmd_is_msr1 ) begin
		    if ( ~cmd[22] & cmd[19] )
                cpsr_n <= sec_operand[31];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
		    if ( cmd[20] )
			    if ( cmd[15:12]==4'hf )
				    cpsr_n <= spsr[10];
				else 
				    cpsr_n <= dp_ans[31];
        end else if ( cmd_is_mult|cmd_is_multlx|cmd_is_multl ) begin
		    if ( cmd[20] )
			    cpsr_n <= sum_rn_rm[31];
        end else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_n <= spsr[10];

always @(posedge clk)
if ( rst )
    cpsr_z <= 1'd0;
else if ( cpu_en )
    if ( cmd_ok )
	    if ( cmd_is_msr0|cmd_is_msr1 ) begin
		    if ( ~cmd[22] & cmd[19] )
                cpsr_z <= sec_operand[30];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
		    if ( cmd[20] )
			    if ( cmd[15:12]==4'hf )
				    cpsr_z <= spsr[9];
				else 
				    cpsr_z <= (dp_ans==32'b0);
        end else if ( cmd_is_mult|cmd_is_multl ) begin
		    if ( cmd[20] )
			    cpsr_z <= (sum_rn_rm==32'b0);
        end else if ( cmd_is_multlx & cmd[20] )
		    cpsr_z <= cpsr_z & (sum_rn_rm==32'b0);
		else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_z <= spsr[9];

always @(posedge clk)
if ( rst )
    cpsr_c <= 1'd0;
else if ( cpu_en ) begin
    if ( cmd_ok ) begin
        if ( cmd_is_msr0|cmd_is_msr1 ) begin
		    if ( ~cmd[22] & cmd[19] )
                cpsr_c <= sec_operand[29];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 )
            if ( cmd[20] ) begin
                if ( cmd[15:12]==4'hf )
                    cpsr_c <= spsr[8];
                else if ( (cmd[24:21]==4'b1011)|(cmd[24:21]==4'b0100)|(cmd[24:21]==4'b0101)|
                          (cmd[24:21]==4'b0011)|(cmd[24:21]==4'b0111) )        // additions
				    cpsr_c <= bit_cy;
				else if ( (cmd[24:21]==4'b1010)|(cmd[24:21]==4'b0010)|(cmd[24:21]==4'b0110) )   // subtractions
				    cpsr_c <= ~bit_cy;
				else if ( cmd_is_dp1 & ~code_rs_flag[0] )       // shift operations
				    case ( cmd[6:5] )                           // shift type
				    2'b00 : cpsr_c <= code_rs_flag[2]   ? 1'b0 : 
                            code_rs_flag[1]             ? reg_ans[0] : reg_ans[32];
					2'b01 : cpsr_c <= code_rs_flag[2]   ? 1'b0 : 
                            code_rs_flag[1]             ? reg_ans[31] : reg_ans[31];
					2'b10 : cpsr_c <= code_rs_flag[2]   ? rm_msb : 
                            code_rs_flag[1]             ? rm_msb : 
                            rm_msb                      ? ~reg_ans[31] : reg_ans[31];
					2'b11 : cpsr_c <= code_rs_flag[0]   ? cpsr_c : reg_ans[31];         // nand2mario: only ROR by 0 should not change the carry flag
					endcase	
                else if ( cmd_is_dp2 )
                    cpsr_c <= 	reg_ans[31];
				else if ( cmd_is_dp0 )  begin
				    case ( cmd[6:5] )
				    2'b00 : cpsr_c <= cmd[11:7]==5'b0 ? cpsr_c : reg_ans[32];
					2'b01 : cpsr_c <= reg_ans[31];
					2'b10 : cpsr_c <= rm_msb ? ~reg_ans[31] : reg_ans[31];
					2'b11 : cpsr_c <= cmd[11:7]==5'b0 ? reg_ans[0] : reg_ans[31];
					endcase
                end
            end
		else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change ) 
		     cpsr_c <= spsr[8];
	end
end

always @(posedge clk)
if ( rst )
    cpsr_v <= 1'd0;
else if ( cpu_en ) begin
    if ( cmd_ok ) begin
        if ( cmd_is_msr0|cmd_is_msr1 ) begin
		    if ( ~cmd[22] & cmd[19] )
                cpsr_v <= sec_operand[28];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
            if ( cmd[20] ) begin
                if ( cmd[15:12]==4'hf )
                    cpsr_v <= spsr[7];
                else if ( (cmd[24:21]==4'd2)|(cmd[24:21]==4'd3)|(cmd[24:21]==4'd4)|
                          (cmd[24:21]==4'd5)|(cmd[24:21]==4'd6)|(cmd[24:21]==4'd7)|
                          (cmd[24:21]==4'd10)|(cmd[24:21]==4'd11) )
                    cpsr_v <= bit_ov;
            end
        end else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_v <= spsr[7];
    end
end

always @(posedge clk)
if ( rst )
    cpsr_i <= 1'd0;
else if ( cpu_en ) begin
    if ( int_all )
        cpsr_i <= 1;
    else if ( cmd_ok & ( cpsr_m != 5'b10000 ) ) begin
        if ( cmd_is_msr0|cmd_is_msr1 ) begin
            if ( ~cmd[22] & cmd[16]  )
                cpsr_i <= sec_operand[7];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
            if ( cmd[20] )
                if 	( cmd[15:12]==4'hf )
                    cpsr_i <= spsr[6];
        end else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_i <= spsr[6];
    end
end

always @(posedge clk)
if ( rst )
    cpsr_f <= 1'd0;
else if ( cpu_en ) begin
    if ( cpu_restart | fiq_en ) 
        cpsr_f <= 1;
    else if ( cmd_ok & ( cpsr_m != 5'b10000 ) ) begin
        if ( cmd_is_msr0|cmd_is_msr1 ) begin
            if ( ~cmd[22] & cmd[16]  )
                cpsr_f <= sec_operand[6];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
            if ( cmd[20] )
                if 	( cmd[15:12]==4'hf )
                    cpsr_f <= spsr[5];
        end else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_f <= spsr[5];
    end
end

always @(posedge clk)
if ( rst )
    cpsr_m <= 5'b10011;
else if ( cpu_en ) begin
    if ( cpu_restart )
        cpsr_m <= 5'b10011;
    else if ( fiq_en )
        cpsr_m <= 5'b10001;
    else if ( ram_abort )
        cpsr_m <= 5'b10111;
    else if ( irq_en )
        cpsr_m <= 5'b10010;
    else if ( cmd_flag & code_abort )
        cpsr_m <= 5'b10111;
    else if ( cmd_flag & code_und )
        cpsr_m <= 5'b11011;
    else if ( cmd_flag & cond_satisfy & cmd_is_swi )
        cpsr_m <= 5'b10011; 
    else if ( cmd_ok & ( cpsr_m != 5'b10000 ) ) begin
        if ( cmd_is_msr0|cmd_is_msr1 ) begin
            if ( ~cmd[22] & cmd[16]  )
                cpsr_m <= sec_operand[4:0];
        end else if ( cmd_is_dp0|cmd_is_dp1|cmd_is_dp2 ) begin
            if ( cmd[20] )
                if 	( cmd[15:12]==4'hf )
                    cpsr_m <= spsr[4:0];
        end else if ( cmd_is_ldm & ( cmd_sum_m==5'b0 ) & ldm_change )
		     cpsr_m <= spsr[4:0];
    end
end   	

assign cpsr = {cpsr_t,cpsr_n,cpsr_z,cpsr_c,cpsr_v,cpsr_i,cpsr_f,cpsr_m};	

always @(posedge clk)
if ( rst )
    spsr_abt <= 11'd0;
else if ( cpu_en ) begin
    if ( ram_abort | ( ~fiq_en & ~irq_en & ( cmd_flag & code_abort ) ) )
	    spsr_abt <= cpsr;
    else if ( cmd_ok & ( cpsr_m==5'b10111) & ( cmd_is_msr0|cmd_is_msr1 ) & cmd[22] ) begin
        spsr_abt[10:0] <= {{cmd[19] ? sec_operand[31:28] : spsr_abt[10:7]},
                     {cmd[16] ? {sec_operand[7:6],sec_operand[4:0]} : spsr_abt[6:0]}}; 	
        spsr_abt[11] <= cmd[16] ? sec_operand[5] : spsr_abt[11];
    end
end

always @(posedge clk)
if ( rst )
    spsr_fiq <= 11'd0;
else if ( cpu_en ) begin
    if ( fiq_en ) begin
         if ( ram_abort )
            spsr_fiq <= {cpsr_n,cpsr_z,cpsr_c,cpsr_v,1'b1,cpsr_f,5'b10111};
        else 
            spsr_fiq <= cpsr;
    end else if ( cmd_ok & ( cpsr_m==5'b10001) & ( cmd_is_msr0|cmd_is_msr1 ) & cmd[22] ) begin
        spsr_fiq[10:0] <= {{cmd[19] ? sec_operand[31:28] : spsr_fiq[10:7]},
                     {cmd[16] ? {sec_operand[7:6], sec_operand[4:0]} : spsr_fiq[6:0]}}; 	
        spsr_fiq[11] <= cmd[16] ? sec_operand[5] : spsr_fiq[11];
    end
end

always @(posedge clk)
if ( rst )
    spsr_irq <= 11'd0;
else if ( cpu_en ) begin
    if ( ~ram_abort & ~fiq_en & irq_en )
	    spsr_irq <= cpsr;
    else if ( cmd_ok & ( cpsr_m==5'b10010) & ( cmd_is_msr0|cmd_is_msr1 ) & cmd[22] ) begin
        spsr_irq[10:0] <= {{cmd[19] ? sec_operand[31:28] : spsr_irq[10:7]},
                     {cmd[16] ? {sec_operand[7:6], sec_operand[4:0]} : spsr_irq[6:0]}}; 
        spsr_irq[11] <= cmd[16] ? sec_operand[5] : spsr_irq[11];                         
    end	
end

always @(posedge clk)
if ( rst )
    spsr_svc <= 11'd0;
else if ( cpu_en ) begin
    if ( ~ram_abort & ~fiq_en & ~irq_en & ( cmd_flag & ~code_abort & ~code_und & (cond_satisfy & cmd_is_swi) ) )
	    spsr_svc <= cpsr;
    else if ( cmd_ok & ( cpsr_m==5'b10011) & ( cmd_is_msr0|cmd_is_msr1 ) & cmd[22] ) begin
        spsr_svc[10:0] <= {{cmd[19] ? sec_operand[31:28] : spsr_svc[10:7]},
                     {cmd[16] ? {sec_operand[7:6], sec_operand[4:0]} : spsr_svc[6:0]}}; 	
        spsr_svc[11] <= cmd[16] ? sec_operand[5] : spsr_svc[11];
    end
end

always @(posedge clk)
if ( rst )
    spsr_und <= 11'd0;
else if ( cpu_en ) begin
    if ( ~ram_abort & ~fiq_en & ~irq_en & ( cmd_flag & ~code_abort & code_und ) )
	    spsr_und <= cpsr;
    else if ( cmd_ok & ( cpsr_m==5'b11011) & ( cmd_is_msr0|cmd_is_msr1 ) & cmd[22] ) begin
        spsr_und[10:0] <= {{cmd[19] ? sec_operand[31:28] : spsr_und[10:7]},
                     {cmd[16] ? {sec_operand[7:6], sec_operand[4:0]} : spsr_und[6:0]}}; 
        spsr_und[11] <= cmd[16] ? sec_operand[5] : spsr_und[11];
    end	
end

always @ ( cpsr_m or spsr_svc or spsr_abt or spsr_irq or spsr_fiq or spsr_und or cpsr )
if ( cpsr_m == 5'b10011 )
    spsr = spsr_svc;
else if ( cpsr_m == 5'b10111 )
    spsr = spsr_abt; 
else if ( cpsr_m == 5'b10010 )
    spsr = spsr_irq;
else if ( cpsr_m == 5'b10001 )
    spsr = spsr_fiq;
else if ( cpsr_m == 5'b11011 )
    spsr = spsr_und;
else
    spsr = cpsr; 

assign to_vld = cmd_ok & ( cmd_is_mrs | 
                ((cmd_is_dp0|cmd_is_dp1|cmd_is_dp2) & (cmd[24:23]!=2'b10)) | 
                cmd_is_mult | cmd_is_multl | cmd_is_multlx | 
                ((cmd_is_ldrh0|cmd_is_ldrh1|cmd_is_ldrsb0|cmd_is_ldrsb1|cmd_is_ldrsh0|
                    cmd_is_ldrsh1|cmd_is_ldr0|cmd_is_ldr1) & (cmd[21]|~cmd[24])) |
                (cmd_is_ldm & cmd_sum_m==5'b0 & cmd[21] & (~basereg_in_list | ~cmd[20])) );  // LDM does not write-back basereg if it is in reglist

always @ ( cmd_is_mrs or cmd_is_dp0 or cmd_is_dp1 or cmd_is_dp2 or cmd_is_multl or cmd )
if (cmd_is_mrs|(cmd_is_dp0|cmd_is_dp1|cmd_is_dp2)|cmd_is_multl)
    to_num = cmd[15:12];
else
    to_num = cmd[19:16];

	
always @ ( cmd_is_mrs or cmd or spsr or cpsr or cmd_is_dp0 or cmd_is_dp1 or cmd_is_dp2 or dp_ans or sum_rn_rm )
if ( cmd_is_mrs )
    to_data = cmd[22] ? {spsr[10:7],20'b0,spsr[6:5],spsr[11],spsr[4:0]} : 
               {cpsr[10:7],20'b0,cpsr[6:5],cpsr[11],cpsr[4:0]};
else if (cmd_is_dp0 | cmd_is_dp1 | cmd_is_dp2)
    to_data = dp_ans;
else
    to_data = sum_rn_rm; 	

assign to_rf_vld = cmd_ok & ((cmd[15:12]==4'hf & (cmd_is_dp0 | cmd_is_dp1 | cmd_is_dp2) & 
                    cmd[24:23]!=2'b10) | (cmd_is_b | cmd_is_bx) & ~cmd_is_bll); 

always @ ( cmd_ok or cmd_is_ldrh0 or cmd_is_ldrh1 or cmd_is_ldrsb0 or cmd_is_ldrsb1 or cmd_is_ldrsh0 or cmd_is_ldrsh1 or cmd_is_ldr0 or cmd_is_ldr1 or cmd or cmd_is_swp )
if ( cmd_ok )
    cha_vld = ((cmd_is_ldrh0 | cmd_is_ldrh1 | cmd_is_ldrsb0 | cmd_is_ldrsb1 | 
                 cmd_is_ldrsh0|cmd_is_ldrsh1|cmd_is_ldr0|cmd_is_ldr1) & cmd[20]) | cmd_is_swp;
else
    cha_vld = 0;

always @ ( cmd )
    cha_num = cmd[15:12];

assign cha_rf_vld = cha_vld & ( cha_num==4'hf );

always @(posedge clk)
if ( rst )
    go_vld <= 1'd0;
else if ( cpu_en )
    go_vld <= cha_vld;


always @(posedge clk)
if ( rst )
    go_num <= 4'd0;
else if ( cpu_en )
    go_num <= cha_num;

always @(posedge clk)
if ( rst )
    go_fmt <= 6'd0;
else if ( cpu_en ) begin
    if ( cmd_is_ldr0|cmd_is_ldr1|cmd_is_swp )
        go_fmt <= cmd[22] ?{4'b0010,cmd_addr[1:0]}: {4'b1000,cmd_addr[1:0]};
    else if ( cmd_is_ldrh0|cmd_is_ldrh1 )
        go_fmt <= {4'b0100,cmd_addr[1:0]};
	else if ( cmd_is_ldrsb0|cmd_is_ldrsb1 )
	    go_fmt <= {4'b0011,cmd_addr[1:0]};
	else if ( cmd_is_ldrsh0|cmd_is_ldrsh1 )
        go_fmt <= {4'b0101,cmd_addr[1:0]};
	else if ( cmd_is_ldm )
	    go_fmt <= {4'b1000,2'b0};       // LDM treats unaligned addresses as aligned
end

assign go_rf_vld = go_vld & (go_num==4'hf);


always @ ( go_fmt or ram_rdata )
if ( go_fmt[5] ) begin
    // go_data = ram_rdata;
    // if (go_fmt[1:0])
    //     $display("off=%x, data=%x, pc=%x", go_fmt[1:0], ram_rdata, rf);
    case(go_fmt[1:0])                   // ldr (unaligned, see datasheet 4.9.3)
    2'b00: go_data = ram_rdata;
    2'b01: go_data = {ram_rdata[7:0], ram_rdata[31:8]};
    2'b10: go_data = {ram_rdata[15:0], ram_rdata[31:16]};
    2'b11: go_data = {ram_rdata[23:0], ram_rdata[31:24]};
    endcase
end else if ( go_fmt[4] )               // ldrh / ldrsh (datasheet 4.10.4 says unaligned is not supported, but we implement mgba-suite behavior)
    case (go_fmt[1:0])
    2'b00: go_data = {{16{go_fmt[2]&ram_rdata[15]}},ram_rdata[15:0]};
    2'b01: if (go_fmt[2]) go_data = {{24{go_fmt[2]&ram_rdata[15]}},ram_rdata[15:8]};
           else           go_data = {ram_rdata[7:0], 16'b0, ram_rdata[15:8]};
    2'b10: go_data = {{16{go_fmt[2]&ram_rdata[31]}},ram_rdata[31:16]};
    2'b11: if (go_fmt[2]) go_data = {{24{go_fmt[2]&ram_rdata[31]}},ram_rdata[31:24]};
           else           go_data = {ram_rdata[23:15], 16'b0, ram_rdata[31:24]};
    endcase
else// if ( cha_reg_fmt[3] )        // ldrb / ldrsb
    case(go_fmt[1:0])
    2'b00 : go_data = { {24{go_fmt[2]&ram_rdata[7]}}, ram_rdata[7:0] };
    2'b01 : go_data = { {24{go_fmt[2]&ram_rdata[15]}}, ram_rdata[15:8] };	
    2'b10 : go_data = { {24{go_fmt[2]&ram_rdata[23]}}, ram_rdata[23:16] };	
    2'b11 : go_data = { {24{go_fmt[2]&ram_rdata[31]}}, ram_rdata[31:24] };	
    endcase	


always @(posedge clk)
if ( rst )
    ldm_vld <= 1'd0;
else if ( cpu_en )
    ldm_vld <= cmd_ok & cmd_is_ldm & cmd[20] & (cmd_sum_m!=5'b0);

always @ ( cmd )
if ( cmd[0] )
    ldm_sel = 4'h0;
else if ( cmd[1] )
    ldm_sel = 4'h1; 
else if ( cmd[2] )
    ldm_sel = 4'h2; 
else if ( cmd[3] )
    ldm_sel = 4'h3; 
else if ( cmd[4] )
    ldm_sel = 4'h4; 
else if ( cmd[5] )
    ldm_sel = 4'h5; 
else if ( cmd[6] )
    ldm_sel = 4'h6; 
else if ( cmd[7] )
    ldm_sel = 4'h7; 
else if ( cmd[8] )
    ldm_sel = 4'h8; 
else if ( cmd[9] )
    ldm_sel = 4'h9; 
else if ( cmd[10] )
    ldm_sel = 4'ha; 
else if ( cmd[11] )
    ldm_sel = 4'hb; 
else if ( cmd[12] )
    ldm_sel = 4'hc; 
else if ( cmd[13] )
    ldm_sel = 4'hd; 
else if ( cmd[14] )
    ldm_sel = 4'he; 
else if ( cmd[15] )
    ldm_sel = 4'hf; 
else 
    ldm_sel = 4'h0;

always @(posedge clk)
if ( rst )
    ldm_num <= 4'd0;
else if ( cpu_en )
    if ( cmd_is_ldm )
        ldm_num <= ldm_sel;

always @(posedge clk)
if ( rst )
    ldm_usr <= 1'd0;
else if ( cpu_en )
    ldm_usr <= cmd_ok & cmd_is_ldm & cmd[20] &  cmd[22] & ~cmd[15];

assign ldm_data = go_data;
assign ldm_rf_vld = ldm_vld & ldm_num==4'hf | (cmd_ok & cmd_is_ldm & cmd[20] & ldm_sel==4'hf);	

always @(posedge clk)
if ( rst )
    r0 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ldm_num==4'h0)
	    r0 <= ldm_data;
	else if (cmd_ok & to_vld & ( to_num== 4'h0 ) )      // cmd stage has priority over go_vld (write-back) stage
	    r0 <= to_data;
	else if (go_vld & go_num==4'h0)
	    r0 <= go_data;
end

always @(posedge clk)
if ( rst )
    r1 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h1 ) ) 
	    r1 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h1 ) )
	    r1 <= to_data;
	else if ( go_vld & (go_num==4'h1 ) )
	    r1 <= go_data;
end

always @(posedge clk)
if ( rst )
    r2 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h2 ) )
	    r2 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h2 ) )
	    r2 <= to_data;
	else if ( go_vld & (go_num==4'h2 ) )
	    r2 <= go_data;
end

always @(posedge clk)
if ( rst )
    r3 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h3 ) )
	    r3 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h3 ) )
	    r3 <= to_data;
	else if ( go_vld & (go_num==4'h3 ) )
	    r3 <= go_data;
end

always @(posedge clk)
if ( rst )
    r4 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h4 ) )
	    r4 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h4 ) )
	    r4 <= to_data;
	else if ( go_vld & (go_num==4'h4 ) )
	    r4 <= go_data;
end

always @(posedge clk)
if ( rst )
    r5 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h5 ) )
	    r5 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h5 ) )
	    r5 <= to_data;
	else if ( go_vld & (go_num==4'h5 ) )
	    r5 <= go_data;
end

always @(posedge clk)
if ( rst )
    r6 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h6 ) )
	    r6 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h6 ) )
	    r6 <= to_data;
	else if ( go_vld & (go_num==4'h6 ) )
	    r6 <= go_data;
end

always @(posedge clk)
if ( rst )
    r7 <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h7 ) )
	    r7 <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h7 ) )
	    r7 <= to_data;
	else if ( go_vld & (go_num==4'h7 ) )
	    r7 <= go_data;
end

assign r8 = (cpsr_m==5'b10001) ? r8_fiq : r8_usr;  

always @(posedge clk)
if ( rst )
    r8_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h8 )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    r8_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'h8 ) & (cpsr_m==5'b10001 )  )
	    r8_fiq <= to_data;
	else if ( go_vld & (go_num==4'h8 ) & (cpsr_m==5'b10001 ) )
	    r8_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    r8_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h8 ) & ( ldm_usr | (cpsr_m!=5'b10001 ) ) )
	    r8_usr <= ldm_data;
	else if ( cmd_ok & to_vld & ( to_num== 4'h8 ) & (cpsr_m!=5'b10001 )  )
        r8_usr <= to_data;
	else if ( go_vld & (go_num==4'h8 ) & (cpsr_m!=5'b10001 ) )
	    r8_usr <= go_data;
end

assign r9 = (cpsr_m==5'b10001) ? r9_fiq : r9_usr;  

always @(posedge clk)
if ( rst )
    r9_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h9 )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    r9_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'h9 ) & (cpsr_m==5'b10001 )  )
	    r9_fiq <= to_data;
	else if ( go_vld & (go_num==4'h9 ) & (cpsr_m==5'b10001 ) )
	    r9_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    r9_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'h9 ) & ( ldm_usr | (cpsr_m!=5'b10001 ) ) )
	    r9_usr <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'h9 ) & (cpsr_m!=5'b10001 )  )
	    r9_usr <= to_data;
	else if ( go_vld & (go_num==4'h9 ) & (cpsr_m!=5'b10001 ) )
	    r9_usr <= go_data;
end

assign ra = (cpsr_m==5'b10001) ? ra_fiq : ra_usr;  

always @(posedge clk)
if ( rst )
    ra_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'ha )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    ra_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'ha ) & (cpsr_m==5'b10001 )  )
	    ra_fiq <= to_data;
	else if ( go_vld & (go_num==4'ha ) & (cpsr_m==5'b10001 ) )
	    ra_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    ra_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'ha ) & ( ldm_usr | (cpsr_m!=5'b10001 ) ) )
	    ra_usr <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'ha ) & (cpsr_m!=5'b10001 )  )
	    ra_usr <= to_data;
	else if ( go_vld & (go_num==4'ha ) & (cpsr_m!=5'b10001 ) )
	    ra_usr <= go_data;
end

assign rb = (cpsr_m==5'b10001) ? rb_fiq : rb_usr;  

always @(posedge clk)
if ( rst )
    rb_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hb )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    rb_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hb ) & (cpsr_m==5'b10001 )  )
	    rb_fiq <= to_data;
	else if ( go_vld & (go_num==4'hb ) & (cpsr_m==5'b10001 ) )
	    rb_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    rb_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hb ) & ( ldm_usr | (cpsr_m!=5'b10001 ) ) )
	    rb_usr <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hb ) & (cpsr_m!=5'b10001 )  )
	    rb_usr <= to_data;
	else if ( go_vld & (go_num==4'hb ) & (cpsr_m!=5'b10001 ) )
	    rb_usr <= go_data;
end

assign rc = (cpsr_m==5'b10001) ? rc_fiq : rc_usr;  

always @(posedge clk)
if ( rst )
    rc_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hc )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    rc_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hc ) & (cpsr_m==5'b10001 )  )
	    rc_fiq <= to_data;
	else if ( go_vld & (go_num==4'hc ) & (cpsr_m==5'b10001 ) )
	    rc_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    rc_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hc ) & ( ldm_usr | (cpsr_m!=5'b10001 ) ) )
	    rc_usr <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hc ) & (cpsr_m!=5'b10001 )  )
	    rc_usr <= to_data;
	else if ( go_vld & (go_num==4'hc ) & (cpsr_m!=5'b10001 ) )
	    rc_usr <= go_data;
end

always @ ( cpsr_m or rd_fiq or rd_und or rd_irq or rd_abt or rd_svc or rd_usr )
case ( cpsr_m )
5'b10001 : rd = rd_fiq;
5'b11011 : rd = rd_und;
5'b10010 : rd = rd_irq;
5'b10111 : rd = rd_abt;  
5'b10011 : rd = rd_svc;
default  : rd = rd_usr;
endcase	

always @(posedge clk)
if ( rst )
    rd_abt <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hd )& ( ~ldm_usr & (cpsr_m==5'b10111 ) ) )
	    rd_abt <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hd ) & (cpsr_m==5'b10111 )  )
	    rd_abt <= to_data;
	else if ( go_vld & (go_num==4'hd ) & (cpsr_m==5'b10111 ) )
	    rd_abt <= go_data;
end

always @(posedge clk)
if ( rst )
    rd_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hd )& ( ~ldm_usr & (cpsr_m==5'b10001 ) ) )
	    rd_fiq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hd ) & (cpsr_m==5'b10001 )  )
	    rd_fiq <= to_data;
	else if ( go_vld & (go_num==4'hd ) & (cpsr_m==5'b10001 ) )
	    rd_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    rd_irq <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hd )& ( ~ldm_usr & (cpsr_m==5'b10010 ) ) )
	    rd_irq <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hd ) & (cpsr_m==5'b10010 )  )
	    rd_irq <= to_data;
	else if ( go_vld & (go_num==4'hd ) & (cpsr_m==5'b10010 ) )
	    rd_irq <= go_data;
end

always @(posedge clk)
if ( rst )
    rd_svc <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hd )& ( ~ldm_usr & (cpsr_m==5'b10011 ) ) )
	    rd_svc <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hd ) & (cpsr_m==5'b10011 )  )
	    rd_svc <= to_data;
	else if ( go_vld & (go_num==4'hd ) & (cpsr_m==5'b10011 ) )
	    rd_svc <= go_data;
end

always @(posedge clk)
if ( rst )
    rd_und <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ( ldm_num==4'hd )& ( ~ldm_usr & (cpsr_m==5'b11011 ) ) )
	    rd_und <= ldm_data;
	else if ( cmd_ok & to_vld  & ( to_num== 4'hd ) & (cpsr_m==5'b11011 )  )
	    rd_und <= to_data;
	else if ( go_vld & (go_num==4'hd ) & (cpsr_m==5'b11011 ) )
	    rd_und <= go_data;
end

always @(posedge clk)
if ( rst )
    rd_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ldm_num==4'hd & (ldm_usr | (cpsr_m!=5'b10001 & cpsr_m!=5'b11011 &
                                cpsr_m!=5'b10010 & cpsr_m!=5'b10111 & cpsr_m!=5'b10011)) )
	    rd_usr <= ldm_data;
	else if ( cmd_ok & to_vld & to_num== 4'hd & (cpsr_m!=5'b10001 & cpsr_m!=5'b11011 & 
                                cpsr_m!=5'b10010 & cpsr_m!=5'b10111 & cpsr_m!=5'b10011) )
	    rd_usr <= to_data;
	else if ( go_vld & go_num==4'hd & (cpsr_m!=5'b10001 & cpsr_m!=5'b11011 &
                                cpsr_m!=5'b10010 & cpsr_m!=5'b10111 & cpsr_m!=5'b10011) )
	    rd_usr <= go_data;
end

always @ ( cpsr_m or re_fiq or re_und or re_irq or re_abt or re_svc or re_usr )
case ( cpsr_m )
5'b10001 : re = re_fiq;
5'b11011 : re = re_und;
5'b10010 : re = re_irq;
5'b10111 : re = re_abt;  
5'b10011 : re = re_svc;
default  : re = re_usr;
endcase	

always @(posedge clk)
if ( rst )
    re_abt <= 32'd0;
else if ( cpu_en ) begin
    if ( ram_abort | ( ~fiq_en & ~irq_en & cmd_flag & code_abort ) )
        re_abt <= rf_b;		
    else if ( ldm_vld & ldm_num==4'he & ~ldm_usr & cpsr_m==5'b10111 )
	    re_abt <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & cpsr_m==5'b10111 ) 
    begin
        if (cmd_is_bll)
            re_abt <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_abt <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
    else if ( cmd_ok & to_vld  & to_num== 4'he & cpsr_m==5'b10111 )
	    re_abt <= to_data;
	else if ( go_vld & go_num==4'he & cpsr_m==5'b10111 )
	    re_abt <= go_data;
end	

always @(posedge clk)
if ( rst )
    re_fiq <= 32'd0;
else if ( cpu_en ) begin
    if ( fiq_en ) begin
	    if ( ram_abort )
		    re_fiq <= 32'h10;
        else
		    re_fiq <= rf_b;
    end else if ( ldm_vld & ldm_num==4'he & ~ldm_usr & cpsr_m==5'b10001 )
	    re_fiq <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & cpsr_m==5'b10001 )
    begin
        if (cmd_is_bll)
            re_fiq <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_fiq <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
	else if ( cmd_ok & to_vld & to_num== 4'he & cpsr_m==5'b10001 )
	    re_fiq <= to_data;
	else if ( go_vld & go_num==4'he & cpsr_m==5'b10001 )
	    re_fiq <= go_data;
end

always @(posedge clk)
if ( rst )
    re_irq <= 32'd0;
else if ( cpu_en ) begin
    if  ( ~ram_abort & ~fiq_en & irq_en )
        re_irq <= cpsr_t ? rf_b + 2 : rf_b;	        // thumb mode +2
    else if ( ldm_vld & ldm_num==4'he & ~ldm_usr & cpsr_m==5'b10010 )
	    re_irq <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & cpsr_m==5'b10010 )
    begin
        if (cmd_is_bll)
            re_irq <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_irq <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
	else if ( cmd_ok & to_vld  & to_num== 4'he & cpsr_m==5'b10010 )
	    re_irq <= to_data;
	else if ( go_vld & go_num==4'he & cpsr_m==5'b10010 )
	    re_irq <= go_data;
end	

always @(posedge clk)
if ( rst )
    re_svc <= 32'd0;
else if ( cpu_en ) begin
    if ( ~ram_abort & ~fiq_en & ~irq_en & cmd_flag & ~code_abort & ~code_und & cond_satisfy & cmd_is_swi )
        re_svc <= rf_b;
    else if ( ldm_vld & ldm_num==4'he & ~ldm_usr & cpsr_m==5'b10011 )
	    re_svc <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & cpsr_m==5'b10011 )
    begin
        if (cmd_is_bll)
            re_svc <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_svc <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
	else if ( cmd_ok & to_vld & to_num== 4'he & cpsr_m==5'b10011 )
	    re_svc <= to_data;
	else if ( go_vld & go_num==4'he & cpsr_m==5'b10011 )
	    re_svc <= go_data;
end	

always @(posedge clk)
if ( rst )
    re_und <= 32'd0;
else if ( cpu_en ) begin
    if ( ~ram_abort & ~fiq_en & ~irq_en & cmd_flag & ~code_abort & code_und )
	    re_und <= rf_b;
    else if ( ldm_vld & ldm_num==4'he & ~ldm_usr & cpsr_m==5'b11011 )
	    re_und <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & cpsr_m==5'b11011 )
    begin
        if (cmd_is_bll)
            re_und <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_und <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
	else if ( cmd_ok & to_vld & to_num== 4'he & cpsr_m==5'b11011 )
	    re_und <= to_data;
	else if ( go_vld & go_num==4'he & cpsr_m==5'b11011 )
	    re_und <= go_data;
end	

always @(posedge clk)
if ( rst )
    re_usr <= 32'd0;
else if ( cpu_en ) begin
    if ( ldm_vld & ldm_num==4'he & ( ldm_usr | (cpsr_m!=5'b10001 & cpsr_m!=5'b11011 & 
            cpsr_m!=5'b10010 & cpsr_m!=5'b10111 & cpsr_m!=5'b10011) ) )
	    re_usr <= ldm_data;
	else if ( cmd_ok & cmd_is_b & cmd[24] & ((cpsr_m!=5'b10001)&(cpsr_m!=5'b11011)&
            (cpsr_m!=5'b10010)&(cpsr_m!=5'b10111)&(cpsr_m!=5'b10011)) )
    begin
        if (cmd_is_bll)
            re_usr <= sum_rn_rm;                    // BLL: LR = PC + offset
        else        
	        re_usr <= {rf_b[31:1], cpsr_t};         // otherwise: LR = return address
	end 
	else if ( cmd_ok & to_vld  & to_num== 4'he & ((cpsr_m!=5'b10001)&(cpsr_m!=5'b11011)&
            (cpsr_m!=5'b10010)&(cpsr_m!=5'b10111)&(cpsr_m!=5'b10011)) )
	    re_usr <= to_data;
	else if ( go_vld & go_num==4'he & ((cpsr_m!=5'b10001)&(cpsr_m!=5'b11011)&(cpsr_m!=5'b10010)&
            (cpsr_m!=5'b10111)&(cpsr_m!=5'b10011)) )
	    re_usr <= go_data;
end


always @(posedge clk)
if ( rst )
    rf <= 32'd0;
else if ( cpu_en ) begin
    if ( cpu_restart )
	    rf <= 32'h0000_0000;
	else if ( fiq_en )
	    rf <= 32'h0000_001c;
	else if ( ram_abort )
	    rf <= 32'h0000_0010;
	else if ( irq_en )
	    rf <= 32'h0000_0018;
	else if ( cmd_flag & code_abort )
	    rf <= 32'h0000_000c; 
	else if ( cmd_flag & code_und )
	    rf <= 32'h0000_0004;
    else if ( cmd_flag & cond_satisfy & cmd_is_swi )
        rf <= 32'h0000_0008;
	else if ( ldm_vld & ldm_num==4'hf )
        rf <= ldm_data;	
    else if ( cmd_ok & (cmd_is_dp0|cmd_is_dp1|cmd_is_dp2) & cmd[24:23]!=2'b10 & cmd[15:12]==4'hf )
	    rf <= dp_ans;	
	else if ( cmd_ok & (cmd_is_b | cmd_is_bx) & ~cmd_is_bll)        // BLL does not update R15
	    rf <= sum_rn_rm;
	else if ( go_vld & go_num==4'hf )
        rf <= go_data;
    else if ( ~hold_en & ~wait_en )
        rf <= rf + (cpsr_t ? 2 : 4);
    rf[0] <= 1'b0;          // datasheet 3.7.1: In THUMB state, bits 0 of R15 are zero
                            //                  In ARM state, bits [1:0] of R15 are zero
end

assign rf_b = rf - (cpsr_t ? 2 : 4);	

always @ ( cmd_is_ldm or sum_rn_rm or cmd_is_swp or cmd_is_swpx or rn or cmd  )
if ( cmd_is_ldm )
    cmd_addr = sum_rn_rm; 
else if ( cmd_is_swp|cmd_is_swpx )
    cmd_addr = rn;
else if ( cmd[24] )
    cmd_addr = sum_rn_rm;
else
    cmd_addr = rn;

// assign ram_addr = {cmd_addr[31:2],2'b0};
assign ram_addr = cmd_addr;     // flash and sram needs last two bits

assign ram_cen = /* cpu_en &*/ cmd_ok & (cmd_is_ldrh0|cmd_is_ldrh1|cmd_is_ldrsb0|cmd_is_ldrsb1|
                    cmd_is_ldrsh0|cmd_is_ldrsh1|cmd_is_ldr0|cmd_is_ldr1|cmd_is_swp|
                    cmd_is_swpx| (cmd_is_ldm &(cmd_sum_m!=5'b0)) );

assign ram_wen = cmd_is_swp ? 1'b0 : ~cmd[20];	


always @ ( cmd_is_ldr0 or cmd_is_ldr1 or cmd_is_swp or cmd_is_swpx or cmd or cmd_addr or cmd_is_ldrh0 or cmd_is_ldrh1 or cmd_is_ldrsh0 or cmd_is_ldrsh1 or cmd_is_ldrsb0 or cmd_is_ldrsb1 )
if ( cmd_is_ldr0|cmd_is_ldr1|cmd_is_swp|cmd_is_swpx )
    ram_flag = cmd[22]? (1'b1<<cmd_addr[1:0]):4'b1111;
else if (cmd_is_ldrh0|cmd_is_ldrh1|cmd_is_ldrsh0|cmd_is_ldrsh1 )
    ram_flag = cmd_addr[1] ? 4'b1100 : 4'b0011;
else if ( cmd_is_ldrsb0|cmd_is_ldrsb1 ) 
    ram_flag = 1'b1<<cmd_addr[1:0];
else
    ram_flag = 4'b1111;

always @ ( cmd_is_ldm or cmd or r0 or r1 or r2 or r3 or r4 or r5 or r6 or r7 or r8 or r9 or ra or rb or rc or rd or re or r8_usr or r9_usr or ra_usr or rb_usr or rc_usr or rd_usr or re_usr or rf or cmd_is_ldr0 or cmd_is_ldr1 or cmd_is_swpx or rna or cmd_is_ldrh0 or cmd_is_ldrh1 )
if ( cmd_is_ldm ) begin
    if ( cmd[0] )
        ram_wdata = r0;
    else if ( cmd[1] )
        ram_wdata = r1; 
    else if ( cmd[2] )
        ram_wdata = r2; 
    else if ( cmd[3] )
        ram_wdata = r3; 
    else if ( cmd[4] )
        ram_wdata = r4; 
    else if ( cmd[5] )
        ram_wdata = r5; 
    else if ( cmd[6] )
        ram_wdata = r6; 
    else if ( cmd[7] )
        ram_wdata = r7; 
    else if ( cmd[8] )
        ram_wdata = cmd[22] ? r8_usr : r8; 
    else if ( cmd[9] )
        ram_wdata = cmd[22] ? r9_usr : r9; 
    else if ( cmd[10] )
        ram_wdata = cmd[22] ? ra_usr : ra; 
    else if ( cmd[11] )
        ram_wdata = cmd[22] ? rb_usr : rb; 
    else if ( cmd[12] )
        ram_wdata = cmd[22] ? rc_usr : rc; 
    else if ( cmd[13] )
        ram_wdata = cmd[22] ? rd_usr : rd; 
    else if ( cmd[14] )
        ram_wdata = cmd[22] ? re_usr : re; 
    else if ( cmd[15] )
        ram_wdata = rf + 4;         // datasheet 4.11.1 (ldm/stm): Whenever R15 is stored to memory the stored value is the address of the STM instruction plus 12
    else 
        ram_wdata = 4'h0;
end else if ( cmd_is_ldr0|cmd_is_ldr1|cmd_is_swpx ) begin
    if ( cmd[22] )
	    ram_wdata = { rna[7:0],rna[7:0],rna[7:0],rna[7:0]};
    else
        ram_wdata = rna;	
end else if ( cmd_is_ldrh0|cmd_is_ldrh1 )
    ram_wdata = {rna[15:0],rna[15:0]};
else
    ram_wdata = rna;

assign rom_en = /* cpu_en &*/ ( ~(int_all | to_rf_vld | cha_rf_vld | go_rf_vld | wait_en | hold_en ) );
assign rom_addr = rf;	

assign wait_en = (code_rm_vld   & cha_vld            & cha_num       == code_rm_num) | 
                 (code_rm_vld   & to_vld             & to_num        == code_rm_num) | 
                 (code_rm_vld   & go_vld             & go_num        == code_rm_num) | 
                 (code_rs_vld   & cha_vld            & cha_num       == code_rs_num) | 
                 (code_rs_vld   & to_vld             & to_num        == code_rs_num) | 
                 (code_rs_vld   & go_vld             & go_num        == code_rs_num) | 
                 (code_rn_vld   & cha_vld            & code_rn_num   == cha_num) |  
                 (code_rnhi_vld & cha_vld            & code_rnhi_num == cha_num) | 
                //  (code_stm_vld  & cha_vld            & (code[15:0] & (~code[15:0] + 16'd1)) == (16'd1 << cha_num)) |
                 (code_stm_vld  & cha_vld            & code_stm_num  == cha_num) |
                 (code_rm_vld   & ldm_vld & ~hold_en & ldm_num       == code_rm_num) | 
                 (code_rs_vld   & ldm_vld & ~hold_en & ldm_num       == code_rs_num) |
                 // last inst is MSR, and this inst uses LR or SP
                 (code_rm_vld   & (cmd_is_msr0 | cmd_is_msr1) & cmd_ok & (code_rm_num == 4'hD | code_rm_num == 4'hE)) |
                 (code_rs_vld   & (cmd_is_msr0 | cmd_is_msr1) & cmd_ok & (code_rs_num == 4'hD | code_rs_num == 4'hE))
                 ;

endmodule



