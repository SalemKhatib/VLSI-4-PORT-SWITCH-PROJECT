# 🔌 4-Port Packet Switch: RTL, Verification & Synthesis

## 📌 Project Overview
A 2-person academic ASIC front-end project for a parameterizable 4-port packet switch, covering RTL design, custom object-oriented SystemVerilog verification, synthesis/optimization, and gate-level simulation.

The design accepts traffic from four independent input ports, buffers packets in per-port FIFOs, arbitrates access to a shared output path, and supports unicast, multicast, and broadcast delivery.

### Project timeline

This repository contains work from two distinct phases:

* **January 2026 — original academic project:** RTL implementation, original SystemVerilog verification flow, Fusion Compiler synthesis/PPA optimization, and gate-level simulation.
* **September 2026 — re-verification and RTL cleanup:** the project was revisited with a stricter scoreboard, which exposed verification blind spots and RTL corner cases. The RTL and scoreboard were corrected and the updated RTL was re-verified with repeated constrained-random regressions.

> **Important:** The synthesis/PPA and gate-level results in Stage C are from the **original January 2026 RTL**. The September 2026 corrected RTL has been re-verified at RTL level, but has **not been re-synthesized**.

---

## ⚙️ Stage A: Architecture & RTL Design

The packet format is 16 bits total:

```text
[ source (4b) | target mask (4b) | data (8b) ]
```

Main RTL blocks:

* **`switch_4port.sv`** — integrates the four input ports, shared arbitration, output mux, and multicast distribution.
* **`switch_port.sv`** — implements per-port FIFO buffering, flow control, and request/transmit FSM behavior.
* **`arbiter.sv`** — round-robin arbitration between competing input ports.
* **`port_if.sv`** — SystemVerilog interface used by the DUT and verification environment.

---

## 🧪 Stage B: SystemVerilog Verification

The DUT is verified with a custom layered object-oriented SystemVerilog environment built without UVM.

### Verification architecture

```text
Sequencer
    |
    v
 Driver ---> DUT ---> Monitor
    |                  |
    +------> Scoreboard <------+
                |
                v
        Functional Coverage
```

The environment includes:

* packet transaction classes with constrained randomization
* sequencers and mailboxes
* drivers and monitors
* reusable per-port verification components
* scoreboard-based prediction and checking
* source × destination functional coverage

### Constrained-random traffic

The packet generator uses the following traffic distribution:

* **70% unicast**
* **20% multicast**
* **10% broadcast**

The main regression generates:

**2,000 input packets per port × 4 ports = 8,000 randomized input packets**

Because multicast and broadcast packets are delivered to multiple destinations, the number of output destination events is larger than the number of generated input packets and varies with the random seed.

---

## ✅ September 2026 Strict Re-Verification

The verification environment was strengthened when the project was revisited in September 2026, and the RTL was re-tested with a stricter scoreboard.

The updated checker now requires all of the following for a PASS:

* every observed output must match an expected transaction
* unexpected or unmatched outputs are counted as failures
* every expected destination transaction must eventually appear
* identical packets are treated as separate valid transactions when multiple copies are expected
* all expected output queues must be empty at the end of the test

A representative 8,000-input constrained-random rerun produced:

```text
Generated input packets:          8000
Expected destination events:      11514
Observed destination events:      11514
Matched destination events:       11514
Unexpected/unmatched events:      0
Missing expected events:          0
Source x destination coverage:    100.00%
STATUS: PASSED
```

The randomized regression was repeated with different destination-event totals due to multicast/broadcast traffic and continued to complete with **zero unexpected outputs and zero missing expected outputs**.

Functional coverage was also re-checked directly in VCS. The source × destination cross reached **100.00%**. A diagnostic run showed that `get_coverage()` reported the aggregate result correctly, while `get_inst_coverage()` returned 0.00% for this covergroup instance, so the final scoreboard reports coverage using:

```systemverilog
coverage_pct = cov.cg_packet.get_coverage();
```

---

## 🔍 Bugs Found During Re-Verification

The stricter regression exposed corner cases that the original checker could miss. The re-verification process led to fixes in both the RTL and testbench.

### Stale registered grant

The round-robin arbiter produces a registered grant. A grant could remain visible briefly after the corresponding request disappeared, allowing stale FIFO data to reach the shared output path.

The output selection is now qualified with the current requests:

```systemverilog
assign active_grants = grants & reqs;
```

Only an actively requesting, currently granted port can drive a valid output transaction.

### FIFO read without ownership of the grant

The original port FSM could advance the FIFO read pointer while in the transmit state even when the port no longer owned the grant.

The corrected behavior is:

```text
grant_i = 1  -> transmit packet -> advance FIFO
grant_i = 0  -> keep packet     -> request again
```

This prevents packets from being discarded during arbitration changes.

### Full-FIFO flow control

FIFO writes are now accepted only when the interface is actually ready:

```systemverilog
assign p_if.ready = (!full || reading);
assign writing    = p_if.valid_in && p_if.ready;
```

This allows safe simultaneous read/write operation while preventing writes into a full FIFO when no real read is occurring.

### Scoreboard robustness

The original scoreboard could silently ignore unexpected packets and did not require all expected queues to drain before reporting success.

The updated scoreboard explicitly checks both directions:

```text
unexpected actual output -> failure
missing expected output  -> failure
```

It also removes duplicate suppression based only on packet field equality, since two independent randomized packets may legitimately contain identical values.

### Functional coverage reporting

The coverage model itself was collecting correctly, but the scoreboard originally queried it with the wrong API for this setup:

```text
get_inst_coverage() -> 0.00%
get_coverage()      -> 100.00%
```

The final report now uses `get_coverage()` and reports the verified **100% source × destination cross coverage**.

---

## 🏭 Stage C: Historical Synthesis & Optimization — January 2026

The original January 2026 RTL was synthesized and optimized using **Synopsys Fusion Compiler** targeting a **32 nm educational technology library**.

> These implementation results correspond to the **pre-fix January RTL**. The September 2026 RTL corrections described above were validated through RTL simulation but were **not re-synthesized**, so the metrics below should not be interpreted as measurements of the current corrected RTL.

Historical implementation results:

| Metric | January 2026 result |
|---|---:|
| Timing target | 5.01 ns |
| Maximum operating frequency | **216.45 MHz** |
| Register clock-gating coverage | **98.32%** |
| Dynamic power | **677 µW → 146 µW** |
| Dynamic power reduction | **78.4%** |
| Total area reduction | **13.8%** |

The January project artifacts also include evidence of **gate-level simulation with SDF back-annotation** and Verdi waveform/debug artifacts for that original implementation.

---

## 📁 Repository Structure

```text
VLSI-4-PORT-SWITCH-PROJECT/
|
|-- RTL/
|   |-- arbiter.sv
|   |-- port_if.sv
|   |-- switch_4port.sv
|   `-- switch_port.sv
|
|-- VERIFICATION/
|   |-- packet_data.sv
|   |-- packet_pkg.sv
|   |-- component_base.sv
|   |-- sequencer.sv
|   |-- driver.sv
|   |-- monitor.sv
|   |-- agent.sv
|   |-- packet_vc.sv
|   |-- scoreboard.sv
|   |-- coverage.sv
|   |-- switch_test.sv
|   `-- vc_test.sv
|
`-- SYNTHESIS/
    `-- January 2026 synthesis / implementation artifacts
```

---

## 🛠️ Tech Stack

* **Language:** SystemVerilog
* **EDA tools used in the project:** Synopsys VCS, Verdi, Fusion Compiler
* **RTL concepts:** FIFOs, FSMs, round-robin arbitration, flow control, multicast/broadcast routing
* **Verification concepts:** constrained-random verification, OOP testbench architecture, sequencers, drivers, monitors, agents, mailboxes, scoreboards, functional coverage
* **Implementation concepts:** SDC constraints, RTL synthesis, Integrated Clock Gating, timing/area/power analysis, gate-level simulation, SDF back-annotation

---

## 🎯 Key Takeaway

The **January 2026 academic project** covered RTL implementation, constrained-random verification, synthesis/PPA optimization, and gate-level simulation.

In **September 2026**, the project was revisited specifically from a verification/debug perspective. A stricter scoreboard exposed weaknesses in the original checker and several RTL corner cases. The RTL and verification environment were corrected, then re-tested with repeated **8,000-input constrained-random regressions**, achieving **zero unexpected outputs, zero missing expected outputs, and 100% source × destination functional coverage**.

The repository therefore contains both the historical January implementation results and the later September RTL/verification corrections; the historical synthesis metrics are intentionally kept separate from the current corrected RTL.