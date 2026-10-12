# Usage:
#   make SIM=vcs|questa|xrun DW=32|64 TEST=axi2apb_smoke_test [WAVES=1] [SEED=1]
#   make regress SIM=...            (all tests, both widths)
SIM   ?= vcs
DW    ?= 32
TEST  ?= axi2apb_smoke_test
SEED  ?= 1
WAVES ?= 0
VERB  ?= UVM_MEDIUM

PLUS  = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERB) +ntb_random_seed=$(SEED)
ifeq ($(WAVES),1)
PLUS += +WAVES
endif
BUILD = build_$(SIM)_dw$(DW)

TESTS = axi2apb_smoke_test axi2apb_single_test axi2apb_pipelined_test axi2apb_apb_wait_test \
        axi2apb_backpressure_test axi2apb_order_test axi2apb_rw_collision_test \
        axi2apb_readback_test axi2apb_narrow_test axi2apb_strobe_test axi2apb_burst_test \
        axi2apb_burst_wait_test axi2apb_burst_wgap_test axi2apb_slverr_test \
        axi2apb_reset_test axi2apb_random_test

.PHONY: run compile regress clean

run: compile
ifeq ($(SIM),vcs)
	cd $(BUILD) && ./simv $(PLUS) -l run_$(TEST).log
endif
ifeq ($(SIM),questa)
	cd $(BUILD) && vsim -c -sv_seed $(SEED) work.tb_top $(PLUS) -do "run -all; quit -f" -l run_$(TEST).log
endif
ifeq ($(SIM),xrun)
	cd $(BUILD) && xrun -R -svseed $(SEED) $(PLUS) -l run_$(TEST).log
endif

compile:
	mkdir -p $(BUILD)
ifeq ($(SIM),vcs)
	cd $(BUILD) && vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
	    +define+AXI_DATA_WIDTH=$(DW) -f ../files.f -debug_access+r -l comp.log -o simv
endif
ifeq ($(SIM),questa)
	cd $(BUILD) && vlib work && vlog -sv -timescale 1ns/1ps +define+AXI_DATA_WIDTH=$(DW) \
	    -L $${UVM_HOME:-$$QUESTA_HOME/verilog_src/uvm-1.2} -f ../files.f -l comp.log
endif
ifeq ($(SIM),xrun)
	cd $(BUILD) && xrun -compile -elaborate -uvm -sv -timescale 1ns/1ps \
	    +define+AXI_DATA_WIDTH=$(DW) -f ../files.f -l comp.log
endif

regress:
	@for dw in 32 64; do \
	  $(MAKE) --no-print-directory compile SIM=$(SIM) DW=$$dw || exit 1; \
	  for t in $(TESTS); do \
	    $(MAKE) --no-print-directory run SIM=$(SIM) DW=$$dw TEST=$$t > /dev/null 2>&1; \
	    log=build_$(SIM)_dw$$dw/run_$$t.log; \
	    errs=$$(grep -E "^UVM_(ERROR|FATAL) :" $$log | awk '{s+=$3} END{print s+0}'); \
	    echo "DW=$$dw  $$t : UVM_ERROR+FATAL = $$errs"; \
	  done; \
	done

clean:
	rm -rf build_* *.log *.vcd
