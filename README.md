# 🔌 4-Port Packet Switch: RTL, Verification & Synthesis

## 📌 Project Overview
A 2-person academic ASIC front-end project for a parameterizable 4-port packet switch, covering RTL design, custom object-oriented SystemVerilog verification, synthesis/optimization, and gate-level simulation.

The design accepts traffic from four independent input ports, buffers packets in per-port FIFOs, arbitrates access to a shared output path, and supports unicast, multicast, and broadcast delivery.

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

## ✅ Strict Re-Verification

The verification environment was later strengthened and the RTL was re-tested with a stricter scoreboard.

The updated checker now requires all of the following for a PASS:

* every observed output must match an expected transaction
* unexpected or unmatched outputs are counted as failures
* every expected destination transaction must eventually appear
* identical packets are treated as separate valid transactions when multiple copies are expected
* all expected output queues must be empty at the end of the test

A representative 8,000-input constrained-random rerun produced:

```text
Generated input packets:          8000
Expected destination events:      11723
Observed destination events:      11723
Matched destination events:       11723
Unexpected/unmatched events:      0
Missing expected events:          0
STATUS: PASSED
```

The randomized regression was repeated with different destination-event totals due to multicast/broadcast traffic and continued to complete with **zero unexpected outputs and zero missing expected outputs**.

Archived project documentation also reports **100% source/destination cross coverage** from the original project verification flow.

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

---

## 🏭 Stage C: Logic Synthesis & Optimization

The RTL was synthesized using **Synopsys Fusion Compiler** targeting a **32 nm educational technology library**.

Key implementation results:

| Metric | Result |
|---|---:|
| Timing target | 5.01 ns |
| Maximum operating frequency | **216.45 MHz** |
| Register clock-gating coverage | **98.32%** |
| Dynamic power | **677 µW → 146 µW** |
| Dynamic power reduction | **78.4%** |
| Total area reduction | **13.8%** |

The project also includes evidence of **gate-level simulation with SDF back-annotation** and Verdi waveform/debug artifacts.

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
    `-- synthesis / implementation artifacts
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

This project covers the complete student front-end flow from **RTL architecture and implementation**, through **constrained-random verification and scoreboard debugging**, to **synthesis, PPA optimization, and gate-level simulation**.

The later strict re-verification was especially useful for exposing subtle arbitration/FIFO corner cases and improving both the RTL and the verification methodology.