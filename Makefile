# Makefile de simulación - Arquitectura CERBERO VLIW
IVERILOG = iverilog
FLAGS    = -g2012
VVP      = vvp

.PHONY: all alu lsu clean help

# Objetivo por defecto si solo se ejecuta 'make'
all: alu

# 1. ALU Corta (Slot S3)
ALU_SRC = hardware/src/short_alu.sv
ALU_TB  = hardware/tb/tb_short_alu.sv
ALU_OUT = sim_short_alu.out
ALU_VCD = sim_short_alu.vcd

alu:
	$(IVERILOG) $(FLAGS) -o $(ALU_OUT) $(ALU_SRC) $(ALU_TB)
	$(VVP) $(ALU_OUT)
	code $(ALU_VCD)

# 2. LSU - Load/Store Unit (Slot S2)
LSU_SRC = hardware/src/lsu.sv
LSU_TB  = hardware/tb/tb_lsu.sv
LSU_OUT = sim_lsu.out
LSU_VCD = sim_lsu.vcd

lsu:
	$(IVERILOG) $(FLAGS) -o $(LSU_OUT) $(LSU_SRC) $(LSU_TB)
	$(VVP) $(LSU_OUT)
	code $(LSU_VCD)

# Limpieza de ejecutables y archivos de ondas
clean:
	rm -f *.out *.vcd