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
# tb_descifrado necesita un archivo cifrado de entrada, asi que no entra en
# "make sim": se corre con "make solo-descifrar".
UNITS := $(filter-out descifrado,$(patsubst $(TB)/tb_%.sv,%,$(wildcard $(TB)/tb_*.sv)))

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
DEPS_div          := $(wildcard $(CPU)/*.sv) \
                     $(PROGS)/div32_prueba.hex $(PROGS)/div32_prueba_datos.hex
# tb_archivo carga tres imagenes por referencia jerarquica, no por macro: son
# dos programas distintos en una misma simulacion y las macros son globales.
DEPS_archivo      := $(wildcard $(CPU)/*.sv) \
                     $(PROGS)/cifrar_archivo.hex \
                     $(PROGS)/descifrar_archivo.hex \
                     $(PROGS)/archivo_prueba.hex
# tb_cifrado carga los mismos dos programas; la imagen del archivo la lee en
# tiempo de simulacion, asi que va como requisito de la corrida, no de aqui
DEPS_cifrado      := $(wildcard $(CPU)/*.sv) \
                     $(PROGS)/cifrar_archivo.hex \
                     $(PROGS)/descifrar_archivo.hex
# tb_descifrado carga el contenedor en tiempo de simulacion, igual que
# tb_cifrado carga el archivo
DEPS_descifrado   := $(wildcard $(CPU)/*.sv) \
                     $(PROGS)/descifrar_archivo.hex

# ---- Opciones de compilacion por unidad -------------------------------------
# tb_asm es el unico testbench que no arma su programa adentro: el .hex entra
# por macro, porque Icarus no puede pasar un parametro string a un submodulo.
XFLAGS_asm := -DCERBERO_IMEM_FILE='"$(PROGS)/feistel.hex"' \
              -DCERBERO_DMEM_FILE='"$(PROGS)/feistel_datos.hex"'
XFLAGS_div := -DCERBERO_IMEM_FILE='"$(PROGS)/div32_prueba.hex"' \
              -DCERBERO_DMEM_FILE='"$(PROGS)/div32_prueba_datos.hex"'

# ---- Unidades sin modulo propio (testbenches de integracion) ----------------
# Para estas, la receta no antepone $(CPU)/<unidad>.sv
NO_RTL := crypto_vault latency wconf pipeline fetch_flow asm div archivo cifrado \
          descifrado

# Objetivos derivados. Se nombran en variables porque las reglas de abajo son
# ESTATICAS y no implicitas: make omite la busqueda de reglas implicitas para
# los objetivos declarados .PHONY, asi que una regla de patron normal como
# "lint-%:" nunca llegaria a ejecutarse y el objetivo pasaria sin hacer nada.
LINT_TARGETS := $(addprefix lint-,$(RTL_UNITS))
WAVE_TARGETS := $(addprefix wave-,$(UNITS))

.PHONY: all sim list clean lint $(UNITS) $(WAVE_TARGETS) $(LINT_TARGETS)

all: herramientas sim flujo

# ---- Pruebas de las herramientas en Python ----------------------------------
# El ensamblador tiene su propio arnes, con el mismo formato de salida que los
# del RTL. Incluye la comprobacion de que programas/cobertura.s usa el 100% del
# conjunto de instrucciones, que es lo que pide el enunciado.
.PHONY: herramientas
herramientas:
	@echo ""
	@echo "---- pruebas del ensamblador ----"
	python3 $(TOOLS)/probar_asm.py
	@echo ""
	@echo "---- pruebas de load_file y extract_data ----"
	python3 $(TOOLS)/probar_archivos.py

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
# Un .s produce los dos .hex de una pasada.
#
# El relleno tiene que coincidir EXACTAMENTE con el tamano de las memorias del
# testbench que va a cargar el binario. Icarus avisa en los dos sentidos:
# "Not enough words" si el archivo es mas corto que la memoria y "Too many
# words" si es mas largo. Ninguno de los dos rompe la simulacion, pero el ruido
# tapa los avisos que si importan, asi que cada programa declara su tamano.
BUNDLES_feistel      := 2048
PALABRAS_feistel     := 64
BUNDLES_div32_prueba := 128
PALABRAS_div32_prueba := 64
BUNDLES_cifrar_archivo    := 2048
BUNDLES_descifrar_archivo := 2048

$(PROGS)/%.hex $(PROGS)/%_datos.hex: $(PROGS)/%.s $(CPU)/cerbero_defs.svh
	$(ASM) $< -o $(PROGS)/$*.hex --datos $(PROGS)/$*_datos.hex \
	       --bundles $(or $(BUNDLES_$*),2048) \
	       --palabras $(or $(PALABRAS_$*),64)

.PHONY: programas cobertura
programas: $(PROGS)/feistel.hex $(PROGS)/div32_prueba.hex \
           $(PROGS)/cifrar_archivo.hex $(PROGS)/descifrar_archivo.hex \
           $(PROGS)/archivo_prueba.hex

# Los dos programas de archivo incluyen los mismos dos fragmentos
$(PROGS)/cifrar_archivo.hex $(PROGS)/descifrar_archivo.hex: \
	$(PROGS)/cargar_llave.s $(PROGS)/vault_sesion.s

# La imagen del archivo de prueba la produce load_file.py, no el ensamblador
$(PROGS)/archivo_prueba.hex: $(PROGS)/archivo_prueba.txt $(TOOLS)/load_file.py
	python3 $(TOOLS)/load_file.py $< -o $@ --palabras 16384

# div32_prueba.s incluye div32.s, asi que su binario depende de los dos
$(PROGS)/div32_prueba.hex: $(PROGS)/div32.s

# El flujo completo, de archivo a archivo. Depende del volcado que escribe
# tb_archivo, asi que corre el testbench primero.
.PHONY: flujo
flujo: archivo
	@echo ""
	@echo "---- flujo completo de archivo a archivo ----"
	python3 $(TOOLS)/probar_flujo.py cifrado_volcado.hex

# ---- Cifrar un archivo cualquiera ---------------------------------------------
#   make cifrar ARCHIVO=../../tools/programas/mi_texto.txt
#
# tb_archivo tiene escrito el criptograma de archivo_prueba.txt, asi que solo
# sirve para ese archivo. tb_cifrado no trae valores fijos y probar_flujo.py
# hace de oraculo con su modelo de referencia. Sin ARCHIVO usa el de prueba.
ARCHIVO ?= $(PROGS)/archivo_prueba.txt

# Se regenera en cada corrida: si solo cambia la variable ARCHIVO, make no
# veria ningun archivo mas nuevo y cargaria la imagen anterior.
.PHONY: archivo_libre.hex cifrar
archivo_libre.hex:
	python3 $(TOOLS)/load_file.py $(ARCHIVO) -o $@ --palabras 16384

cifrado: archivo_libre.hex

cifrar: cifrado
	@echo ""
	@echo "---- flujo completo sobre $(ARCHIVO) ----"
	python3 $(TOOLS)/probar_flujo.py cifrado_libre.hex $(ARCHIVO)

# Solo el cifrado: el segundo procesador no arranca. El criptograma lo sigue
# verificando probar_flujo.py contra el modelo de referencia, que no necesita
# del descifrado del hardware.
#   make solo-cifrar ARCHIVO=../../tools/programas/mi_texto.txt
.PHONY: solo-cifrar
solo-cifrar: tb_cifrado.vvp archivo_libre.hex
	@echo ""
	@echo "---- solo cifrar $(ARCHIVO) ----"
	$(VVP) -n tb_cifrado.vvp +SOLO_CIFRAR
	@echo ""
	@echo "---- el criptograma contra el modelo de referencia ----"
	python3 $(TOOLS)/probar_flujo.py cifrado_libre.hex $(ARCHIVO)

# Solo el descifrado, partiendo de un archivo cifrado en disco. Por omision
# toma el que deja "make solo-cifrar"; con ORIGINAL, tambien compara contra el.
#   make solo-descifrar
#   make solo-descifrar CIFRADO=cifrado_libre.bin ORIGINAL=../../mi_texto.txt
# El archivo descifrado queda en descifrado_libre.bin.
CIFRADO  ?= cifrado_libre.bin
ORIGINAL ?=

.PHONY: solo-descifrar contenedor_libre.hex
contenedor_libre.hex:
	python3 $(TOOLS)/load_file.py $(CIFRADO) -o $@ --palabras 16384 --cifrado

solo-descifrar: tb_descifrado.vvp contenedor_libre.hex
	@echo ""
	@echo "---- solo descifrar $(CIFRADO) ----"
	$(VVP) -n tb_descifrado.vvp
	@echo ""
	@echo "---- el descifrado contra el modelo de referencia ----"
	python3 $(TOOLS)/probar_descifrado.py $(CIFRADO) descifrado_libre.hex \
	        descifrado_libre.bin $(ORIGINAL)

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

# clean borra TAMBIEN los binarios que produce el ensamblador. No es por
# prolijidad: las marcas de tiempo del sistema de archivos tienen granularidad
# de un segundo, asi que editar un .s y correr make en el mismo segundo puede
# dejar el .hex anterior en pie, y la simulacion correria el programa viejo sin
# que nada avise. Con "make clean && make" eso no puede pasar.
clean:
	rm -f *.vvp *.vcd cifrado_volcado.hex cifrado_volcado.bin
	rm -f archivo_libre.hex cifrado_libre.hex cifrado_libre.bin
	rm -f contenedor_libre.hex descifrado_libre.hex descifrado_libre.bin
	rm -f $(PROGS)/*.hex
