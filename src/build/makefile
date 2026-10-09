# =============================================================================
# makefile - CERBERO (Icarus Verilog)
# Se ejecuta desde src/build.  Para ver todos los comandos:  make help
#
#   make help              -> lista todos los comandos y las unidades detectadas
#   make tb-<unidad>       -> compila y corre la simulación de esa unidad
#                             (ej.: make tb-regfile, make tb-key_vault, make tb-alu)
#   make wave-<unidad>     -> corre la simulación y abre su onda en GTKWave
#   make tb-all            -> corre TODAS las simulaciones (se detiene en la 1.a que falle)
#   make tb-all-continue   -> corre todas aunque alguna falle (equivale a make -k)
#   make list              -> lista las unidades que tienen testbench
#   make clean             -> borra los .vvp y .vcd generados
#
# Convención (para agregar una unidad sin tocar este archivo):
#   - Módulo:      ../cpu/<unidad>.sv       (ej. ../cpu/regfile.sv)
#   - Testbench:   ../tb/tb_<unidad>.sv     (ej. ../tb/tb_regfile.sv, módulo tb_regfile)
#   - Includes:    ../cpu/*.svh              (se encuentran por la opción -I)
#   - Paquetes:    ../cpu/*_pkg.sv           (se compilan primero en todas las unidades)
#   - Si una unidad necesita compilar otros archivos, se declaran en la sección
#     "Archivos extra por unidad" como  EXTRA_SOURCES_<unidad> := ...
# =============================================================================

# ---- Herramientas -----------------------------------------------------------
VERILOG_COMPILER   ?= iverilog
SIMULATION_RUNNER  ?= vvp
WAVEFORM_VIEWER    ?= gtkwave

# ---- Carpetas -----------------------------------------------------------------
MODULES_DIRECTORY    := ../cpu
TESTBENCHES_DIRECTORY := ../tb

# ---- Opciones del compilador ------------------------------------------------
#   -g2012         : SystemVerilog (IEEE 1800-2012)
#   -Wall          : todas las advertencias
#   -Wno-timescale : no avisar por módulos sin `timescale
#   -I <carpeta>   : dónde buscar los `include (ej. cerbero_defs.svh)
COMPILER_FLAGS := -g2012 -Wall -Wno-timescale -I $(MODULES_DIRECTORY)

# ---- Descubrimiento automático de unidades ---------------------------------
# Cada ../tb/tb_<unidad>.sv define una unidad llamada <unidad>.
SHARED_PACKAGE_FILES := $(wildcard $(MODULES_DIRECTORY)/*_pkg.sv)
TESTBENCH_FILES      := $(wildcard $(TESTBENCHES_DIRECTORY)/tb_*.sv)
UNIT_NAMES           := $(patsubst $(TESTBENCHES_DIRECTORY)/tb_%.sv,%,$(TESTBENCH_FILES))

SIMULATION_TARGETS := $(addprefix tb-,$(UNIT_NAMES))
WAVEFORM_TARGETS   := $(addprefix wave-,$(UNIT_NAMES))

# ---- Archivos extra por unidad ----------------------------------------------
# Se agregan a la compilación de esa unidad, después de su módulo.
EXTRA_SOURCES_crypto_unit := $(TESTBENCHES_DIRECTORY)/key_vault_model.sv
# EXTRA_SOURCES_top       := $(filter-out $(SHARED_PACKAGE_FILES) $(MODULES_DIRECTORY)/top.sv,$(wildcard $(MODULES_DIRECTORY)/*.sv))

# =============================================================================
# Reglas
# =============================================================================
.PHONY: help list tb-all tb-all-continue clean $(SIMULATION_TARGETS) $(WAVEFORM_TARGETS)
.DEFAULT_GOAL := help

help:
	@echo "Comandos disponibles (ejecutar desde src/build):"
	@echo "  make tb-<unidad>       corre la simulacion de una unidad"
	@echo "  make wave-<unidad>     corre la simulacion y abre la onda en GTKWave"
	@echo "  make tb-all            corre todas las simulaciones"
	@echo "  make tb-all-continue   corre todas aunque alguna falle"
	@echo "  make list              lista las unidades"
	@echo "  make clean             borra .vvp y .vcd"
	@echo ""
	@echo "Simulaciones disponibles:"
	@for unit_name in $(UNIT_NAMES); do echo "  make tb-$$unit_name"; done

list:
	@echo $(UNIT_NAMES)

# make tb-<unidad>: compila (si hace falta) y corre la simulación
$(SIMULATION_TARGETS): tb-%: tb_%.vvp
	@echo "=============== Simulacion: $* ==============="
	$(SIMULATION_RUNNER) -n $< +VCD=tb_$*.vcd

# Compilación de una unidad: paquetes + módulo + archivos extra + testbench.
# Se recompila solo si cambió alguno de esos archivos.
.SECONDARY:
.SECONDEXPANSION:
tb_%.vvp: $$(SHARED_PACKAGE_FILES) $(MODULES_DIRECTORY)/%.sv $$(EXTRA_SOURCES_$$*) $(TESTBENCHES_DIRECTORY)/tb_%.sv
	$(VERILOG_COMPILER) $(COMPILER_FLAGS) -s tb_$* -o $@ \
		$(SHARED_PACKAGE_FILES) $(MODULES_DIRECTORY)/$*.sv $(EXTRA_SOURCES_$*) $(TESTBENCHES_DIRECTORY)/tb_$*.sv

# make wave-<unidad>: corre la simulación y abre la onda
$(WAVEFORM_TARGETS): wave-%: tb-%
	$(WAVEFORM_VIEWER) tb_$*.vcd &

# Todas las simulaciones, una tras otra
tb-all: $(SIMULATION_TARGETS)

tb-all-continue:
	@$(MAKE) --no-print-directory -k tb-all

clean:
	rm -f *.vvp *.vcd