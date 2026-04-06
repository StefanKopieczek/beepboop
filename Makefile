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
	verilator --binary --trace-fst --timing -Wno-fatal verilator.vlt \
		$(addprefix -I,$(shell find $(RTL_DIR) -type d)) \
		--top-module tb_$* \
		-o $(abspath $@) --Mdir $(SIM_DIR)/obj_$* \
		$(RTL_SRC) $<
	$@

wave-%: $(SIM_DIR)/tb_%
	gtkwave $(SIM_DIR)/tb_$*.fst &

lint-rtl:
	verilator --lint-only --no-timing -Wno-MULTITOP verilator.vlt \
		$(addprefix -I,$(shell find $(RTL_DIR) -type d)) $(RTL_SRC)

lint-tests:
	verilator --lint-only --timing -Wno-MULTITOP verilator.vlt \
		$(addprefix -I,$(shell find $(RTL_DIR) -type d)) $(RTL_SRC) $(TB_SRC)

lint: lint-rtl lint-tests

format:
	verible-verilog-format --inplace $(RTL_SRC) $(TB_SRC)

clean:
	rm -rf $(SIM_DIR)/*.fst $(SIM_DIR)/tb_* build/

.PHONY: sim lint lint-rtl lint-tests format clean