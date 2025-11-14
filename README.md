## 📘 8-Lane Vector Forwarding Unit — RISC-V Vector Processor (RVV-Style Forwarding)

A fully combinational per-lane data forwarding engine with correct pipeline priority (WB > MEM > EX > VRF).

## ⭐ Overview

This project implements a vector data-forwarding unit for a custom RISC-V Vector Processor Unit (VPU).
The forwarding unit is designed to resolve read-after-write (RAW) hazards between:

- Vector Register File (VRF)
- Execute Stage (EX)
- Memory Stage (MEM)
- Writeback Stage (WB)

Unlike scalar pipelines, the vector forwarding unit operates per lane (8 lanes × 64-bit each), enabling lane-wise forwarding based on validity masks.
This design is fully combinational, supports tag-based matching, and implements the correct RISC-V forwarding priority:

🟩 WB > MEM > EX > VRF
- This ensures the consumer instruction always receives the most recent value available anywhere in the pipeline.

## 🧩 Key Features

🔹 8 lanes, each 64 bits
Supports 512-bit vector width with independent lane forwarding.

🔹 Tag-based forwarding
Each producer tag = {vreg, ver}
Each consumer tag = {vreg, ver}
Forwarding occurs only when tags match.

🔹 Per-lane valid masks
Each stage can forward different lanes in the same cycle:

- ex_valid_mask  : 8 bits
- mem_valid_mask : 8 bits
- wb_valid_mask  : 8 bits
- vrf_ready_mask : 8 bits

🔹 Priority-based selection (hardware accurate)

If multiple stages have valid data for the same lane:
1. Writeback (newest)
2. Memory
3. Execute
4. Register File (fallback)

🔹 Full Verilator testbench

Covers all cases:
- VRF only
- EX forwarding
- MEM overrides EX
- WB overrides MEM & EX
- Conflicting masks
- Version mismatch resets forwarding
- Per-lane zero-extension handling

## 🛠️ Architecture

- Each cycle, the forwarding unit:
- Compares src_tag with EX / MEM / WB tags

For each lane:
- Checks valid masks
- Selects the newest data source
- Outputs lane-ready mask bit

The full selection is:

- if (wb_match  && wb_valid_mask[l]) sel_data = wb_data;
- else if (mem_match && mem_valid_mask[l]) sel_data = mem_data;
- else if (ex_match  && ex_valid_mask[l])  sel_data = ex_data;
- else if (vrf_ready_mask[l])              sel_data = vrf_data;

## 🧪 Simulation & Testing
Build using Verilator & run the simulation

## 🧠 Why Priority WB > MEM > EX > VRF?
1️⃣ WB has the newest architectural updates
- Instruction already passed through pipeline.

2️⃣ MEM wrote values closer to completion than EX
- Used when load/store instructions write vectors.

3️⃣ EX results are newer than VRF
- ALU operations performed directly on lanes.

4️⃣ VRF is fallback if no stage is producing newer data
Useful when:
- no RAW hazard
- version mismatches
- pipeline stalls

## 📚 References

- Patterson & Hennessy – Computer Organization and Design, 4th Edition
- RISC-V Vector Specification v1.0
- Berkeley BOOM/RoCC documentation
- Imperas Vector ISA test framework

## ✨ Future Work

- Features planned for next version:
- Support 128-bit or 256-bit lanes
- Out-of-order vector execution (per-lane scoreboard)
- Integration with vector ALU pipeline

## 👨‍💻 Author
Srikanth Muthuvel Ganthimathi
SUNY Binghamton 
