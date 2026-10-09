//==============================================================================
// cerbero_defs.svh
// CERBERO-1 - Definiciones compartidas del ISA
//
// Se usan macros `define en lugar de un package de SystemVerilog porque el
// soporte de packages en Icarus Verilog es parcial segun la version. Las
// macros funcionan de forma identica en iverilog -g2012 y en Verilator.
//==============================================================================
`ifndef CERBERO_DEFS_SVH
`define CERBERO_DEFS_SVH

//------------------------------------------------------------------------------
// Anchos generales
//------------------------------------------------------------------------------
`define XLEN      32   // Ancho de registro y de dato
`define NREGS     16   // Cantidad de registros de proposito general
`define RIDX_W     4   // Ancho del campo de registro
`define BUNDLE_W 128   // Ancho del bundle
`define NSLOTS     5   // Cantidad de slots por bundle

//------------------------------------------------------------------------------
// Rangos de bits del bundle de 128 bits
//------------------------------------------------------------------------------
`define SLOT_S0 127:96   // ALU-0
`define SLOT_S1  95:64   // ALU-1
`define SLOT_S2  63:32   // LSU
`define SLOT_S3  31:16   // Criptografica / boveda / ALU corta
`define SLOT_S4  15:0    // BRU

//------------------------------------------------------------------------------
// Campos del slot de 32 bits (tipos A, I, U, M)
//------------------------------------------------------------------------------
`define F_OPC    31:27   // Opcode de 5 bits
`define F_RD     26:23   // Registro destino
`define F_RS1    22:19   // Primer operando fuente
`define F_RS2    18:15   // Segundo operando fuente (tipo A)
`define F_RSVA   14:0    // Reservado del tipo A, debe valer cero
`define F_IMM19  18:0    // Inmediato con signo (tipo I)
`define F_IMM16  18:3    // Inmediato de 16 bits (tipo U)
`define F_COND   2:0     // Codigo de condicion (tipo U, SETcc)

//------------------------------------------------------------------------------
// Opcodes del slot ALU (S0 y S1)
// El bit 4 selecciona la forma del segundo operando:
//   0 = registro, 1 = inmediato.
// Excepciones documentadas: NEG, SETCC, MFPSW y MOVH.
//------------------------------------------------------------------------------
`define ALU_NOP   5'b00000
`define ALU_ADD   5'b00001
`define ALU_SUB   5'b00010
`define ALU_MUL   5'b00011
`define ALU_AND   5'b00100
`define ALU_OR    5'b00101
`define ALU_XOR   5'b00110
`define ALU_SLL   5'b00111
`define ALU_SRL   5'b01000
`define ALU_SRA   5'b01001
`define ALU_ROL   5'b01010
`define ALU_ROR   5'b01011
`define ALU_MOV   5'b01100
`define ALU_NOT   5'b01101
`define ALU_CMP   5'b01110   // solo S0
`define ALU_TEST  5'b01111   // solo S0
`define ALU_NEG   5'b10000
`define ALU_ADDI  5'b10001
`define ALU_SUBI  5'b10010
`define ALU_SETCC 5'b10011
`define ALU_ANDI  5'b10100
`define ALU_ORI   5'b10101
`define ALU_XORI  5'b10110
`define ALU_SLLI  5'b10111
`define ALU_SRLI  5'b11000
`define ALU_SRAI  5'b11001
`define ALU_ROLI  5'b11010
`define ALU_MFPSW 5'b11011
`define ALU_MOVI  5'b11100
`define ALU_MOVH  5'b11101
`define ALU_CMPI  5'b11110   // solo S0
`define ALU_TESTI 5'b11111   // solo S0

//------------------------------------------------------------------------------
// Codigos de condicion (BRU y SETcc)
//------------------------------------------------------------------------------
`define COND_AL   3'b000
`define COND_EQ   3'b001
`define COND_NE   3'b010
`define COND_LT   3'b011
`define COND_GE   3'b100
`define COND_LTU  3'b101
`define COND_GEU  3'b110
`define COND_AUTH 3'b111

//------------------------------------------------------------------------------
// Posiciones de bit del PSW
//------------------------------------------------------------------------------
`define PSW_Z         0
`define PSW_N         1
`define PSW_C         2
`define PSW_V         3
`define PSW_AUTH      4
`define PSW_AUTHFAIL  5
`define PSW_EXC       6
`define PSW_CAUSE   9:7

// Indices dentro del vector compacto de banderas {V, C, N, Z}
`define FLG_Z 0
`define FLG_N 1
`define FLG_C 2
`define FLG_V 3

//------------------------------------------------------------------------------
// Codigos de causa de falla
//------------------------------------------------------------------------------
`define CAUSE_NONE     3'b000
`define CAUSE_ILLOP    3'b001
`define CAUSE_MISALIGN 3'b010
`define CAUSE_RANGE    3'b011
`define CAUSE_DENIED   3'b100
`define CAUSE_NOKEY    3'b101
`define CAUSE_WCONF    3'b110

`endif // CERBERO_DEFS_SVH
