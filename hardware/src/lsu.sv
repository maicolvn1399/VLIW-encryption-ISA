// =================================================================================
// Módulo: lsu.sv (Slot S2 - Load/Store Unit)
// Arquitectura: CERBERO VLIW
// Descripción: Maneja cargas/almacenamientos con desplazamiento y post-incremento.
// =================================================================================

module lsu (
    input  logic [4:0]  opcode,        // Opcode de 5 bits del Slot S2
    input  logic [3:0]  rd_rs_idx,     // Índice del registro rd (load) o rs_dato (store)
    input  logic [3:0]  rbase_idx,     // Índice del registro base
    input  logic [31:0] rbase_val,     // Valor leído del registro base
    input  logic [31:0] rs_data_val,   // Valor del registro a almacenar (store)
    input  logic [18:0] imm19,         // Inmediato de 19 bits con signo
    input  logic [31:0] mem_read_data, // Dato leído desde la RAM de datos

    output logic [31:0] eff_addr,      // Dirección efectiva enviada a DMEM
    output logic [31:0] mem_write_data,// Dato procesado a escribir en DMEM
    output logic        mem_we,        // Habilitador de escritura en DMEM
    output logic [3:0]  byte_enable,   // Máscara de bytes para la RAM
    output logic [31:0] rd_load_data,  // Dato cargado para escribir en rd
    output logic [31:0] rbase_updated, // Nuevo valor para rbase (variantes .INC)
    output logic        rbase_write_en // Habilitador de escritura para el incremento de rbase
);

    // Desglose del opcode de S2
    wire is_inc = opcode[4];   // 1 = Post-incremento
    wire is_st  = opcode[3];   // 0 = Load, 1 = Store
    wire [1:0] tam = opcode[2:1]; // 01 = Byte, 10 = Half, 11 = Word
    wire is_unsigned = opcode[0]; // 1 = Relleno con ceros (LBU, LHU)

    // Extensión de signo del inmediato
    logic [31:0] sign_ext_imm;
    assign sign_ext_imm = {{13{imm19[18]}}, imm19};

    // Dirección efectiva: En post-incremento es la base pura, de lo contrario es Base + Imm
    assign eff_addr = is_inc ? rbase_val : (rbase_val + sign_ext_imm);

    // Puntero base actualizado tras post-incremento
    assign rbase_updated = rbase_val + sign_ext_imm;

    // Conflicto límite: Si rd == rbase en LW.INC, se prioriza el dato leído
    assign rbase_write_en = is_inc && !(~is_st && (rd_rs_idx == rbase_idx));

    // Control de escritura en memoria
    assign mem_we = is_st && (opcode != 5'b00000);

    // Selección de byte enable y alineación de datos de escritura (Store)
    always_comb begin
        byte_enable = 4'b0000;
        mem_write_data = 32'b0;

        if (is_st) begin
            case (tam)
                2'b01: begin // Byte (SB)
                    byte_enable = 4'b0001 << eff_addr[1:0];
                    mem_write_data = rs_data_val << (eff_addr[1:0] * 8);
                end
                2'b10: begin // Media Palabra (SH)
                    byte_enable = 4'b0011 << eff_addr[1:0];
                    mem_write_data = rs_data_val << (eff_addr[1:0] * 8);
                end
                2'b11: begin // Palabra Completa (SW, SW.INC)
                    byte_enable = 4'b1111;
                    mem_write_data = rs_data_val;
                end
                default: byte_enable = 4'b0000;
            endcase
        end
    end

    // Procesamiento de datos leídos (Load)
    always_comb begin
        rd_load_data = 32'b0;

        if (!is_st && opcode != 5'b00000) begin
            case (tam)
                2'b01: begin // Byte (LB, LBU)
                    logic [7:0] raw_byte;
                    raw_byte = mem_read_data >> (eff_addr[1:0] * 8);
                    rd_load_data = is_unsigned ? {24'b0, raw_byte} : {{24{raw_byte[7]}}, raw_byte};
                end
                2'b10: begin // Half (LH, LHU)
                    logic [15:0] raw_half;
                    raw_half = mem_read_data >> (eff_addr[1:0] * 8);
                    rd_load_data = is_unsigned ? {16'b0, raw_half} : {{16{raw_half[15]}}, raw_half};
                end
                2'b11: begin // Word (LW, LW.INC)
                    rd_load_data = mem_read_data;
                end
                default: rd_load_data = 32'b0;
            endcase
        end
    end

endmodule