RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim

PKG_SRC = $(shell find $(RTL_DIR) -name '*_pkg.sv')
RTL_SRC = $(PKG_SRC) $(shell find $(RTL_DIR) -name '*.sv' ! -name '*_pkg.sv')
TB_SRC = $(shell find $(TB_DIR) -name 'tb_*.sv')
TB_TARGETS = $(patsubst $(TB_DIR)/tb_%.sv,$(SIM_DIR)/tb_%,$(TB_SRC))

sim: $(TB_TARGETS)

$(SIM_DIR)/tb_%: $(TB_DIR)/tb_%.sv $(RTL_SRC)
	echo "$(TB_TARGETS)"
	@mkdir -p $(SIM_DIR)
	iverilog -g2012 -o $@ -I $(RTL_DIR) $(RTL_SRC) $< 
	vvp $@

wave-%: $(SIM_DIR)/tb_%
	gtkwave $(SIM_DIR)/tb_$*.vcd &

lint:	
	verilator --lint-only -Wno-MULTITOP $(addprefix -I,$(shell find $(RTL_DIR) -type d)) $(RTL_SRC)

format:
	verible-verilog-format --inplace $(RTL_SRC) $(TB_SRC)

clean:
	rm -rf $(SIM_DIR)/*.vcd $(SIM_DIR)/tb_* build/

.PHONY: sim lint format clean