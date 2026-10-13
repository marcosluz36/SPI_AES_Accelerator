# --- Directory Tree --- 
RTL_DIR = rtl
TB_DIR = tb
SYN_DIR = syn

# --- Project Files ---
RTL_FILES = \
	../$(RTL_DIR)/common/deserializer.sv

TB_FILES = \
	../$(TB_DIR)/tb_deserializer.sv

TOP = tb_deserializer

TIMESCALE = 1ns/1ps

# --- Tools Flags ---
VLOGAN_FLAGS = -full64 \
               -sverilog \
               -kdb \
               +lint=all

VCS_FLAGS = -full64 \
            -timescale=$(TIMESCALE) \
            -debug_access+all \
            -kdb

# --- Make commands ---
.PHONY: syntax compile run waveform clean

syntax:
	mkdir -p $(SYN_DIR)
	cd $(SYN_DIR) && \
	vlogan $(VLOGAN_FLAGS) \
				 $(RTL_FILES) \
				 $(TB_FILES) \
				 -l syntax.log

compile: syntax
	cd $(SYN_DIR) && \
	vcs $(VCS_FLAGS) -sverilog \
	    $(RTL_FILES) \
	    $(TB_FILES) \
	    -top $(TOP) \
	    -o simv \
	    -l compile.log

run: compile
	cd $(SYN_DIR) && ./simv

run_gui: compile
	cd $(SYN_DIR) && ./simv -gui

waveform: run
	cd $(SIM_DIR) && \
	verdi -ssf waves.fsdb -sswr tb_deserializer.vcd

