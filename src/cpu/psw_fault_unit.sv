// =====================================================================================
// Módulo: psw_fault_unit.sv (Program Status Word y Unidad de Fallos)
// Arquitectura: CERBERO VLIW
// Descripción: Centraliza las banderas de S0, el estado de la bóveda (AUTH),
//              y resuelve colisiones de fallas con prioridad S0 > S1 > S2 > S3 > S4.
// =====================================================================================

module psw_fault_unit (
    input  logic        clk,
    input  logic        rst,

    // --- Banderas exclusivas de ALU-0 (Slot S0) ---
    input  logic        alu0_flags_we, // Habilita escritura (ej. instrucciones CMP, TEST)
    input  logic        alu0_z,
    input  logic        alu0_n,
    input  logic        alu0_c,
    input  logic        alu0_v,

    // --- Señales de control de Bóveda ---
    input  logic        vault_login_ok,    // Pone AUTH = 1
    input  logic        vault_login_fail,  // Pone AUTHFAIL = 1
    input  logic        vault_logout,      // Limpia AUTH (logout manual o salida de región segura)

    // --- Señales de fallas por slot (valid + cause de 3 bits) ---
    input  logic        s0_fault_val,
    input  logic [2:0]  s0_fault_cause,
    input  logic        s1_fault_val,
    input  logic [2:0]  s1_fault_cause,
    input  logic        s2_fault_val,
    input  logic [2:0]  s2_fault_cause,
    input  logic        s3_fault_val,
    input  logic [2:0]  s3_fault_cause,
    input  logic        s4_fault_val,
    input  logic [2:0]  s4_fault_cause,

    // --- Salidas ---
    output logic [31:0] psw_out,     // Registro PSW completo de 32 bits
    output logic        auth_active  // Señal combinacional para el despachador/bóveda
);

    // Registros internos del PSW
    logic z_reg, n_reg, c_reg, v_reg;
    logic auth_reg, authfail_reg;
    logic exc_reg;
    logic [2:0] cause_reg;

    // Lógica combinacional para resolución de prioridad (S0 > S1 > S2 > S3 > S4)
    logic       any_fault;
    logic [2:0] highest_priority_cause;

    always_comb begin
        any_fault = s0_fault_val | s1_fault_val | s2_fault_val | s3_fault_val | s4_fault_val;

        // Multiplexor de prioridad descendente
        if (s0_fault_val)      highest_priority_cause = s0_fault_cause;
        else if (s1_fault_val) highest_priority_cause = s1_fault_cause;
        else if (s2_fault_val) highest_priority_cause = s2_fault_cause;
        else if (s3_fault_val) highest_priority_cause = s3_fault_cause;
        else if (s4_fault_val) highest_priority_cause = s4_fault_cause;
        else                   highest_priority_cause = 3'b000;
    end

    // Lógica secuencial
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            z_reg        <= 1'b0;
            n_reg        <= 1'b0;
            c_reg        <= 1'b0;
            v_reg        <= 1'b0;
            auth_reg     <= 1'b0;
            authfail_reg <= 1'b0;
            exc_reg      <= 1'b0;
            cause_reg    <= 3'b000;
        end else begin
            // 1. Actualización de banderas (Solo cuando ALU-0 lo solicita)
            if (alu0_flags_we) begin
                z_reg <= alu0_z;
                n_reg <= alu0_n;
                c_reg <= alu0_c;
                v_reg <= alu0_v;
            end

            // 2. Manejo de fallas y estado de Bóveda
            if (any_fault) begin
                // Cierre de sesión automático y registro de falla
                exc_reg   <= 1'b1;
                cause_reg <= highest_priority_cause;
                auth_reg  <= 1'b0; 
            end else begin
                // Comportamiento normal si no hay fallas en el ciclo
                if (vault_login_ok) begin
                    auth_reg     <= 1'b1;
                    authfail_reg <= 1'b0;
                end else if (vault_login_fail) begin
                    authfail_reg <= 1'b1;
                end

                if (vault_logout) begin
                    auth_reg <= 1'b0;
                end
            end
        end
    end

    // Ensamblaje del registro PSW de 32 bits según la especificación
    // Bits: [31:10] Reservado(0) | [9:7] CAUSE | [6] EXC | [5] AUTHFAIL | [4] AUTH | [3] V | [2] C | [1] N | [0] Z
    assign psw_out = {22'b0, cause_reg, exc_reg, authfail_reg, auth_reg, v_reg, c_reg, n_reg, z_reg};
    
    // Salida directa para validación continua de privilegios en el pipeline
    assign auth_active = auth_reg;

endmodule