RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim

PKG_SRC = $(shell find $(RTL_DIR) -name '*_pkg.sv')
RTL_SRC = $(PKG_SRC) $(shell find $(RTL_DIR) -name '*.sv' ! -name '*_pkg.sv')
TB_SRC = $(shell find $(TB_DIR) -name 'tb_*.sv')
TB_TARGETS = $(patsubst $(TB_DIR)/tb_%.sv,$(SIM_DIR)/tb_%,$(TB_SRC))

sim: $(TB_TARGETS)

$(SIM_DIR)/tb_%: $(TB_DIR)/tb_%.sv $(RTL_SRC)
	@mkdir -p $(SIM_DIR)
	verilator --binary --trace-fst -Wno-fatal -Wno-TIMESCALEMOD \
		$(addprefix -I,$(shell find $(RTL_DIR) -type d)) \
		--top-module tb_$* \
		-o $(abspath $@) --Mdir $(SIM_DIR)/obj_$* \
		$(RTL_SRC) $<
	$@

wave-%: $(SIM_DIR)/tb_%
	gtkwave $(SIM_DIR)/tb_$*.fst &

lint:	
	verilator --lint-only -Wno-MULTITOP $(addprefix -I,$(shell find $(RTL_DIR) -type d)) $(RTL_SRC)

format:
	verible-verilog-format --inplace $(RTL_SRC) $(TB_SRC)

clean:
	rm -rf $(SIM_DIR)/*.fst $(SIM_DIR)/tb_* build/

.PHONY: sim lint format clean