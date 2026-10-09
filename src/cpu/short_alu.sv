// =======================================================================================
// Módulo: short_alu.sv (Slot S3 - ALU Corta 16-bit Tipo AC)
// Arquitectura: CERBERO VLIW
// Descripción: Ejecuta operaciones de 32 bits con formato destructivo (rd <- rd op op2).
//              No afecta las banderas del PSW.
// =======================================================================================

module short_alu (
    input  logic        i_bit,         // 0: Registro rs2, 1: Inmediato imm5
    input  logic [2:0]  subop,         // Código de suboperación (000 - 111)
    input  logic [31:0] rd_val,        // Valor del registro destino (primer operando)
    input  logic [31:0] rs2_val,       // Valor del registro rs2 (si i = 0)
    input  logic [4:0]  imm5,          // Inmediato de 5 bits sin signo (si i = 1)
    output logic [31:0] result         // Resultado a reescribir en rd
);

    logic [31:0] operand2;

    // Extensión con ceros del inmediato de 5 bits cuando i = 1
    assign operand2 = i_bit ? {27'b0, imm5} : rs2_val;

    always_comb begin
        case (subop)
            3'b000: result = rd_val + operand2;                 // ADD.S / ADDI.S
            3'b001: result = rd_val - operand2;                 // SUB.S / SUBI.S
            3'b010: result = rd_val & operand2;                 // AND.S / ANDI.S
            3'b011: result = rd_val | operand2;                 // OR.S  / ORI.S
            3'b100: result = rd_val ^ operand2;                 // XOR.S / XORI.S
            3'b101: result = operand2;                          // MOV.S / MOVI.S
            3'b110: result = i_bit ? 32'b0 : ~rd_val;           // NOT.S (solo i=0)
            3'b111: result = i_bit ? 32'b0 : -rd_val;           // NEG.S (solo i=0)
            default: result = 32'b0;
        endcase
    end

endmodule