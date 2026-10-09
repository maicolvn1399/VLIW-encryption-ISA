#==============================================================================
# CERBERO-1 - Makefile de simulacion
#
#   make sim        Compila y ejecuta todos los testbenches
#   make tb_alu     Solo el testbench de la ALU
#   make wave       Abre la ultima forma de onda en GTKWave
#   make lint       Analisis estatico con Verilator (opcional)
#   make clean      Borra los artefactos de compilacion
#==============================================================================

IVERILOG  ?= iverilog
VVP       ?= vvp
GTKWAVE   ?= gtkwave
VERILATOR ?= verilator

RTL_DIR   := rtl
TB_DIR    := tb
BUILD_DIR := build

# -g2012 habilita SystemVerilog. -I expone cerbero_defs.svh al `include.
IVFLAGS := -g2012 -Wall -I $(RTL_DIR)

# Fuentes de diseno
RTL_SRCS := $(RTL_DIR)/alu.sv

# Un objetivo por testbench. Al agregar unidades, anadir aqui.
TESTS := tb_alu

.PHONY: all sim clean wave lint $(TESTS)

all: sim

#------------------------------------------------------------------------------
# Ejecuta todos los testbenches y resume el resultado
#------------------------------------------------------------------------------
sim: $(TESTS)
	@echo ""
	@echo "=============================================="
	@echo " Simulacion completa"
	@echo "=============================================="

#------------------------------------------------------------------------------
# Testbench de la ALU
#------------------------------------------------------------------------------
tb_alu: $(BUILD_DIR)/tb_alu
	@echo ""
	@$(VVP) $(BUILD_DIR)/tb_alu

$(BUILD_DIR)/tb_alu: $(RTL_DIR)/alu.sv $(RTL_DIR)/cerbero_defs.svh $(TB_DIR)/tb_alu.sv | $(BUILD_DIR)
	@echo "[iverilog] tb_alu"
	@$(IVERILOG) $(IVFLAGS) -o $@ $(RTL_DIR)/alu.sv $(TB_DIR)/tb_alu.sv

#------------------------------------------------------------------------------
# Utilidades
#------------------------------------------------------------------------------
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

wave: $(BUILD_DIR)/tb_alu.vcd
	$(GTKWAVE) $(BUILD_DIR)/tb_alu.vcd &

# Verilator se usa solo para analisis estatico: detecta anchos inconsistentes,
# senales no manejadas y latches inferidos que Icarus no reporta.
lint:
	$(VERILATOR) --lint-only -Wall -I$(RTL_DIR) $(RTL_SRCS) --top-module alu

clean:
	@rm -rf $(BUILD_DIR)
	@echo "Artefactos eliminados."