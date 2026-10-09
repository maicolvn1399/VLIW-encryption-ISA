# =============================================================================
# makefile - CERBERO (Icarus Verilog)
# Se ejecuta desde src/build:
#
#   make                -> corre todos los testbenches de ../tb (make sim)
#   make key_vault      -> corre solo tb_key_vault.sv
#   make wave-key_vault -> abre tb_key_vault.vcd en GTKWave
#   make list           -> lista las unidades con testbench
#   make clean          -> borra .vvp y .vcd
#
# Convención (para que funcione sin tocar este archivo):
#   - Módulo:     ../cpu/<unidad>.sv        (ej. ../cpu/alu.sv)
#   - Testbench:  ../tb/tb_<unidad>.sv      (ej. ../tb/tb_alu.sv, módulo tb_alu)
#   - Paquetes compartidos: ../cpu/*_pkg.sv  (se compilan primero en todos)
#   - Si un módulo instancia otros, declarar sus dependencias abajo:
#         DEPS_crypto_unit := $(CPU)/key_vault.sv
# =============================================================================

IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave
FLAGS    := -g2012 -Wall -Wno-timescale -I ../cpu

CPU := ../cpu
TB  := ../tb

PKGS  := $(wildcard $(CPU)/*_pkg.sv)
UNITS := $(patsubst $(TB)/tb_%.sv,%,$(wildcard $(TB)/tb_*.sv))

# ---- Dependencias extra por unidad (agregar aquí) ---------------------------
DEPS_crypto_unit := $(TB)/key_vault_model.sv
# DEPS_top         := $(filter-out $(PKGS),$(wildcard $(CPU)/*.sv))

.PHONY: all sim list clean $(UNITS) $(addprefix wave-,$(UNITS))

all: sim

sim: $(UNITS)

list:
	@echo $(UNITS)

# make <unidad>: compila y ejecuta su testbench
$(UNITS): %: tb_%.vvp
	$(VVP) -n $< +VCD=tb_$*.vcd

# Compilación: paquetes + módulo + dependencias + testbench
.SECONDARY:
.SECONDEXPANSION:
tb_%.vvp: $$(PKGS) $(CPU)/%.sv $$(DEPS_$$*) $(TB)/tb_%.sv
	$(IVERILOG) $(FLAGS) -s tb_$* -o $@ $(PKGS) $(CPU)/$*.sv $(DEPS_$*) $(TB)/tb_$*.sv

wave-%: %
	$(GTKWAVE) tb_$*.vcd &

clean:
	rm -f *.vvp *.vcd