`timescale 1ns/1ps

module vpu_forward_unit_monitor
#(
  parameter LANES = 8,
  parameter EW    = 64,
  parameter VREG  = 5,
  parameter VER   = 4,
  parameter TAGW  = VREG + VER
)(
  // DUT outputs to watch
  input  [LANES*EW-1:0] out_data,
  input  [LANES-1:0]    out_ready_mask,

  // Optional context (if your tool can also feed these)
  input  [TAGW-1:0]     src_tag,
  input  [LANES-1:0]    vrf_ready_mask,
  input  [LANES-1:0]    ex_valid_mask,
  input  [LANES-1:0]    mem_valid_mask,
  input  [LANES-1:0]    wb_valid_mask
);

  // Pretty state dump (pure Verilog-2001)
  task show_state;
    integer i;
  begin
    #1;
    $display("---- MONITOR @%0t ----", $time);
    $display(" src_tag=%0h  ready=%b  VRF=%b  EX=%b  MEM=%b  WB=%b",
             src_tag, out_ready_mask, vrf_ready_mask, ex_valid_mask, mem_valid_mask, wb_valid_mask);
    $write  (" L7..L0 = {");
    for (i = LANES-1; i >= 0; i = i - 1) begin
      $write("%h", out_data[i*EW +: EW]);
      if (i > 0) $write(",");
    end
    $write("}\n");
  end
  endtask

  // Sample periodically (or call from tool)
  initial begin
    forever begin
      #5; show_state();
    end
  end

endmodule