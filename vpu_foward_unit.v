`timescale 1ns/1ps

module vpu_forward_unit #(
    parameter integer LANES      = 8,   // lanes per vector register
    parameter integer EW         = 64,  // element width (bits)
    parameter integer VREG_BITS  = 5,   // 32 VRs -> 5 bits
    parameter integer VER_BITS   = 4    // version id bits (bcoz data can be forwarded from Vregister file or execute or memory or writeback stage)
)(
    // Consumer expects this source tag to compare & get the data
    input      [VREG_BITS+VER_BITS-1:0] src_tag,

    // Active lanes (mask/VL)
    input      [LANES-1:0]              active_mask,

    // VRF fallback (if the data is from vector register file)
    input      [LANES*EW-1:0]           vrf_data,
    input      [LANES-1:0]              vrf_ready_mask,

    // EX forward bus (if it's from execute side)
    input      [VREG_BITS+VER_BITS-1:0] ex_tag,
    input      [LANES-1:0]              ex_valid_mask,
    input      [LANES*EW-1:0]           ex_data, // means [63:0] from each lane. since there are 8 lanes, then total data which will be transfered from there is declared. kind off defines entire bus width. 

    // MEM forward bus (if it's from memory access)
    input      [VREG_BITS+VER_BITS-1:0] mem_tag,
    input      [LANES-1:0]              mem_valid_mask,
    input      [LANES*EW-1:0]           mem_data,

    // WB forward bus (if it's from writeback stage)
    input      [VREG_BITS+VER_BITS-1:0] wb_tag,
    input      [LANES-1:0]              wb_valid_mask,
    input      [LANES*EW-1:0]           wb_data, 

    // Outputs
    output reg [LANES*EW-1:0]           out_data,       // per-lane selected data
    output reg [LANES-1:0]              out_ready_mask  // lanes ready this cycle
);

    // Tag compare (checking whether the tag is getting matched or not)
    wire ex_match  = (ex_tag  == src_tag);
    wire mem_match = (mem_tag == src_tag);
    wire wb_match  = (wb_tag  == src_tag);

    integer l;

    // Per-lane combinational select and ready
    always @* begin
		//initially, kept as zero
        out_data       = {LANES*EW{1'b0}}; 
        out_ready_mask = {LANES{1'b0}};
		
        for (l = 0; l < LANES; l = l + 1) begin : per_lane
            reg [EW-1:0] sel_data;
            reg          lane_ready;

            sel_data   = vrf_data[l*EW +: EW]; // default
            lane_ready = 1'b0; //intializing zero before starting. 

	   if (active_mask[l]) begin
                // Highest priority: WB (latest in pipeline)
                if (wb_match && wb_valid_mask[l]) begin
                    sel_data   = wb_data[l*EW +: EW];
                    lane_ready = 1'b1;
                end
                // Then MEM
                else if (mem_match && mem_valid_mask[l]) begin
                    sel_data   = mem_data[l*EW +: EW];
                    lane_ready = 1'b1;
                end
                // Then EX
                else if (ex_match && ex_valid_mask[l]) begin
                    sel_data   = ex_data[l*EW +: EW];
                    lane_ready = 1'b1;
                end
                // Fallback: VRF
                else if (vrf_ready_mask[l]) begin
                    sel_data   = vrf_data[l*EW +: EW];
                    lane_ready = 1'b1;
                end
            end

            out_data[l*EW +: EW] = sel_data; // kind of slice selector - i.e. choosing which lane's data need to been store and also tells from which bit to start and end
            out_ready_mask[l]    = lane_ready;
        end
    end

endmodule