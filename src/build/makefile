# =============================================================================
# makefile - CERBERO (Icarus Verilog + Verilator)
# CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4
#
# Se ejecuta desde src/build. Para ver todos los comandos:  make help
# Funciona igual desde Linux/WSL y desde PowerShell/cmd en Windows.
#
#   make help                -> lista los comandos y las unidades detectadas
#   make tb-<unidad>         -> compila y corre la simulación de esa unidad
#                               (ej.: make tb-regfile, make tb-crypto_vault)
#   make wave-<unidad>       -> corre la simulación y abre la onda en GTKWave
#   make tb-all              -> corre TODAS las simulaciones (se detiene en la
#                               primera que falle)
#   make tb-all-continue     -> corre todas aunque alguna falle
#   make lint-<unidad>       -> análisis estático de un módulo con Verilator
#   make lint-all            -> análisis estático de todos los módulos
#   make list                -> lista unidades con testbench y módulos RTL
#   make clean               -> borra los .vvp y .vcd generados
#
# Convención (para agregar una unidad sin tocar este archivo):
#   - Módulo:      ../cpu/<unidad>.sv       (ej. ../cpu/regfile.sv)
#   - Testbench:   ../tb/tb_<unidad>.sv     (ej. ../tb/tb_regfile.sv, módulo tb_regfile)
#   - Includes:    ../cpu/*.svh              (se encuentran con la opción -I)
#   - Paquetes:    ../cpu/*_pkg.sv           (se compilan primero en todas las unidades)
#   - Si una unidad necesita compilar otros archivos, se declaran en la
#     sección "Archivos extra por unidad" como  EXTRA_SOURCES_<unidad> := ...
#   - Un testbench de integración (prueba varios módulos y no tiene un
#     ../cpu/<nombre>.sv propio) se agrega a INTEGRATION_TESTBENCHES.
#
# Un testbench que encuentra un error termina con $fatal: vvp devuelve un
# código distinto de cero y make se detiene. Si "make tb-all" termina bien,
# todas las unidades PASARON, no solo corrieron.
# =============================================================================

# ---- Herramientas -----------------------------------------------------------
VERILOG_COMPILER  ?= iverilog
SIMULATION_RUNNER ?= vvp
WAVEFORM_VIEWER   ?= gtkwave
LINTER            ?= verilator

# ---- Diferencias entre Windows (cmd/PowerShell) y Linux/WSL ---------------
ifeq ($(OS),Windows_NT)
    DELETE_FILES       := del /Q /F
    OPEN_IN_BACKGROUND := start ""
    BACKGROUND_SUFFIX  :=
else
    DELETE_FILES       := rm -f
    OPEN_IN_BACKGROUND :=
    BACKGROUND_SUFFIX  := &
endif

# Un espacio literal, para sangrar las líneas que imprime make
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

# ---- Carpetas -----------------------------------------------------------------
MODULES_DIRECTORY     := ../cpu
TESTBENCHES_DIRECTORY := ../tb

# ---- Opciones de las herramientas ------------------------------------------
#   -g2012         : SystemVerilog (IEEE 1800-2012)
#   -Wall          : todas las advertencias
#   -Wno-timescale : no avisar por módulos sin `timescale
#   -I <carpeta>   : dónde buscar los `include (ej. cerbero_defs.svh)
COMPILER_FLAGS := -g2012 -Wall -Wno-timescale -I $(MODULES_DIRECTORY)
LINTER_FLAGS   := --lint-only -Wall -I$(MODULES_DIRECTORY)

# ---- Descubrimiento automático ---------------------------------------------
# Cada ../tb/tb_<unidad>.sv define una unidad simulable llamada <unidad>.
# Cada ../cpu/<modulo>.sv (que no sea un paquete) es un módulo RTL.
SHARED_PACKAGE_FILES := $(wildcard $(MODULES_DIRECTORY)/*_pkg.sv)
TESTBENCH_FILES      := $(wildcard $(TESTBENCHES_DIRECTORY)/tb_*.sv)
UNIT_NAMES           := $(patsubst $(TESTBENCHES_DIRECTORY)/tb_%.sv,%,$(TESTBENCH_FILES))
RTL_MODULE_NAMES     := $(patsubst $(MODULES_DIRECTORY)/%.sv,%,\
                          $(filter-out $(SHARED_PACKAGE_FILES),$(wildcard $(MODULES_DIRECTORY)/*.sv)))

SIMULATION_TARGETS := $(addprefix tb-,$(UNIT_NAMES))
WAVEFORM_TARGETS   := $(addprefix wave-,$(UNIT_NAMES))
LINT_TARGETS       := $(addprefix lint-,$(RTL_MODULE_NAMES))

# ---- Testbenches de integración --------------------------------------------
# No tienen un ../cpu/<nombre>.sv; compilan solo sus EXTRA_SOURCES.
INTEGRATION_TESTBENCHES := crypto_vault

# ---- Archivos extra por unidad ----------------------------------------------
# Se compilan junto a la unidad, después de su módulo.
EXTRA_SOURCES_crypto_unit  := $(TESTBENCHES_DIRECTORY)/key_vault_model.sv
EXTRA_SOURCES_crypto_vault := $(MODULES_DIRECTORY)/crypto_unit.sv $(MODULES_DIRECTORY)/key_vault.sv
# EXTRA_SOURCES_top        := $(filter-out $(SHARED_PACKAGE_FILES) $(MODULES_DIRECTORY)/top.sv,$(wildcard $(MODULES_DIRECTORY)/*.sv))

# Módulo propio de una unidad: vacío si es un testbench de integración
unit_module_file = $(if $(filter $(1),$(INTEGRATION_TESTBENCHES)),,$(MODULES_DIRECTORY)/$(1).sv)

# =============================================================================
# Reglas
# =============================================================================
.PHONY: help list tb-all tb-all-continue lint-all clean \
        $(SIMULATION_TARGETS) $(WAVEFORM_TARGETS) $(LINT_TARGETS)
.DEFAULT_GOAL := help

help:
	$(info Comandos disponibles (ejecutar desde src/build):)
	$(info $(SPACE) make tb-NOMBRE         corre la simulacion de una unidad)
	$(info $(SPACE) make wave-NOMBRE       corre la simulacion y abre la onda en GTKWave)
	$(info $(SPACE) make tb-all            corre todas las simulaciones)
	$(info $(SPACE) make tb-all-continue   corre todas aunque alguna falle)
	$(info $(SPACE) make lint-NOMBRE       analisis estatico de un modulo (Verilator))
	$(info $(SPACE) make lint-all          analisis estatico de todos los modulos)
	$(info $(SPACE) make list              lista unidades y modulos)
	$(info $(SPACE) make clean             borra .vvp y .vcd)
	$(info )
	$(info Simulaciones disponibles:)
	$(foreach unit_name,$(UNIT_NAMES),$(info $(SPACE) make tb-$(unit_name)))
	$(info )
	$(info Modulos para lint:)
	$(foreach module_name,$(RTL_MODULE_NAMES),$(info $(SPACE) make lint-$(module_name)))
	@exit 0

list:
	$(info Unidades con testbench: $(UNIT_NAMES))
	$(info Modulos RTL:            $(RTL_MODULE_NAMES))
	@exit 0

# ---- Simulación -------------------------------------------------------------
# make tb-<unidad>: compila (si cambió algo) y corre la simulación
$(SIMULATION_TARGETS): tb-%: tb_%.vvp
	$(info )
	$(info =============== Simulacion: $* ===============)
	$(SIMULATION_RUNNER) -n $< +VCD=tb_$*.vcd

# Compilación: paquetes + módulo propio (si tiene) + archivos extra + testbench
.SECONDARY:
.SECONDEXPANSION:
tb_%.vvp: $$(SHARED_PACKAGE_FILES) $$(call unit_module_file,$$*) $$(EXTRA_SOURCES_$$*) $(TESTBENCHES_DIRECTORY)/tb_%.sv
	$(VERILOG_COMPILER) $(COMPILER_FLAGS) -s tb_$* -o $@ $^

# make wave-<unidad>: corre la simulación y abre la onda
$(WAVEFORM_TARGETS): wave-%: tb-%
	$(OPEN_IN_BACKGROUND) $(WAVEFORM_VIEWER) tb_$*.vcd $(BACKGROUND_SUFFIX)

# Todas las simulaciones, una tras otra
tb-all: $(SIMULATION_TARGETS)
	$(info )
	$(info ==============================================================)
	$(info $(SPACE)Todas las unidades pasaron)
	$(info ==============================================================)
	@exit 0

tb-all-continue:
	@$(MAKE) --no-print-directory -k tb-all

# ---- Análisis estático con Verilator ---------------------------------------
# Verilator detecta cosas que Icarus deja pasar: anchos inconsistentes,
# señales sin usar y latches inferidos en un always_comb incompleto.
# Conviene correrlo antes de cada commit.
$(LINT_TARGETS): lint-%:
	$(info ---- verilator: $* ----)
	$(LINTER) $(LINTER_FLAGS) $(SHARED_PACKAGE_FILES) $(MODULES_DIRECTORY)/$*.sv --top-module $*

lint-all: $(LINT_TARGETS)
	$(info )
	$(info ==============================================================)
	$(info $(SPACE)Analisis estatico limpio en todos los modulos)
	$(info ==============================================================)
	@exit 0

# ---- Limpieza ---------------------------------------------------------------
clean:
	$(DELETE_FILES) *.vvp *.vcd