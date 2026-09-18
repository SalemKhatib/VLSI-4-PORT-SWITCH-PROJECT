# 🔌 4-Port Packet Switch: RTL to Gate-Level Synthesis

### 📌 Project Overview
A 2-person academic ASIC front-end project for a parameterizable 4-port packet switch, covering RTL design, custom object-oriented SystemVerilog verification, synthesis/optimization, and gate-level simulation.

---

### ⚙️ Stage A: Architecture & RTL Design
The hardware routes 16-bit packets between four independent input/output ports through shared switching logic.

* **Top level:** `switch_4port.sv` integrates four switch ports, shared arbitration, and output distribution.
* **Buffering/control:** Each input port uses FIFO buffering and FSM-based flow control.
* **Arbitration:** Contention is resolved using round-robin arbitration.

### 🧪 Stage B: SystemVerilog Verification
The DUT was verified with a custom layered OOP SystemVerilog environment.

* **Layered testbench:** Sequencers, drivers, monitors, agents, mailboxes, and scoreboard-based checking.
* **Constrained-random traffic:** 70% unicast, 20% multicast, and 10% broadcast traffic distribution.
* **Test size:** The submitted regression launches **2,000 generated input packets per port (8,000 total input packets)**.
* **Functional coverage:** Archived project documentation reports **100% source/destination cross coverage**.
* **Scoreboarding:** Archived runs report **0 mismatches**; historical match totals vary across runs, so no single output-transaction count is presented here as the canonical result.

> Note: Earlier portfolio/CV versions quoted **12,081 packets**. The original source of that exact historical number is no longer traceable in the surviving artifacts, so the repository now uses only directly reproducible/documented counts.

### 🏭 Stage C: Logic Synthesis & Optimization
The RTL was synthesized using Synopsys Fusion Compiler targeting a 32 nm educational technology library.

* **Timing target:** 5.01 ns clock period under the slow corner.
* **Clock gating:** Integrated Clock Gating was applied across 98.32% of registers.
* **Power:** Dynamic power reduced from 677 µW to 146 µW (**78.4% reduction**).
* **Area:** Total area reduced by **13.8%**.
* **Performance:** Reported theoretical maximum operating frequency: **216.45 MHz**.
* **Gate-level simulation:** The project includes evidence of gate-level simulation with SDF back-annotation and Verdi waveform/debug artifacts.

### 🛠️ Tech Stack
* **Language:** SystemVerilog
* **EDA tools used in the project:** Synopsys VCS, Verdi, Fusion Compiler
* **Concepts:** FIFO buffering, round-robin arbitration, FSMs, constrained-random verification, OOP testbench architecture, mailboxes, scoreboard checking, functional coverage, clock gating, gate-level simulation, SDF back-annotation
