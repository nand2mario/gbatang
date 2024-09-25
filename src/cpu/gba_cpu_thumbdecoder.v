//****************************************************************************************************
// Thumb decoder for ARM7TDMI-S processor
// Designed by Ruslan Lepetenok
// Modified 30.01.2003
//****************************************************************************************************
// 2024.8 by nand2mario: Fix translation of BL instruction
module ThumbDecoder(
    input           CLK,
    input           nRESET,
    input           CLKEN,
    input [31:0]    InstForDecode,      // Instruction to decode
    input           HalfWordAddress,    // Which half-word to decode
    input           ThumbDecoderEn,     // 1: cpu in thumb mode, 0: in arm mode
    output [31:0]   ExpandedInst,       // Thumb instruction expanded as ARM one
    output          ThADR,              // THUMB ADD(5) and PC-relative load correction. PC bit 1 should be cleared.
                                        // 1: this is a thumb load address instruciton (see datasheet 5.12.1)
                                        //    or PC-relative load instruction (datasheet 5.6.1)
    output reg      ThBLL,              // BLL instruction, ExpandedInst is BL with imm24 = imm11 << 11 (signed extended)
    output reg      ThBLH               // BLH instruction, ExpandedInst is BL with imm24 = imm11       (signed extended)
);

wire [15:0]     HalfWordForDecode;
reg [31:0]      DecoderOut;

reg [10:0]      ThBLFP_Reg;
reg             ThBLFP_Reg_EN;

// reg             ThADR_IDC;
reg             ThADR_Int;
//---------------------------------------------------------------
// Instruction types
//----------------------------------------------------------------

// Constants
parameter [4:0] CThBLFP = 5'b11110;		// First part of Thumb BL
parameter [4:0] CThBLSP = 5'b11111;		// Second part of Thumb BL

assign HalfWordForDecode = HalfWordAddress == 1'b0 ? InstForDecode[15:0] : 
                            InstForDecode[31:16];

assign ExpandedInst = ThumbDecoderEn ? DecoderOut : 		// Thumb instruction
                        InstForDecode;		                // ARM instruction
assign ThADR = ThADR_Int & ThumbDecoderEn;

// always @(posedge CLK)
// begin: ThADR_Register
//     if (nRESET == 1'b0)
//         ThADR_Int <= 1'b0;
//     else  begin
//         if (CLKEN & StagnatePipeline == 1'b0)
//             ThADR_Int <= ThADR_IDC;
//     end 
// end

always @(posedge CLK) begin
    if (nRESET == 1'b0)
        ThBLFP_Reg <= {11{1'b0}};
    else  begin		// Maybe need CLKEN?
        if (CLKEN & ThBLFP_Reg_EN)
            ThBLFP_Reg <= HalfWordForDecode[10:0];
    end 
end

// Combinatorial process
// Naming based on ARM ISA

always @(HalfWordForDecode) begin
    // Move Instructions
    ThBLFP_Reg_EN = 1'b0;
    ThADR_Int = 1'b0;
    ThBLL = 0;
    ThBLH = 0;
    DecoderOut[31:0] = {32{1'b0}};

    casez (HalfWordForDecode[15:6])
    10'b00100?????: begin		// MOV1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00111011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end


    10'b01000110??: begin		// MOV3
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011010;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15] = HalfWordForDecode[7];
        DecoderOut[14:12] = HalfWordForDecode[2:0];
        DecoderOut[11:4] = {4'b0000, 4'b0000};
        DecoderOut[3] = HalfWordForDecode[6];
        DecoderOut[2:0] = HalfWordForDecode[5:3];
    end

    // Arithmetic Instructions
    10'b0100000101: begin		// ADC
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00001011;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 
    
    10'b0001110???: begin		
        if (HalfWordForDecode[8:6] == 3'b000) begin // MOV2
            DecoderOut[31:28] = 4'b1110;
            DecoderOut[27:20] = 8'b00101001;
            DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
            DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
            DecoderOut[11:0] = 12'b000000000000;
        end else begin              // ADD1
            DecoderOut[31:28] = 4'b1110;
            DecoderOut[27:20] = 8'b00101001;
            DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
            DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
            DecoderOut[11:3] = 9'b000000000;
            DecoderOut[2:0] = HalfWordForDecode[8:6];
        end
    end
    
    10'b00110?????: begin		// ADD2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00101001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 
    
    10'b0001100???: begin		// ADD3
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00001001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 
    
    10'b01000100??: begin		// ADD4
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00001000;
        DecoderOut[19] = HalfWordForDecode[7];
        DecoderOut[18:16] = HalfWordForDecode[2:0];
        DecoderOut[15] = HalfWordForDecode[7];
        DecoderOut[14:12] = HalfWordForDecode[2:0];
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3] = HalfWordForDecode[6];
        DecoderOut[2:0] = HalfWordForDecode[5:3];
    end
    
    10'b10100?????: begin		// ADD5
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00101000;
        DecoderOut[19:16] = 4'b1111;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:8] = 4'b1111;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
        ThADR_Int = 1'b1;
    end
    
    10'b10101?????: begin		// ADD6
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00101000;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:8] = 4'b1111;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 
    
    10'b101100000?: begin		// ADD7
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00101000;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15:12] = 4'b1101;
        DecoderOut[11:7] = 5'b11110;
        DecoderOut[6:0] = HalfWordForDecode[6:0];
    end
    
    10'b0100001011: begin		// CMN
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00010111;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 
    
    10'b00101?????: begin		// CMP1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00110101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 
    
    10'b0100001010: begin		// CMP2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00010101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 
    
    10'b01000101??: begin		// CMP3
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00010101;
        DecoderOut[19] = HalfWordForDecode[7];
        DecoderOut[18:16] = HalfWordForDecode[2:0];
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3] = HalfWordForDecode[6];
        DecoderOut[2:0] = HalfWordForDecode[5:3];
    end 
    
    10'b0100001101: begin		// MUL
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00000001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:8] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[7:4] = 4'b1001;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 
    
    10'b0100001001: begin		// NEG
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00100111;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:0] = 12'b000000000000;
    end 

    10'b0100000110: begin		// SBC
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00001101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0001111???: begin		// SUB1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00100101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:3] = 9'b000000000;
        DecoderOut[2:0] = HalfWordForDecode[8:6];
    end         

    10'b00111?????: begin		// SUB2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00100101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 

    10'b0001101???: begin		// SUB3
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00000101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b101100001?: begin		// SUB4
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00100100;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15:12] = 4'b1101;
        DecoderOut[11:7] = 5'b11110;
        DecoderOut[6:0] = HalfWordForDecode[6:0];
    end 

    // Logical Operations
    10'b0100000000: begin		// AND
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00000001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100001110: begin		// BIC
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100000001: begin		// EOR
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00000011;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100001111: begin		// MVN
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011111;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100001100: begin		// ORR
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100001000: begin		// TST
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00010001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[15:12] = 4'b0000;
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    // Shift/Rotate Instructions
    10'b00000?????: begin		// LSL1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:7] = HalfWordForDecode[10:6];
        DecoderOut[6:4] = 3'b000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100000010: begin		// LSL2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[7:4] = 4'b0001;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[2:0]};
    end 

    10'b00001?????: begin		// LSR1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:7] = HalfWordForDecode[10:6];
        DecoderOut[6:4] = 3'b010;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100000011: begin		// LSR2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[7:4] = 4'b0011;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[2:0]};
    end 

    10'b00010?????: begin		// ASR1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:7] = HalfWordForDecode[10:6];
        DecoderOut[6:4] = 3'b100;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[5:3]};
    end 

    10'b0100000100: begin		// ASR2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[19:16] = 4'b0000;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[7:4] = 4'b0101;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[2:0]};
    end 

    10'b0100000111: begin		// ROR
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011011;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[7:4] = 4'b0111;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[2:0]};
    end 

    // Branch Instructions
    10'b1101??????: begin		// B1 & SWI
        if (HalfWordForDecode[11:8] == 4'b1111) begin		// SWI
            DecoderOut[31:28] = 4'b1110;
            DecoderOut[27:24] = 4'b1111;
            DecoderOut[23:8] = 16'b0000000000000000;
            DecoderOut[7:0] = HalfWordForDecode[7:0];
        end else begin                                      // B1
            DecoderOut[31:28] = HalfWordForDecode[11:8];
            DecoderOut[27:24] = 4'b1010;
            DecoderOut[23:8] = {16{HalfWordForDecode[7]}};		    // Sign extend
            DecoderOut[7:0] = HalfWordForDecode[7:0];
        end
    end 

    10'b11100?????: begin		// B2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:24] = 4'b1010;
        DecoderOut[23:11] = {13{HalfWordForDecode[10]}};		// sign extend
        DecoderOut[10:0] = HalfWordForDecode[10:0];
    end

    10'b11110?????: begin		// BLL
        // ThBLFP_Reg_EN = 1'b1;		                        // Register higher 11 bits of imm24 offset
        ThBLL = 1;
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:24] = 4'b1011;
        DecoderOut[23:0] = {{2{HalfWordForDecode[10]}}, HalfWordForDecode[10:0], 11'b0};
    end 

    10'b111?1?????: begin       // BLH
        // reg [21:0] full_offset;
        // full_offset = {ThBLFP_Reg, HalfWordForDecode[10:0]};
        ThBLH = 1;
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:24] = 4'b1011;
        DecoderOut[23:0] = {{13{1'b0}}, HalfWordForDecode[10:0]};
    end

    10'b010001110?: begin		// BX
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:24] = 4'b0001;
        DecoderOut[23:20] = 4'b0010;
        DecoderOut[19:16] = 4'b1111;
        DecoderOut[15:12] = 4'b1111;
        DecoderOut[11:8] = 4'b1111;
        DecoderOut[7:4] = 4'b0001;
        DecoderOut[3] = HalfWordForDecode[6];
        DecoderOut[2:0] = HalfWordForDecode[5:3];
    end 

    // Load
    10'b11001?????: begin		// LDMIA
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:22] = 6'b100010;
        
        //DecoderOut(21) = '0' when HalfWordForDecode(HalfWordForDecode(10 downto 8))='1'
        //                      else '1';
        // Send help, I am lost
        DecoderOut[21] = 1'b1;
        DecoderOut[20] = 1'b1;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[15:8] = 8'b00000000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 

    10'b01101?????: begin		// LDR1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:7] = 5'b00000;
        DecoderOut[6:2] = HalfWordForDecode[10:6];
        DecoderOut[1:0] = 2'b00;
    end 

    10'b0101100???: begin		// LDR2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01111001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b01001?????: begin		// LDR3  (pc relative load)
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011001;
        DecoderOut[19:16] = 4'b1111;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:10] = 2'b00;
        DecoderOut[9:2] = HalfWordForDecode[7:0];
        DecoderOut[1:0] = 2'b00;

        ThADR_Int = 1'b1;      // datasheet 5.6.1
    end 

    10'b10011?????: begin		// LDR4
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011001;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:10] = 2'b00;
        DecoderOut[9:2] = HalfWordForDecode[7:0];
        DecoderOut[1:0] = 2'b00;
    end 

    10'b01111?????: begin		// LDRB1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:5] = 7'b0000000;
        DecoderOut[4:0] = HalfWordForDecode[10:6];
    end 

    10'b0101110???: begin		// LDRB2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01111101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b10001?????: begin		// LDRH1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011101;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:10] = 2'b00;
        DecoderOut[9:8] = HalfWordForDecode[10:9];
        DecoderOut[7:4] = 4'b1011;
        DecoderOut[3:1] = HalfWordForDecode[8:6];
        DecoderOut[0] = 1'b0;
    end 

    10'b0101101???: begin		// LDRH2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:4] = 4'b1011;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b0101011???: begin		// LDRSB
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:4] = 4'b1101;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b0101111???: begin		// LDRSH
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011001;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:4] = 4'b1111;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    // Store Instructions
    10'b11000?????: begin		//STMIA
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b10001010;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[15:8] = 8'b00000000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 

    10'b01100?????: begin		// STR1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011000;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:7] = 5'b00000;
        DecoderOut[6:2] = HalfWordForDecode[10:6];
        DecoderOut[1:0] = 2'b00;
    end 

    10'b0101000???: begin		// STR2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01111000;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b10010?????: begin		// STR3
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011000;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[10:8]};
        DecoderOut[11:10] = 2'b00;
        DecoderOut[9:2] = HalfWordForDecode[7:0];
        DecoderOut[1:0] = 2'b00;
    end 

    10'b01110?????: begin		// STRB1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01011100;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:5] = 7'b0000000;
        DecoderOut[4:0] = HalfWordForDecode[10:6];
    end 

    10'b0101010???: begin		// STRB2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b01111100;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:4] = 8'b00000000;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    10'b10000?????: begin		// STRH1
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011100;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:10] = 2'b00;
        DecoderOut[9:8] = HalfWordForDecode[10:9];
        DecoderOut[7:4] = 4'b1011;
        DecoderOut[3:1] = HalfWordForDecode[8:6];
        DecoderOut[0] = 1'b0;
    end 

    10'b0101001???: begin		// STRH2
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b00011000;
        DecoderOut[19:16] = {1'b0, HalfWordForDecode[5:3]};
        DecoderOut[15:12] = {1'b0, HalfWordForDecode[2:0]};
        DecoderOut[11:8] = 4'b0000;
        DecoderOut[7:4] = 4'b1011;
        DecoderOut[3:0] = {1'b0, HalfWordForDecode[8:6]};
    end 

    // Other
    10'b1011110???: begin		// Pop
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b10001011;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15] = HalfWordForDecode[8];
        DecoderOut[14:8] = 7'b0000000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 

    10'b1011010???: begin		// PUSH
        DecoderOut[31:28] = 4'b1110;
        DecoderOut[27:20] = 8'b10010010;
        DecoderOut[19:16] = 4'b1101;
        DecoderOut[15] = 1'b0;
        DecoderOut[14] = HalfWordForDecode[8];
        DecoderOut[13:8] = 6'b000000;
        DecoderOut[7:0] = HalfWordForDecode[7:0];
    end 

    default: DecoderOut = {32{1'bX}};
    endcase
end


endmodule

