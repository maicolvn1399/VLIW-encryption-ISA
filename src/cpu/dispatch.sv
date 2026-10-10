// ============================================================================
// Módulo: dispatch.sv (Etapa de Decodificación y Despacho)
// Arquitectura: CERBERO VLIW
// Descripción: Trocea el bundle de 128 bits en sus 5 slots. Extrae campos 
//              posicionales, detecta instrucciones ilegales (ILLOP) y previene 
//              conflictos de escritura paralela (WCONF).
// ============================================================================

module dispatch (
    input  logic [127:0] bundle,

    output logic [31:0] s0_inst, s1_inst, s2_inst,
    output logic [15:0] s3_inst, s4_inst,

    output logic        s0_fault_val,
    output logic [2:0]  s0_fault_cause,
    output logic        s1_fault_val,
    output logic [2:0]  s1_fault_cause,
    output logic        s2_fault_val,
    output logic [2:0]  s2_fault_cause,
    output logic        s3_fault_val,
    output logic [2:0]  s3_fault_cause,
    output logic        s4_fault_val,
    output logic [2:0]  s4_fault_cause
);

    // ========================================================================
    // 1. PARTICIÓN DEL BUNDLE (Uso de 'wire' para asignación continua)
    // ========================================================================
    
    assign s0_inst = bundle[127:96];
    wire [4:0] s0_opcode = s0_inst[31:27];
    wire [3:0] s0_rd     = s0_inst[26:23];
    
    assign s1_inst = bundle[95:64];
    wire [4:0] s1_opcode = s1_inst[31:27];
    wire [3:0] s1_rd     = s1_inst[26:23];

    assign s2_inst = bundle[63:32];
    wire [4:0] s2_opcode = s2_inst[31:27];
    wire [3:0] s2_rd     = s2_inst[26:23];
    wire [3:0] s2_rbase  = s2_inst[22:19];

    assign s3_inst = bundle[31:16];
    wire [2:0] s3_opcode = s3_inst[15:13];
    wire [3:0] s3_rd     = s3_inst[8:5];   
    wire [2:0] s3_par    = s3_inst[12:10]; 

    assign s4_inst = bundle[15:0];
    wire [2:0] s4_opcode = s4_inst[15:13];
    wire [3:0] s4_rd     = s4_inst[8:5];


    // ========================================================================
    // 2. DETECCIÓN DE INSTRUCCIONES ILEGALES (ILLOP - CAUSE: 001)
    // ========================================================================
    logic s0_illop, s1_illop, s2_illop, s3_illop, s4_illop;

    always_comb begin
        // --- S0 ILLOP ---
        s0_illop = 1'b0;
        if (s0_opcode == 5'b10011 || s0_opcode == 5'b11011) s0_illop = 1'b1; 
        if ((!s0_opcode[4] || s0_opcode == 5'b10000) && s0_inst[14:0] != 15'b0) s0_illop = 1'b1;

        // --- S1 ILLOP ---
        s1_illop = 1'b0;
        if (s1_opcode == 5'b10011 || s1_opcode == 5'b11011) s1_illop = 1'b1;
        if ((!s1_opcode[4] || s1_opcode == 5'b10000) && s1_inst[14:0] != 15'b0) s1_illop = 1'b1;
        if (s1_opcode == 5'b01110 || s1_opcode == 5'b01111 || 
            s1_opcode == 5'b11110 || s1_opcode == 5'b11111) s1_illop = 1'b1;

        // --- S2 ILLOP ---
        s2_illop = 1'b1; 
        case (s2_opcode)
            5'b00000, 5'b00010, 5'b00011, 5'b00100, 5'b00101, 5'b00110, 
            5'b01010, 5'b01100, 5'b01110, 5'b10110, 5'b11110: s2_illop = 1'b0;
        endcase

        // --- S3 ILLOP ---
        s3_illop = 1'b0;
        case (s3_opcode)
            3'b000: if (s3_inst[12:0] != 0) s3_illop = 1'b1;
            3'b001, 3'b010: if (s3_inst[5:0] != 0) s3_illop = 1'b1; 
            3'b011: if (s3_inst[4:0] != 0) s3_illop = 1'b1;         
            3'b100: if (s3_inst[12:11] != 0 || s3_inst[4:0] != 0) s3_illop = 1'b1; 
            3'b101: if (s3_inst[8:0] != 0) s3_illop = 1'b1;         
            3'b110: begin 
                if (s3_inst[12] == 1'b0 && s3_inst[4] != 1'b0) s3_illop = 1'b1; 
                if (s3_inst[12] == 1'b1 && s3_inst[11:10] == 2'b11) s3_illop = 1'b1; 
            end
            3'b111: s3_illop = 1'b1; 
        endcase

        // --- S4 ILLOP ---
        s4_illop = 1'b0;
        case (s4_opcode)
            3'b000: if (s4_inst[12:0] != 0) s4_illop = 1'b1;
            3'b011, 3'b100: if (s4_inst[9] != 0 || s4_inst[4:0] != 0) s4_illop = 1'b1; 
            3'b101: if (s4_inst[12:0] != 0) s4_illop = 1'b1; 
            3'b110, 3'b111: s4_illop = 1'b1; 
        endcase
    end


    // ========================================================================
    // 3. DETECCIÓN DE ESCRITURAS A REGISTROS PARA CONFLICTOS (WCONF)
    // ========================================================================
    logic s0_we, s1_we, s2_we_rd, s2_we_base, s3_we_rd, s3_we_par, s4_we_r15;
    
    always_comb begin
        s0_we = (s0_opcode != 5'b00000) && (s0_opcode != 5'b01110) && (s0_opcode != 5'b01111) && 
                (s0_opcode != 5'b11110) && (s0_opcode != 5'b11111) && !s0_illop;
        
        s1_we = (s1_opcode != 5'b00000) && !s1_illop;

        s2_we_rd   = (s2_opcode != 5'b00000) && (s2_opcode[3] == 1'b0) && !s2_illop;
        s2_we_base = (s2_opcode != 5'b00000) && (s2_opcode[4] == 1'b1) && !s2_illop;

        s3_we_rd  = (s3_opcode == 3'b110) && !s3_illop;
        s3_we_par = (s3_opcode == 3'b001 || s3_opcode == 3'b010) && !s3_illop;
        
        s4_we_r15 = (s4_opcode == 3'b010 || s4_opcode == 3'b100) && !s4_illop;
    end


    // ========================================================================
    // 4. PREVALENCIA Y RESOLUCIÓN DEL WCONF (S0 > S1 > S2 > S3 > S4)
    // ========================================================================
    logic s1_wconf, s2_wconf, s3_wconf, s4_wconf;
    wire [3:0] p_reg0 = {s3_par, 1'b0}; 
    wire [3:0] p_reg1 = {s3_par, 1'b1}; 
    
    always_comb begin
        s1_wconf = s1_we && s0_we && (s1_rd == s0_rd);

        s2_wconf = (s2_we_rd   && ((s0_we && s2_rd == s0_rd)    || (s1_we && s2_rd == s1_rd))) || 
                   (s2_we_base && ((s0_we && s2_rbase == s0_rd) || (s1_we && s2_rbase == s1_rd)));

        s3_wconf = (s3_we_rd && ((s0_we && s3_rd == s0_rd) || (s1_we && s3_rd == s1_rd) || (s2_we_rd && s3_rd == s2_rd) || (s2_we_base && s3_rd == s2_rbase))) ||
                   (s3_we_par && (
                       (s0_we && (p_reg0 == s0_rd || p_reg1 == s0_rd)) || 
                       (s1_we && (p_reg0 == s1_rd || p_reg1 == s1_rd)) || 
                       (s2_we_rd && (p_reg0 == s2_rd || p_reg1 == s2_rd)) || 
                       (s2_we_base && (p_reg0 == s2_rbase || p_reg1 == s2_rbase))
                   ));

        s4_wconf = s4_we_r15 && (
                       (s0_we && 4'd15 == s0_rd) || 
                       (s1_we && 4'd15 == s1_rd) || 
                       (s2_we_rd && 4'd15 == s2_rd) || 
                       (s2_we_base && 4'd15 == s2_rbase) ||
                       (s3_we_rd && 4'd15 == s3_rd) ||
                       (s3_we_par && (4'd15 == p_reg0 || 4'd15 == p_reg1))
                   );
    end


    // ========================================================================
    // 5. ASIGNACIÓN FINAL DE SEÑALES DE FALLA
    // ========================================================================
    
    assign s0_fault_val   = s0_illop;
    assign s0_fault_cause = s0_illop ? 3'b001 : 3'b000;

    assign s1_fault_val   = s1_illop | s1_wconf;
    assign s1_fault_cause = s1_illop ? 3'b001 : (s1_wconf ? 3'b110 : 3'b000);

    assign s2_fault_val   = s2_illop | s2_wconf;
    assign s2_fault_cause = s2_illop ? 3'b001 : (s2_wconf ? 3'b110 : 3'b000);

    assign s3_fault_val   = s3_illop | s3_wconf;
    assign s3_fault_cause = s3_illop ? 3'b001 : (s3_wconf ? 3'b110 : 3'b000);

    assign s4_fault_val   = s4_illop | s4_wconf;
    assign s4_fault_cause = s4_illop ? 3'b001 : (s4_wconf ? 3'b110 : 3'b000);

endmodule