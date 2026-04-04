RTL_DIR = rtl
TB_DIR  = tb
SIM_DIR = sim

RTL_SRC = $(shell find $(RTL_DIR) -name '*.sv')
TB_SRC = $(shell find $(TB_DIR) -name 'tb_*.sv')
TB_TARGETS = $(patsubst $(TB_DIR)/tb_%.sv,$(SIM_DIR)/tb_%,$(TB_SRC))

sim: $(TB_TARGETS)

$(SIM_DIR)/tb_%: $(TB_DIR)/tb_%.sv $(RTL_SRC)
	echo "$(TB_TARGETS)"
	@mkdir -p $(SIM_DIR)
	iverilog -g2012 -o $@ -I $(RTL_DIR) $< $(RTL_SRC)
	vvp $@

wave-%: $(SIM_DIR)/tb_%
	gtkwave $(SIM_DIR)/tb_$*.vcd &

lint:
	verilator --lint-only -I$(RTL_DIR) $(RTL_SRC)

format:
	verible-verilog-format --inplace $(RTL_SRC) $(TB_SRC)

clean:
	rm -rf $(SIM_DIR)/*.vcd $(SIM_DIR)/tb_* build/

.PHONY: sim lint format clean