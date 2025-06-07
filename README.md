# cache-design-core-sv
# RTL Cache Design Project (SystemVerilog)

## Overview
This project is an in-progress RTL implementation of a parameterized multi-way set-associative cache with an age-based Least Recently Used (LRU) eviction policy. The design targets simulation and formal verification environments and is written in SystemVerilog.

## Status: 🚧 Not Yet Functional
- Code does **not yet compile**.
- Modules are being built incrementally and integration is ongoing.

## Design Goals
- Support for N-way set-associative caches (parameterized)
- Modular RTL structure for easy testing and extension
- Formal verification of LRU eviction policy

## Modules (So Far)
- **`way.sv`**: Stores tag, valid bit, age; updates age on access
- **`lru_eviction.sv`**: Identifies least recently used way based on age
- **`controller.sv`**: Orchestrates read/write ops, tag comparisons, and updates
- **`way_search.sv`**: Handles hit/miss detection across all ways

## Planned Verification
- **Simulation**: Synopsys VCS (or ModelSim)
- **Formal Checks**: Using Yosys to validate correctness of LRU policy

## To Do
- Complete and debug module interconnects
- Resolve syntax and interface mismatches
- Add basic testbenches
- Document parameter and signal specifications

## Tools
- Language: SystemVerilog
- Version Control: Git
- Planned Tools: Synopsys VCS, GTKWave, Yosys

---

## Notes
This project is part of a research initiative to explore dynamic cache behavior and age-based replacement logic in CPU microarchitecture design.
