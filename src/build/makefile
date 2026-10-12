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

# Programa y datos para "make top". Opcionales: sin ellos las memorias arrancan
# vacias y el testbench las carga por referencia jerarquica.
#   make top IMEM=../tb/programa.hex DMEM=../tb/datos.hex
IMEM ?=
DMEM ?=
INIT_DEFS :=
ifneq ($(IMEM),)
INIT_DEFS += -DCERBERO_IMEM_FILE='"$(IMEM)"'
endif
ifneq ($(DMEM),)
INIT_DEFS += -DCERBERO_DMEM_FILE='"$(DMEM)"'
endif

FLAGS      := -g2012 -Wall -Wno-timescale -I ../cpu $(INIT_DEFS)
LINT_FLAGS := --lint-only -Wall -I../cpu

CPU   := ../cpu
TB    := ../tb
TOOLS := ../../tools
PROGS := $(TOOLS)/programas
ASM   := python3 $(TOOLS)/cerbero_asm.py

PKGS  := $(wildcard $(CPU)/*_pkg.sv)
UNITS := $(patsubst $(TB)/tb_%.sv,%,$(wildcard $(TB)/tb_*.sv))

# Unidades con modulo propio en ../cpu. Se excluyen los testbenches de
# integracion, que no tienen un ../cpu/<nombre>.sv detras.
RTL_UNITS := $(patsubst $(CPU)/%.sv,%,$(wildcard $(CPU)/*.sv))

# ---- Submodulos RTL por unidad ----------------------------------------------
# Modulos de ../cpu que otra unidad instancia. Se compilan junto a ella Y se
# analizan junto a ella, que es la diferencia con DEPS_: esas son dependencias
# del testbench, no del modulo.
SUB_lsu := $(CPU)/load_align.sv
SUB_top := $(filter-out $(CPU)/top.sv,$(wildcard $(CPU)/*.sv))

# ---- Dependencias extra por unidad (agregar aqui) ---------------------------
DEPS_crypto_unit  := $(TB)/key_vault_model.sv
DEPS_crypto_vault := $(CPU)/crypto_unit.sv $(CPU)/key_vault.sv
DEPS_latency      := $(CPU)/regfile.sv
DEPS_wconf        := $(CPU)/psw_fault_unit.sv $(CPU)/regfile.sv
DEPS_pipeline     := $(CPU)/reg_if_id.sv $(CPU)/reg_id_ex.sv \
                     $(CPU)/reg_ex_mem.sv $(CPU)/regfile.sv
DEPS_fetch_flow   := $(CPU)/fetch.sv $(CPU)/imem.sv $(CPU)/reg_if_id.sv \
                     $(CPU)/bru.sv
# tb_asm carga el binario que produce el ensamblador, asi que depende del .hex
DEPS_asm          := $(wildcard $(CPU)/*.sv) \
                     $(PROGS)/feistel.hex $(PROGS)/feistel_datos.hex

# ---- Opciones de compilacion por unidad -------------------------------------
# tb_asm es el unico testbench que no arma su programa adentro: el .hex entra
# por macro, porque Icarus no puede pasar un parametro string a un submodulo.
XFLAGS_asm := -DCERBERO_IMEM_FILE='"$(PROGS)/feistel.hex"' \
              -DCERBERO_DMEM_FILE='"$(PROGS)/feistel_datos.hex"'

# ---- Unidades sin modulo propio (testbenches de integracion) ----------------
# Para estas, la receta no antepone $(CPU)/<unidad>.sv
NO_RTL := crypto_vault latency wconf pipeline fetch_flow asm

# Objetivos derivados. Se nombran en variables porque las reglas de abajo son
# ESTATICAS y no implicitas: make omite la busqueda de reglas implicitas para
# los objetivos declarados .PHONY, asi que una regla de patron normal como
# "lint-%:" nunca llegaria a ejecutarse y el objetivo pasaria sin hacer nada.
LINT_TARGETS := $(addprefix lint-,$(RTL_UNITS))
WAVE_TARGETS := $(addprefix wave-,$(UNITS))

.PHONY: all sim list clean lint $(UNITS) $(WAVE_TARGETS) $(LINT_TARGETS)

all: herramientas sim

# ---- Pruebas de las herramientas en Python ----------------------------------
# El ensamblador tiene su propio arnes, con el mismo formato de salida que los
# del RTL. Incluye la comprobacion de que programas/cobertura.s usa el 100% del
# conjunto de instrucciones, que es lo que pide el enunciado.
.PHONY: herramientas
herramientas:
	@echo ""
	@echo "---- pruebas del ensamblador ----"
	python3 $(TOOLS)/probar_asm.py

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
tb_%.vvp: $$(PKGS) $$(if $$(filter $$*,$$(NO_RTL)),,$(CPU)/%.sv) $$(SUB_$$*) $$(DEPS_$$*) $(TB)/tb_%.sv
	$(IVERILOG) $(FLAGS) $(XFLAGS_$*) -s tb_$* -o $@ $(filter %.sv,$^)

# ---- Ensamblado de programas -------------------------------------------------
# Un .s produce los dos .hex de una pasada. Se rellenan hasta el tamano de las
# memorias para que $readmemh no avise.
$(PROGS)/%.hex $(PROGS)/%_datos.hex: $(PROGS)/%.s $(CPU)/cerbero_defs.svh
	$(ASM) $< -o $(PROGS)/$*.hex --datos $(PROGS)/$*_datos.hex \
	       --bundles 2048 --palabras 64

.PHONY: programas cobertura
programas: $(PROGS)/feistel.hex

# Comprueba que el programa de cobertura usa el 100% del conjunto
cobertura:
	@echo "---- cobertura del conjunto de instrucciones ----"
	$(ASM) $(PROGS)/cobertura.s --cobertura

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
	$(VERILATOR) $(LINT_FLAGS) $(SUB_$*) $(CPU)/$*.sv --top-module $*

clean:
	rm -f *.vvp *.vcd
