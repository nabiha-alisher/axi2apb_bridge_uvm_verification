# axi2apb_bridge_uvm_verification


Two agents, one scoreboard, functional coverage, SVA checkers, 16 tests, two data-width builds.

```
tb_top ── clk/rst, DUT (axi2apb_wrap), AXI_BUS, APB_BUS, SVA checkers
 └─ uvm_test
     └─ axi2apb_env
         ├─ axi_agent   (active)  sequencer + driver + monitor     → AXI master side
         ├─ apb_agent   (active)  slave: seq_item → sequence → sequencer → driver, + monitor → APB slave side
         ├─ axi2apb_scoreboard    reference model + checks
         └─ axi2apb_coverage      AXI + APB covergroups
```

## Build / run
```
cd sim
make SIM=vcs    DW=32 TEST=axi2apb_smoke_test      # 32 -> 32 bridge (axi2apb)
make SIM=questa DW=64 TEST=axi2apb_burst_test      # 64 -> 32 bridge (axi2apb_64_32)
make SIM=xrun   regress                            # every test, both widths
```
`DW` becomes `+define+AXI_DATA_WIDTH`, which selects the bridge inside `axi2apb_wrap`.

**RTL note.** The original files `include` each other without guards (duplicate modules) and
`axi2apb_wrap.sv` includes itself. `rtl/` holds your files unchanged except for the removed
`` `include `` lines; `sim/files.f` lists them in compile order.



Burst tests print a skip message on the 32-bit build (that bridge ignores AxLEN).

## What is checked
* Scoreboard (spec-level model): number, order, address, direction and data of every APB access
  per AXI transaction (two APB accesses per 64-bit beat, zero-strobe words skipped); BID/RID echo,
  RLAST position, beat count, BRESP/RRESP, RDATA assembled from the APB PRDATA; leftover
  transactions at end of test (hang detection).
* SVA: VALID/payload stability on all five AXI channels, X checks, responses without requests,
  APB hold-during-wait. `STRICT_SETUP` (APB setup phase before PENABLE) is off by default.

## Things I expect the tests to flag — from reading the RTL, NOT yet confirmed in simulation
These are model-vs-RTL differences; confirm each in simulation before filing as a bug.
1. `axi2apb_64_32` burst write, first beat with APB wait states: `WAIT_W_PREADY` samples AW without
   `incr_AWADDR`, so the second word of beat 0 looks like it is written to the wrong address. (`burst_wait`)
2. `BURST_WR`: if the next W beat is not yet valid the FSM moves to `BURST_WR_64` and the high
   word is written before the low word. (`burst_wgap`)
3. Burst reads: the first read goes to `BURST_RD_64` without incrementing the address, and
   `RLAST` depends on `ARLEN_Q` which counts 32-bit words; I could not make the sequence line up
   on paper. (`burst`)
4. Single 64-bit writes always write both words regardless of WSTRB (`strobe`).
5. `PSLVERR` is never mapped to SLVERR (`slverr`).
6. PSEL is tied high and PENABLE is not preceded by a setup phase (visible with `STRICT_SETUP=1`).

## Files
```
rtl/        your design (includes stripped)
tb/axi/     item, cfg, driver, monitor, agent
tb/apb/     apb_seq_item, apb_sequence, apb_sequencer, apb_driver, apb_monitor, apb_agent, cfg
tb/env/     env_cfg, scoreboard, coverage, env
tb/seq/     sequences          tb/tests/  tests
tb/top/     tb_top, protocol_checkers
sim/        files.f, Makefile
```

## APB slave agent: how the pieces connect
```
apb_slave_seq (forever loop, default sequence of the sequencer)
   │  start_item / randomize / finish_item    one apb_seq_item per APB access
   ▼
apb_sequencer ──► apb_driver ──► APB_BUS: pready / prdata / pslverr   (DUT drives psel / penable / paddr ...)
                      │  fills the item with addr / write / wdata / rdata, item_done()
                      ▼
                  slave memory
apb_monitor ── apb_item ──► scoreboard, coverage
```
Choose the slave behaviour per test by overriding `apb_slave_response_type()`:
`apb_slave_seq` (knobs in `apb_agent_cfg`), `apb_zero_wait_slave_seq`, `apb_slow_slave_seq`,
`apb_error_slave_seq`, `apb_stuck_slave_seq`.
>>>>>>> dc76ece (AXI2APB Updated Project Files)
