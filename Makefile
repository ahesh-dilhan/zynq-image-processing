PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
BUILD_DIR ?= build

RTL := rtl/axis_mean_filter_3x3.sv
TB := sim/tb_axis_mean_filter_3x3.sv
SIMULATION := $(BUILD_DIR)/tb_axis_mean_filter_3x3.vvp

.PHONY: test model-test rtl-test reference clean

test: model-test rtl-test

model-test:
	$(PYTHON) -m unittest discover -s tests -v

$(SIMULATION): $(RTL) $(TB)
	mkdir -p $(BUILD_DIR)
	$(IVERILOG) -g2012 -Wall -s tb_axis_mean_filter_3x3 -o $@ $^

rtl-test: $(SIMULATION)
	$(VVP) $(SIMULATION)

reference:
	$(PYTHON) sim/reference_model.py --output-dir $(BUILD_DIR)/reference

clean:
	rm -rf $(BUILD_DIR)
