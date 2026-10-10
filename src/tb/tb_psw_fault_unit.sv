`timescale 1ns/1ps

// ============================================================================
// Módulo: tb_psw_fault_unit.sv (Testbench para Program Status Word y Unidad de Fallos)
// Arquitectura: CERBERO VLIW
// Descripción: Valida actualización de banderas desde S0, auto-logout y 
//              la prioridad de fallas simultáneas (S0 > S1 > S2 > S3 > S4).
// ============================================================================

module tb_psw_fault_unit;

    // Entradas
    logic clk;
    logic rst;
    logic alu0_flags_we;
    logic alu0_z, alu0_n, alu0_c, alu0_v;
    logic vault_login_ok, vault_login_fail, vault_logout;
    
    logic       s0_fault_val;
    logic [2:0] s0_fault_cause;
    logic       s1_fault_val;
    logic [2:0] s1_fault_cause;
    logic       s2_fault_val;
    logic [2:0] s2_fault_cause;
    logic       s3_fault_val;
    logic [2:0] s3_fault_cause;
    logic       s4_fault_val;
    logic [2:0] s4_fault_cause;

    // Salidas
    logic [31:0] psw_out;
    logic        auth_active;

    // Instancia del módulo a probar (UUT)
    psw_fault_unit uut (
        .clk(clk),
        .rst(rst),
        .alu0_flags_we(alu0_flags_we),
        .alu0_z(alu0_z), .alu0_n(alu0_n), .alu0_c(alu0_c), .alu0_v(alu0_v),
        .vault_login_ok(vault_login_ok),
        .vault_login_fail(vault_login_fail),
        .vault_logout(vault_logout),
        .s0_fault_val(s0_fault_val), .s0_fault_cause(s0_fault_cause),
        .s1_fault_val(s1_fault_val), .s1_fault_cause(s1_fault_cause),
        .s2_fault_val(s2_fault_val), .s2_fault_cause(s2_fault_cause),
        .s3_fault_val(s3_fault_val), .s3_fault_cause(s3_fault_cause),
        .s4_fault_val(s4_fault_val), .s4_fault_cause(s4_fault_cause),
        .psw_out(psw_out),
        .auth_active(auth_active)
    );

    // Generación de reloj (100 MHz)
    always #5 clk = ~clk;

    // Tarea auxiliar para limpiar las señales de entrada de fallas
    task clear_faults();
        s0_fault_val = 0; s0_fault_cause = 3'b000;
        s1_fault_val = 0; s1_fault_cause = 3'b000;
        s2_fault_val = 0; s2_fault_cause = 3'b000;
        s3_fault_val = 0; s3_fault_cause = 3'b000;
        s4_fault_val = 0; s4_fault_cause = 3'b000;
    endtask

    initial begin
        // 1. Configuración de volcado para GTKWave
        $dumpfile("tb_psw_fault_unit.vcd"); 
        $dumpvars(0, tb_psw_fault_unit);

        // Inicialización
        clk = 0;
        alu0_flags_we = 0;
        alu0_z = 0; alu0_n = 0; alu0_c = 0; alu0_v = 0;
        vault_login_ok = 0; vault_login_fail = 0; vault_logout = 0;
        clear_faults();

        // 2. Aplicar reset
        $display("[Test] Aplicando reset...");
        rst = 1; #10;
        rst = 0; #10;
        if (psw_out == 32'b0) $display("  -> Exito: PSW inicializado en 0.");

        // 3. Prueba de actualización de Banderas ALU-0
        $display("[Test] Escribiendo Banderas desde S0 (Z=1, C=1)...");
        alu0_flags_we = 1; alu0_z = 1; alu0_c = 1; alu0_n = 0; alu0_v = 0;
        #10;
        alu0_flags_we = 0;
        // Bits de flags: V(3), C(2), N(1), Z(0) => 0101 (Hex 5)
        if (psw_out[3:0] == 4'b0101) $display("  -> Exito: Banderas ALU-0 actualizadas correctamente.");

        // 4. Prueba de autenticación en Bóveda
        $display("[Test] Simulando LOGIN exitoso...");
        vault_login_ok = 1; #10;
        vault_login_ok = 0; #10;
        if (psw_out[4] == 1'b1) $display("  -> Exito: Bit AUTH encendido.");

        // 5. Prueba de colisión de fallas (prioridad S2 sobre S3) y Auto-Logout
        $display("[Test] Inyectando fallas simultaneas: MISALIGN en S2 y NOKEY en S3...");
        // MISALIGN = 010, NOKEY = 101
        s2_fault_val = 1; s2_fault_cause = 3'b010;
        s3_fault_val = 1; s3_fault_cause = 3'b101;
        #10;
        clear_faults();
        #10;

        // Verificaciones
        // CAUSE está en los bits [9:7]. Debe ser 010 (MISALIGN) por prioridad de S2.
        if (psw_out[9:7] == 3'b010) 
            $display("  -> Exito: Prioridad resuelta correctamente (Gano S2 con CAUSE 010).");
        else 
            $display("  -> ERROR: Prioridad incorrecta. CAUSE = %b", psw_out[9:7]);

        // EXC está en el bit [6]. Debe ser 1.
        if (psw_out[6] == 1'b1) 
            $display("  -> Exito: Bit EXC encendido.");

        // AUTH está en el bit [4]. Debe haber regresado a 0 por el auto-logout.
        if (psw_out[4] == 1'b0) 
            $display("  -> Exito: Auto-Logout disparado. Bit AUTH se apago tras la falla.");

        // 6. Fin de la simulación
        $display("Simulacion del PSW completada.");
        $finish;
    end

endmodule