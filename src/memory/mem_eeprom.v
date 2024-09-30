//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.10.02
//Part Number: GW5AST-LV138PG484AC1/I0
//Device: GW5AST-138
//Device Version: B
//Created Time: Mon Sep 30 20:38:39 2024

module mem_eeprom (douta, doutb, clka, ocea, cea, reseta, wrea, clkb, oceb, ceb, resetb, wreb, ada, dina, adb, dinb);

output [0:0] douta;
output [7:0] doutb;
input clka;
input ocea;
input cea;
input reseta;
input wrea;
input clkb;
input oceb;
input ceb;
input resetb;
input wreb;
input [15:0] ada;
input [0:0] dina;
input [12:0] adb;
input [7:0] dinb;

wire [14:0] dpb_inst_0_douta_w;
wire [0:0] dpb_inst_0_douta;
wire [7:0] dpb_inst_0_doutb_w;
wire [7:0] dpb_inst_0_doutb;
wire [14:0] dpb_inst_1_douta_w;
wire [0:0] dpb_inst_1_douta;
wire [7:0] dpb_inst_1_doutb_w;
wire [7:0] dpb_inst_1_doutb;
wire [14:0] dpb_inst_2_douta_w;
wire [0:0] dpb_inst_2_douta;
wire [7:0] dpb_inst_2_doutb_w;
wire [7:0] dpb_inst_2_doutb;
wire [14:0] dpb_inst_3_douta_w;
wire [0:0] dpb_inst_3_douta;
wire [7:0] dpb_inst_3_doutb_w;
wire [7:0] dpb_inst_3_doutb;
wire dff_q_0;
wire dff_q_1;
wire dff_q_2;
wire dff_q_3;
wire mux_o_0;
wire mux_o_1;
wire mux_o_3;
wire mux_o_4;
wire mux_o_6;
wire mux_o_7;
wire mux_o_9;
wire mux_o_10;
wire mux_o_12;
wire mux_o_13;
wire mux_o_15;
wire mux_o_16;
wire mux_o_18;
wire mux_o_19;
wire mux_o_21;
wire mux_o_22;
wire mux_o_24;
wire mux_o_25;
wire cea_w;
wire ceb_w;
wire gw_gnd;

assign cea_w = ~wrea & cea;
assign ceb_w = ~wreb & ceb;
assign gw_gnd = 1'b0;

DPB dpb_inst_0 (
    .DOA({dpb_inst_0_douta_w[14:0],dpb_inst_0_douta[0]}),
    .DOB({dpb_inst_0_doutb_w[7:0],dpb_inst_0_doutb[7],dpb_inst_0_doutb[6],dpb_inst_0_doutb[5],dpb_inst_0_doutb[4],dpb_inst_0_doutb[3],dpb_inst_0_doutb[2],dpb_inst_0_doutb[1],dpb_inst_0_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[12],adb[11]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7],dinb[6],dinb[5],dinb[4],dinb[3],dinb[2],dinb[1],dinb[0]})
);

defparam dpb_inst_0.READ_MODE0 = 1'b0;
defparam dpb_inst_0.READ_MODE1 = 1'b0;
defparam dpb_inst_0.WRITE_MODE0 = 2'b00;
defparam dpb_inst_0.WRITE_MODE1 = 2'b00;
defparam dpb_inst_0.BIT_WIDTH_0 = 1;
defparam dpb_inst_0.BIT_WIDTH_1 = 8;
defparam dpb_inst_0.BLK_SEL_0 = 3'b000;
defparam dpb_inst_0.BLK_SEL_1 = 3'b000;
defparam dpb_inst_0.RESET_MODE = "SYNC";

DPB dpb_inst_1 (
    .DOA({dpb_inst_1_douta_w[14:0],dpb_inst_1_douta[0]}),
    .DOB({dpb_inst_1_doutb_w[7:0],dpb_inst_1_doutb[7],dpb_inst_1_doutb[6],dpb_inst_1_doutb[5],dpb_inst_1_doutb[4],dpb_inst_1_doutb[3],dpb_inst_1_doutb[2],dpb_inst_1_doutb[1],dpb_inst_1_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[12],adb[11]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7],dinb[6],dinb[5],dinb[4],dinb[3],dinb[2],dinb[1],dinb[0]})
);

defparam dpb_inst_1.READ_MODE0 = 1'b0;
defparam dpb_inst_1.READ_MODE1 = 1'b0;
defparam dpb_inst_1.WRITE_MODE0 = 2'b00;
defparam dpb_inst_1.WRITE_MODE1 = 2'b00;
defparam dpb_inst_1.BIT_WIDTH_0 = 1;
defparam dpb_inst_1.BIT_WIDTH_1 = 8;
defparam dpb_inst_1.BLK_SEL_0 = 3'b001;
defparam dpb_inst_1.BLK_SEL_1 = 3'b001;
defparam dpb_inst_1.RESET_MODE = "SYNC";

DPB dpb_inst_2 (
    .DOA({dpb_inst_2_douta_w[14:0],dpb_inst_2_douta[0]}),
    .DOB({dpb_inst_2_doutb_w[7:0],dpb_inst_2_doutb[7],dpb_inst_2_doutb[6],dpb_inst_2_doutb[5],dpb_inst_2_doutb[4],dpb_inst_2_doutb[3],dpb_inst_2_doutb[2],dpb_inst_2_doutb[1],dpb_inst_2_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[12],adb[11]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7],dinb[6],dinb[5],dinb[4],dinb[3],dinb[2],dinb[1],dinb[0]})
);

defparam dpb_inst_2.READ_MODE0 = 1'b0;
defparam dpb_inst_2.READ_MODE1 = 1'b0;
defparam dpb_inst_2.WRITE_MODE0 = 2'b00;
defparam dpb_inst_2.WRITE_MODE1 = 2'b00;
defparam dpb_inst_2.BIT_WIDTH_0 = 1;
defparam dpb_inst_2.BIT_WIDTH_1 = 8;
defparam dpb_inst_2.BLK_SEL_0 = 3'b010;
defparam dpb_inst_2.BLK_SEL_1 = 3'b010;
defparam dpb_inst_2.RESET_MODE = "SYNC";

DPB dpb_inst_3 (
    .DOA({dpb_inst_3_douta_w[14:0],dpb_inst_3_douta[0]}),
    .DOB({dpb_inst_3_doutb_w[7:0],dpb_inst_3_doutb[7],dpb_inst_3_doutb[6],dpb_inst_3_doutb[5],dpb_inst_3_doutb[4],dpb_inst_3_doutb[3],dpb_inst_3_doutb[2],dpb_inst_3_doutb[1],dpb_inst_3_doutb[0]}),
    .CLKA(clka),
    .OCEA(ocea),
    .CEA(cea),
    .RESETA(reseta),
    .WREA(wrea),
    .CLKB(clkb),
    .OCEB(oceb),
    .CEB(ceb),
    .RESETB(resetb),
    .WREB(wreb),
    .BLKSELA({gw_gnd,ada[15],ada[14]}),
    .BLKSELB({gw_gnd,adb[12],adb[11]}),
    .ADA(ada[13:0]),
    .DIA({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dina[0]}),
    .ADB({adb[10:0],gw_gnd,gw_gnd,gw_gnd}),
    .DIB({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,dinb[7],dinb[6],dinb[5],dinb[4],dinb[3],dinb[2],dinb[1],dinb[0]})
);

defparam dpb_inst_3.READ_MODE0 = 1'b0;
defparam dpb_inst_3.READ_MODE1 = 1'b0;
defparam dpb_inst_3.WRITE_MODE0 = 2'b00;
defparam dpb_inst_3.WRITE_MODE1 = 2'b00;
defparam dpb_inst_3.BIT_WIDTH_0 = 1;
defparam dpb_inst_3.BIT_WIDTH_1 = 8;
defparam dpb_inst_3.BLK_SEL_0 = 3'b011;
defparam dpb_inst_3.BLK_SEL_1 = 3'b011;
defparam dpb_inst_3.RESET_MODE = "SYNC";

DFFRE dff_inst_0 (
  .Q(dff_q_0),
  .D(ada[15]),
  .CLK(clka),
  .CE(cea_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_1 (
  .Q(dff_q_1),
  .D(ada[14]),
  .CLK(clka),
  .CE(cea_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_2 (
  .Q(dff_q_2),
  .D(adb[12]),
  .CLK(clkb),
  .CE(ceb_w),
  .RESET(gw_gnd)
);
DFFRE dff_inst_3 (
  .Q(dff_q_3),
  .D(adb[11]),
  .CLK(clkb),
  .CE(ceb_w),
  .RESET(gw_gnd)
);
MUX2 mux_inst_0 (
  .O(mux_o_0),
  .I0(dpb_inst_0_douta[0]),
  .I1(dpb_inst_1_douta[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_1 (
  .O(mux_o_1),
  .I0(dpb_inst_2_douta[0]),
  .I1(dpb_inst_3_douta[0]),
  .S0(dff_q_1)
);
MUX2 mux_inst_2 (
  .O(douta[0]),
  .I0(mux_o_0),
  .I1(mux_o_1),
  .S0(dff_q_0)
);
MUX2 mux_inst_3 (
  .O(mux_o_3),
  .I0(dpb_inst_0_doutb[0]),
  .I1(dpb_inst_1_doutb[0]),
  .S0(dff_q_3)
);
MUX2 mux_inst_4 (
  .O(mux_o_4),
  .I0(dpb_inst_2_doutb[0]),
  .I1(dpb_inst_3_doutb[0]),
  .S0(dff_q_3)
);
MUX2 mux_inst_5 (
  .O(doutb[0]),
  .I0(mux_o_3),
  .I1(mux_o_4),
  .S0(dff_q_2)
);
MUX2 mux_inst_6 (
  .O(mux_o_6),
  .I0(dpb_inst_0_doutb[1]),
  .I1(dpb_inst_1_doutb[1]),
  .S0(dff_q_3)
);
MUX2 mux_inst_7 (
  .O(mux_o_7),
  .I0(dpb_inst_2_doutb[1]),
  .I1(dpb_inst_3_doutb[1]),
  .S0(dff_q_3)
);
MUX2 mux_inst_8 (
  .O(doutb[1]),
  .I0(mux_o_6),
  .I1(mux_o_7),
  .S0(dff_q_2)
);
MUX2 mux_inst_9 (
  .O(mux_o_9),
  .I0(dpb_inst_0_doutb[2]),
  .I1(dpb_inst_1_doutb[2]),
  .S0(dff_q_3)
);
MUX2 mux_inst_10 (
  .O(mux_o_10),
  .I0(dpb_inst_2_doutb[2]),
  .I1(dpb_inst_3_doutb[2]),
  .S0(dff_q_3)
);
MUX2 mux_inst_11 (
  .O(doutb[2]),
  .I0(mux_o_9),
  .I1(mux_o_10),
  .S0(dff_q_2)
);
MUX2 mux_inst_12 (
  .O(mux_o_12),
  .I0(dpb_inst_0_doutb[3]),
  .I1(dpb_inst_1_doutb[3]),
  .S0(dff_q_3)
);
MUX2 mux_inst_13 (
  .O(mux_o_13),
  .I0(dpb_inst_2_doutb[3]),
  .I1(dpb_inst_3_doutb[3]),
  .S0(dff_q_3)
);
MUX2 mux_inst_14 (
  .O(doutb[3]),
  .I0(mux_o_12),
  .I1(mux_o_13),
  .S0(dff_q_2)
);
MUX2 mux_inst_15 (
  .O(mux_o_15),
  .I0(dpb_inst_0_doutb[4]),
  .I1(dpb_inst_1_doutb[4]),
  .S0(dff_q_3)
);
MUX2 mux_inst_16 (
  .O(mux_o_16),
  .I0(dpb_inst_2_doutb[4]),
  .I1(dpb_inst_3_doutb[4]),
  .S0(dff_q_3)
);
MUX2 mux_inst_17 (
  .O(doutb[4]),
  .I0(mux_o_15),
  .I1(mux_o_16),
  .S0(dff_q_2)
);
MUX2 mux_inst_18 (
  .O(mux_o_18),
  .I0(dpb_inst_0_doutb[5]),
  .I1(dpb_inst_1_doutb[5]),
  .S0(dff_q_3)
);
MUX2 mux_inst_19 (
  .O(mux_o_19),
  .I0(dpb_inst_2_doutb[5]),
  .I1(dpb_inst_3_doutb[5]),
  .S0(dff_q_3)
);
MUX2 mux_inst_20 (
  .O(doutb[5]),
  .I0(mux_o_18),
  .I1(mux_o_19),
  .S0(dff_q_2)
);
MUX2 mux_inst_21 (
  .O(mux_o_21),
  .I0(dpb_inst_0_doutb[6]),
  .I1(dpb_inst_1_doutb[6]),
  .S0(dff_q_3)
);
MUX2 mux_inst_22 (
  .O(mux_o_22),
  .I0(dpb_inst_2_doutb[6]),
  .I1(dpb_inst_3_doutb[6]),
  .S0(dff_q_3)
);
MUX2 mux_inst_23 (
  .O(doutb[6]),
  .I0(mux_o_21),
  .I1(mux_o_22),
  .S0(dff_q_2)
);
MUX2 mux_inst_24 (
  .O(mux_o_24),
  .I0(dpb_inst_0_doutb[7]),
  .I1(dpb_inst_1_doutb[7]),
  .S0(dff_q_3)
);
MUX2 mux_inst_25 (
  .O(mux_o_25),
  .I0(dpb_inst_2_doutb[7]),
  .I1(dpb_inst_3_doutb[7]),
  .S0(dff_q_3)
);
MUX2 mux_inst_26 (
  .O(doutb[7]),
  .I0(mux_o_24),
  .I1(mux_o_25),
  .S0(dff_q_2)
);
endmodule //mem_eeprom
