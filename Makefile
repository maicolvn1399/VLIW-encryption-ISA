# Archivos fuente y testbench
SRC = hardware/src/short_alu.sv
TB  = hardware/tb/tb_short_alu.sv

# Archivos de salida
OUT = sim_short_alu.out
VCD = sim_short_alu.vcd

# Opciones de compilación
IVERILOG = iverilog
FLAGS    = -g2012

.PHONY: all compile run view clean

# Regla por defecto: compila, simula y abre el VCD
all: run view

# 1. Compilación
compile:
	$(IVERILOG) $(FLAGS) -o $(OUT) $(SRC) $(TB)

# 2. Ejecución de la simulación
run: compile
	vvp $(OUT)

# 3. Abrir el visor de ondas en VS Code
view:
	code $(VCD)

# Limpieza de ejecutables y archivos temporales
clean:
	rm -f $(OUT) $(VCD)