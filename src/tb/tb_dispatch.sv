`timescale 1ns/1ps

// ============================================================================
// Módulo: tb_dispatch.sv (Testbench para la etapa de despacho)
// Arquitectura: CERBERO VLIW
// ============================================================================

module tb_dispatch;

    logic [127:0] bundle;
    logic [31:0] s0_inst, s1_inst, s2_inst;
    logic [15:0] s3_inst, s4_inst;

    logic        s0_fault_val; logic [2:0] s0_fault_cause;
    logic        s1_fault_val; logic [2:0] s1_fault_cause;
    logic        s2_fault_val; logic [2:0] s2_fault_cause;
    logic        s3_fault_val; logic [2:0] s3_fault_cause;
    logic        s4_fault_val; logic [2:0] s4_fault_cause;

    dispatch uut (
        .bundle(bundle),
        .s0_inst(s0_inst), .s1_inst(s1_inst), .s2_inst(s2_inst),
        .s3_inst(s3_inst), .s4_inst(s4_inst),
        .s0_fault_val(s0_fault_val), .s0_fault_cause(s0_fault_cause),
        .s1_fault_val(s1_fault_val), .s1_fault_cause(s1_fault_cause),
        .s2_fault_val(s2_fault_val), .s2_fault_cause(s2_fault_cause),
        .s3_fault_val(s3_fault_val), .s3_fault_cause(s3_fault_cause),
        .s4_fault_val(s4_fault_val), .s4_fault_cause(s4_fault_cause)
    );

    initial begin
        $dumpfile("tb_dispatch.vcd");
        $dumpvars(0, tb_dispatch);

        // --------------------------------------------------------------------
        // Prueba 1: Decodificación Normal (Ejemplo modificado sin conflictos)
        // --------------------------------------------------------------------
        $display("---------------------------------------------------------");
        $display("[Test 1] Decodificacion Normal (Libre de conflictos WCONF)");
        $display("  -> addi r10, r10, #4 | nop | lw.inc r12, #0(r14) | f4e p0, k0, #0 | nop ;");
        
        // Bundle inyectado libre de choques de registros:
        bundle = 128'h8D500004_00000000_B6700000_2000_0000;
        #10;
        
        if (s0_inst == 32'h8D500004) $display("  -> Exito: S0 extraido correctamente: 0x%08X", s0_inst);
        if (s1_inst == 32'h00000000) $display("  -> Exito: S1 extraido correctamente: 0x%08X", s1_inst);
        if (s2_inst == 32'hB6700000) $display("  -> Exito: S2 extraido correctamente: 0x%08X", s2_inst);
        if (s3_inst == 16'h2000)     $display("  -> Exito: S3 extraido correctamente: 0x%04X", s3_inst);
        if (s4_inst == 16'h0000)     $display("  -> Exito: S4 extraido correctamente: 0x%04X", s4_inst);

        if (!s0_fault_val && !s1_fault_val && !s2_fault_val && !s3_fault_val && !s4_fault_val)
            $display("  -> Exito: Ninguna falla reportada (operacion legal).");
        else
            $display("  -> ERROR: Se detectaron fallas inesperadas.");

        // --------------------------------------------------------------------
        // Prueba 2: Conflicto de Escritura Paralela (WCONF)
        // --------------------------------------------------------------------
        $display("---------------------------------------------------------");
        $display("[Test 2] Conflicto de Escritura (WCONF)");
        $display("  -> S0 escribe en R5 (addi r5, r0, #1)");
        $display("  -> S1 escribe en R5 (movi r5, #2)");
        
        bundle = 128'h8A800001_E2800002_00000000_0000_0000;
        #10;
        
        if (s0_fault_val == 0) 
            $display("  -> Exito: S0 no genero falla (Tiene la maxima prioridad).");
        if (s1_fault_val == 1 && s1_fault_cause == 3'b110)
            $display("  -> Exito: S1 detecto WCONF (causa 110) y desactivo su instruccion.");
        else
            $display("  -> ERROR: S1 no detecto WCONF correctamente.");

        // --------------------------------------------------------------------
        // Prueba 3: Instrucción Ilegal Temprana (ILLOP)
        // --------------------------------------------------------------------
        $display("---------------------------------------------------------");
        $display("[Test 3] Instruccion Ilegal (ILLOP)");
        $display("  -> S1 intenta ejecutar 'cmp r1, r2' (Comparaciones exclusivas de S0)");
        
        bundle = 128'h00000000_70090000_00000000_0000_0000;
        #10;

        if (s1_fault_val == 1 && s1_fault_cause == 3'b001)
            $display("  -> Exito: S1 detecto ILLOP (causa 001).");
        else
            $display("  -> ERROR: S1 no detecto ILLOP correctamente.");

        $display("---------------------------------------------------------");
        $display("Simulacion del despachador completada.");
        $finish;
    end
endmodule