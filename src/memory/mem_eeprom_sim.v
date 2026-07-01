// Simulation-only Verilog model for mem_eeprom (replaces Gowin IP for Verilator builds)
// Original: 8KB dual-port RAM:
//   Port A: 16-bit addr, 1-bit data (64K bits = 8KB) - used by GBA eeprom bit-serial access
//   Port B: 13-bit addr, 8-bit data (8KB)             - used by picorv32 for save/load

module mem_eeprom (
    output reg [0:0]  douta,
    output reg [7:0]  doutb,
    input             clka,
    input             ocea,
    input             cea,
    input             reseta,
    input             wrea,
    input             clkb,
    input             oceb,
    input             ceb,
    input             resetb,
    input             wreb,
    input      [15:0] ada,
    input      [0:0]  dina,
    input      [12:0] adb,
    input      [7:0]  dinb
);

// 8KB = 8192 bytes of storage
// Port A is 1-bit wide × 64K = 64K bits
// Port B is 8-bit wide × 8K = 64K bits (same underlying storage)
// We model as a byte-addressable 8192-byte RAM, with port A doing bit-level access

reg [7:0] mem [0:8191] /* verilator public */;

// Port A: 1-bit access, addr[15:0], addr[15:3] = byte index, addr[2:0] = bit index
always @(posedge clka) begin
    if (reseta) begin
        douta <= 1'b0;
    end else if (cea) begin
        if (wrea) begin
            mem[ada[15:3]][ada[2:0]] <= dina[0];
        end
        douta <= mem[ada[15:3]][ada[2:0]];
    end
end

// Port B: 8-bit byte access, addr[12:0] = byte index
always @(posedge clkb) begin
    if (resetb) begin
        doutb <= 8'h00;
    end else if (ceb) begin
        if (wreb) begin
            mem[adb] <= dinb;
        end
        doutb <= mem[adb];
    end
end

endmodule
