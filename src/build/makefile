# =============================================================================
# makefile - CERBERO-1 (Icarus Verilog + Verilator)
# CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4
#
# Se ejecuta desde src/build:
#
#   make                -> corre todos los testbenches de ../tb (make sim)
#   make key_vault      -> corre solo tb_key_vault.sv
#   make wave-key_vault -> abre tb_key_vault.vcd en GTKWave
#   make lint           -> analisis estatico de todas las unidades
#   make lint-lsu       -> analisis estatico de una unidad
#   make list           -> lista las unidades con testbench
#   make clean          -> borra .vvp y .vcd
#
# Convencion (para que funcione sin tocar este archivo):
#   - Modulo:     ../cpu/<unidad>.sv        (ej. ../cpu/alu.sv)
#   - Testbench:  ../tb/tb_<unidad>.sv      (ej. ../tb/tb_alu.sv, modulo tb_alu)
#   - Paquetes compartidos: ../cpu/*_pkg.sv  (se compilan primero en todos)
#   - Si un modulo instancia otros, declarar sus dependencias abajo:
#         DEPS_crypto_unit := $(CPU)/key_vault.sv
#
# Un testbench que encuentra un error llama a $fatal, lo que le da a vvp un
# codigo de salida distinto de cero y detiene el make. "make sim" que termina
# bien significa que todas las unidades pasaron, no solo que corrieron.
# =============================================================================

IVERILOG  ?= iverilog
VVP       ?= vvp
GTKWAVE   ?= gtkwave
VERILATOR ?= verilator

FLAGS      := -g2012 -Wall -Wno-timescale -I ../cpu
LINT_FLAGS := --lint-only -Wall -I../cpu

CPU := ../cpu
TB  := ../tb

PKGS  := $(wildcard $(CPU)/*_pkg.sv)
UNITS := $(patsubst $(TB)/tb_%.sv,%,$(wildcard $(TB)/tb_*.sv))

# Unidades con modulo propio en ../cpu. Se excluyen los testbenches de
# integracion, que no tienen un ../cpu/<nombre>.sv detras.
RTL_UNITS := $(patsubst $(CPU)/%.sv,%,$(wildcard $(CPU)/*.sv))

# ---- Dependencias extra por unidad (agregar aqui) ---------------------------
DEPS_crypto_unit  := $(TB)/key_vault_model.sv
DEPS_crypto_vault := $(CPU)/crypto_unit.sv $(CPU)/key_vault.sv
DEPS_latency      := $(CPU)/regfile.sv
DEPS_wconf        := $(CPU)/psw_fault_unit.sv $(CPU)/regfile.sv
# DEPS_top        := $(filter-out $(PKGS),$(wildcard $(CPU)/*.sv))

# ---- Unidades sin modulo propio (testbenches de integracion) ----------------
# Para estas, la receta no antepone $(CPU)/<unidad>.sv
NO_RTL := crypto_vault latency wconf

# Objetivos derivados. Se nombran en variables porque las reglas de abajo son
# ESTATICAS y no implicitas: make omite la busqueda de reglas implicitas para
# los objetivos declarados .PHONY, asi que una regla de patron normal como
# "lint-%:" nunca llegaria a ejecutarse y el objetivo pasaria sin hacer nada.
LINT_TARGETS := $(addprefix lint-,$(RTL_UNITS))
WAVE_TARGETS := $(addprefix wave-,$(UNITS))

.PHONY: all sim list clean lint $(UNITS) $(WAVE_TARGETS) $(LINT_TARGETS)

all: sim

sim: $(UNITS)
	@echo ""
	@echo "=============================================================="
	@echo " Todas las unidades pasaron"
	@echo "=============================================================="

list:
	@echo "Unidades con testbench: $(UNITS)"
	@echo "Modulos RTL:            $(RTL_UNITS)"

# make <unidad>: compila y ejecuta su testbench
$(UNITS): %: tb_%.vvp
	@echo ""
	@echo "---- $* ----"
	$(VVP) -n $< +VCD=tb_$*.vcd

# Compilacion: paquetes + modulo + dependencias + testbench
.SECONDARY:
.SECONDEXPANSION:
tb_%.vvp: $$(PKGS) $$(if $$(filter $$*,$$(NO_RTL)),,$(CPU)/%.sv) $$(DEPS_$$*) $(TB)/tb_%.sv
	$(IVERILOG) $(FLAGS) -s tb_$* -o $@ $^

$(WAVE_TARGETS): wave-%: %
	$(GTKWAVE) tb_$*.vcd &

# ---- Analisis estatico ------------------------------------------------------
# Verilator ve cosas que Icarus deja pasar: anchos inconsistentes, senales no
# usadas y latches inferidos en un always_comb incompleto. Conviene correrlo
# antes de cada commit, no solo cuando algo falla.
lint: $(LINT_TARGETS)
	@echo ""
	@echo "=============================================================="
	@echo " Analisis estatico limpio en todas las unidades"
	@echo "=============================================================="

$(LINT_TARGETS): lint-%:
	@echo "---- verilator $* ----"
	$(VERILATOR) $(LINT_FLAGS) $(CPU)/$*.sv --top-module $*

clean:
	rm -f *.vvp *.vcd
