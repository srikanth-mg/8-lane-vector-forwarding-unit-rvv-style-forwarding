`timescale 1ns/1ps

// ===================================================================
// Stimulus: drives the DUT inputs (pure Verilog-2001, no SV features)
// ===================================================================
module vpu_forward_unit_stimulus
#(
  parameter LANES = 8,
  parameter EW    = 64,
  parameter VREG  = 5,           // 32 VRs
  parameter VER   = 4,           // version bits
  parameter TAGW  = VREG + VER
)(
  // DUT inputs (driven by this module)
  output [TAGW-1:0]     src_tag,
  output [LANES-1:0]    active_mask,

  output [LANES*EW-1:0] vrf_data,
  output [LANES-1:0]    vrf_ready_mask,

  output [TAGW-1:0]     ex_tag,
  output [LANES-1:0]    ex_valid_mask,
  output [LANES*EW-1:0] ex_data,

  output [TAGW-1:0]     mem_tag,
  output [LANES-1:0]    mem_valid_mask,
  output [LANES*EW-1:0] mem_data,

  output [TAGW-1:0]     wb_tag,
  output [LANES-1:0]    wb_valid_mask,
  output [LANES*EW-1:0] wb_data
);

  // ---------------- Drive regs behind the outputs ----------------
  reg [TAGW-1:0]     src_tag_r;         assign src_tag        = src_tag_r;
  reg [LANES-1:0]    active_mask_r;     assign active_mask    = active_mask_r;

  reg [LANES*EW-1:0] vrf_data_r;        assign vrf_data       = vrf_data_r;
  reg [LANES-1:0]    vrf_ready_mask_r;  assign vrf_ready_mask = vrf_ready_mask_r;

  reg [TAGW-1:0]     ex_tag_r;          assign ex_tag         = ex_tag_r;
  reg [LANES-1:0]    ex_valid_mask_r;   assign ex_valid_mask  = ex_valid_mask_r;
  reg [LANES*EW-1:0] ex_data_r;         assign ex_data        = ex_data_r;

  reg [TAGW-1:0]     mem_tag_r;         assign mem_tag        = mem_tag_r;
  reg [LANES-1:0]    mem_valid_mask_r;  assign mem_valid_mask = mem_valid_mask_r;
  reg [LANES*EW-1:0] mem_data_r;        assign mem_data       = mem_data_r;

  reg [TAGW-1:0]     wb_tag_r;          assign wb_tag         = wb_tag_r;
  reg [LANES-1:0]    wb_valid_mask_r;   assign wb_valid_mask  = wb_valid_mask_r;
  reg [LANES*EW-1:0] wb_data_r;         assign wb_data        = wb_data_r;

  integer i;
  reg [31:0]  i32;              // 32-bit mirror of loop index
  reg [EW-1:0] lane64;          // zero-extended 64-bit version of i32

  // ---------------- Test sequence ----------------
  initial begin
    // defaults
    active_mask_r     = {LANES{1'b1}}; // all lanes active
    src_tag_r         = {TAGW{1'b0}};
    vrf_data_r        = {LANES*EW{1'b0}};
    vrf_ready_mask_r  = {LANES{1'b0}};
    ex_tag_r          = {TAGW{1'b0}};
    ex_valid_mask_r   = {LANES{1'b0}};
    ex_data_r         = {LANES*EW{1'b0}};
    mem_tag_r         = {TAGW{1'b0}};
    mem_valid_mask_r  = {LANES{1'b0}};
    mem_data_r        = {LANES*EW{1'b0}};
    wb_tag_r          = {TAGW{1'b0}};
    wb_valid_mask_r   = {LANES{1'b0}};
    wb_data_r         = {LANES*EW{1'b0}};

    // src_tag = {vreg, ver}; expect vreg=19, ver=5
    src_tag_r = {5'd19, 4'd5};

    // 1) nothing ready
    #5;

    // 2) VRF lanes 0..3 ready with (0x100 + lane)
    vrf_ready_mask_r = 8'b0000_1111;
    for (i = 0; i < LANES; i = i + 1) begin
      i32    = i;                                // cast integer -> 32-bit reg
      lane64 = {{(EW-32){1'b0}}, i32};           // zero-extend to EW
      if (vrf_ready_mask_r[i])
        vrf_data_r[i*EW +: EW] = 64'h0000_0000_0000_0100 + lane64;
      else
        vrf_data_r[i*EW +: EW] = {EW{1'b0}};
    end
    #5;

    // 3) EX matches lanes 4..7 with (0x200 + lane)
    ex_tag_r        = src_tag_r;
    ex_valid_mask_r = 8'b1111_0000;
    for (i = 4; i < 8; i = i + 1) begin
      i32    = i;
      lane64 = {{(EW-32){1'b0}}, i32};
      ex_data_r[i*EW +: EW] = 64'h0000_0000_0000_0200 + lane64;
    end
    #5;

    // 4) MEM matches lanes 2,3 with (0x555 + lane) (override VRF on those)
    mem_tag_r        = src_tag_r;
    mem_valid_mask_r = 8'b0000_1100;
    mem_data_r[2*EW +: EW] = 64'h0000_0000_0000_0555 + 64'd2;
    mem_data_r[3*EW +: EW] = 64'h0000_0000_0000_0555 + 64'd3;
    #5;

    // 5) WB matches lane1 with 0x777 (override VRF lane1)
    wb_tag_r        = src_tag_r;
    wb_valid_mask_r = 8'b0000_0010;
    wb_data_r[1*EW +: EW] = 64'h0000_0000_0000_0777;
    #5;

    // 6) EX and MEM both valid on lanes 4..7
    //    MEM data should WIN over EX (because WB > MEM > EX > VRF)
    ex_tag_r        = src_tag_r;
    mem_tag_r       = src_tag_r;
    ex_valid_mask_r  = 8'b1111_0000;
    mem_valid_mask_r = 8'b1111_0000;
    for (i = 4; i < 8; i = i + 1) begin
      i32    = i;
      lane64 = {{(EW-32){1'b0}}, i32};
      // older EX data
      ex_data_r[i*EW +: EW]  = 64'h0000_0000_0000_0200 + lane64;
      // newer MEM data (should be selected by DUT)
      mem_data_r[i*EW +: EW] = 64'h0000_0000_0000_0555 + lane64;
    end
    #10;

    // 7) WB overlaps MEM/EX on lanes 5 and 6 – WB must WIN over both
    wb_tag_r        = src_tag_r;
    wb_valid_mask_r = 8'b0110_0000;          // lanes 5,6
    wb_data_r[5*EW +: EW] = 64'h0000_0000_0000_0775;
    wb_data_r[6*EW +: EW] = 64'h0000_0000_0000_0776;
    #5;

    // 8) Change version → forwards no longer match; only VRF lanes 0..3 ready
    src_tag_r = {5'd19, 4'd6};
    vrf_ready_mask_r = 8'b0000_1111;
    for (i = 0; i < LANES; i = i + 1) begin
      i32    = i;                                // cast integer -> 32-bit reg
      lane64 = {{(EW-32){1'b0}}, i32};           // zero-extend to EW
      if (vrf_ready_mask_r[i])
        vrf_data_r[i*EW +: EW] = 64'h0000_0000_0000_0100 + lane64;
      else
        vrf_data_r[i*EW +: EW] = {EW{1'b0}};
    end
    #5;

    $display("Stimulus completed.");
    $finish;
  end

endmodule