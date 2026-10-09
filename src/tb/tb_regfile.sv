// =============================================================================
// tb_regfile.sv  -  Testbench autoverificable de regfile.sv
// Ejecutar desde src/build:  make regfile        Ondas: src/build/tb_regfile.vcd
// -----------------------------------------------------------------------------
// Cada verificación imprime una fila:
//   | Test | Verificación | Estímulo | Obtenido | Esperado | Estado |
// Al final imprime el total. Si hubo fallas termina con $fatal (make se detiene).
// =============================================================================
`timescale 1ns/1ps

module tb_regfile;

    // ---------------- Tamaños (iguales a los defaults del regfile) ----------
    localparam int NUM_REGISTERS        = 16;
    localparam int REGISTER_WIDTH       = 32;
    localparam int NUM_READ_PORTS       = 9;
    localparam int NUM_WRITE_PORTS      = 7;
    localparam int REGISTER_INDEX_WIDTH = 4;

    // ---------------- Señales conectadas al regfile -------------------------
    logic clk     = 1'b0;
    logic reset_n = 1'b0;

    logic [NUM_READ_PORTS-1:0][REGISTER_INDEX_WIDTH-1:0]  read_register_index = '0;
    logic [NUM_READ_PORTS-1:0][REGISTER_WIDTH-1:0]        read_register_value;

    logic [NUM_WRITE_PORTS-1:0]                           write_enable         = '0;
    logic [NUM_WRITE_PORTS-1:0][REGISTER_INDEX_WIDTH-1:0] write_register_index = '0;
    logic [NUM_WRITE_PORTS-1:0][REGISTER_WIDTH-1:0]       write_value          = '0;

    logic                                                 write_conflict_detected;
    logic [NUM_REGISTERS-1:0][REGISTER_WIDTH-1:0]         debug_register_values;

    // Instancia del módulo bajo prueba (.* conecta por nombre igual)
    regfile register_file_under_test (.*);

    // Reloj de 10 ns: posedge en t = 5, 15, 25...; negedge en t = 10, 20, 30...
    always #5 clk = ~clk;

    // Imitación del registro de segmentación ID/EX: captura en el FLANCO
    // POSITIVO lo que entrega el puerto de lectura 0. Es la "lectura en
    // posedge" de la convención del curso (la usa el test T13).
    logic [REGISTER_WIDTH-1:0] operand_captured_by_id_ex;
    always_ff @(posedge clk) operand_captured_by_id_ex <= read_register_value[0];

    // ---------------- Contadores e información de la prueba actual ----------
    int    total_checks         = 0;
    int    total_failures       = 0;
    int    checks_in_test       = 0;
    int    failures_in_test     = 0;
    string current_test_id      = "";
    string current_test_title   = "";
    string stimulus_description = "";
    string waveform_file_name;

    // Compara un valor obtenido contra el esperado e imprime una fila de la tabla
    task automatic check_value(input string       check_name,
                               input logic [31:0] observed_value,
                               input logic [31:0] expected_value);
        string result_text;
        total_checks++;
        checks_in_test++;
        if (observed_value === expected_value) begin
            result_text = "PASS";
        end else begin
            result_text = "FAIL";
            total_failures++;
            failures_in_test++;
        end
        $display("| %-3s | %-30s | %-50s | 0x%08h | 0x%08h | %s |",
                 current_test_id, check_name, stimulus_description,
                 observed_value, expected_value, result_text);
    endtask

    // Imprime el subtotal del test que termina
    task automatic print_test_subtotal();
        if (current_test_id != "")
            $display("|     | %-30s | %-50s |            |            | %0d/%0d |",
                     "subtotal", current_test_title,
                     checks_in_test - failures_in_test, checks_in_test);
    endtask

    // Cierra el test anterior y arranca uno nuevo
    task automatic start_test(input string test_id, input string test_title);
        print_test_subtotal();
        current_test_id      = test_id;
        current_test_title   = test_title;
        checks_in_test       = 0;
        failures_in_test     = 0;
        stimulus_description = "(estado actual)";
        $display("|-----|--------------------------------|----------------------------------------------------|------------|------------|------|");
        $display("| %-3s | %s", test_id, test_title);
    endtask

    // Valor de prueba fácil de reconocer en la onda y en la tabla:
    //   0xA<registro>B<puerto><etiqueta de 16 bits>
    // Ej.: make_test_value(5, 3, 16'h2000) = 0xA5B32000
    //      -> "registro 5, escrito por el puerto 3, en el test de etiqueta 2000"
    function automatic [31:0] make_test_value(input int register_number,
                                              input int write_port,
                                              input int test_tag);
        make_test_value = {4'hA, 4'(register_number), 4'hB, 4'(write_port), 16'(test_tag)};
    endfunction

    // Prepara una escritura en un puerto (se aplicará en el próximo negedge)
    task automatic prepare_write(input int          write_port,
                                 input int          register_number,
                                 input logic [31:0] value_to_write);
        write_enable[write_port]         = 1'b1;
        write_register_index[write_port] = REGISTER_INDEX_WIDTH'(register_number);
        write_value[write_port]          = value_to_write;
    endtask

    // Deja que el regfile escriba en el negedge y luego apaga todos los enables
    task automatic complete_write_cycle();
        @(negedge clk); #1;
        write_enable = '0;
    endtask

    // ---------------- Secuencia de pruebas -----------------------------------
    initial begin
        if (!$value$plusargs("VCD=%s", waveform_file_name)) waveform_file_name = "tb_regfile.vcd";
        $dumpfile(waveform_file_name);
        $dumpvars(0, tb_regfile);

        $display("| Test| Verificación                   | Estímulo                                           | Obtenido   | Esperado   | Estado |");

        // Reset activo durante 2 flancos negativos y luego se libera
        repeat (2) @(negedge clk);
        @(posedge clk); #1;
        reset_n = 1'b1;

        // T1 ------------------------------------------------------------------
        start_test("T1", "Reset: los 16 registros en cero");
        stimulus_description = "reset_n=0 durante 2 negedges";
        for (int register_number = 0; register_number < NUM_REGISTERS; register_number++)
            check_value($sformatf("R%0d", register_number),
                        debug_register_values[register_number], 32'd0);

        // T2 ------------------------------------------------------------------
        start_test("T2", "Escribir y leer los 16 registros (puerto 0)");
        for (int register_number = 0; register_number < NUM_REGISTERS; register_number++) begin
            @(posedge clk); #1;
            prepare_write(0, register_number, make_test_value(register_number, 0, 16'h1000 + register_number));
            complete_write_cycle();
        end
        for (int register_number = 0; register_number < NUM_REGISTERS; register_number++) begin
            read_register_index[0] = REGISTER_INDEX_WIDTH'(register_number);
            #1;
            stimulus_description = $sformatf("read_register_index[0]=R%0d", register_number);
            check_value($sformatf("lectura puerto 0, R%0d", register_number),
                        read_register_value[0],
                        make_test_value(register_number, 0, 16'h1000 + register_number));
        end

        // T3 ------------------------------------------------------------------
        start_test("T3", "R0 no esta cableado a cero");
        stimulus_description = "valor escrito en T2";
        check_value("R0 conserva su valor", debug_register_values[0], make_test_value(0, 0, 16'h1000));

        // T4 ------------------------------------------------------------------
        start_test("T4", "Cada puerto de escritura funciona solo");
        for (int write_port = 0; write_port < NUM_WRITE_PORTS; write_port++) begin
            @(posedge clk); #1;
            prepare_write(write_port, write_port + 2, make_test_value(write_port + 2, write_port, 16'h2000));
            stimulus_description = $sformatf("write_enable[%0d] -> R%0d", write_port, write_port + 2);
            complete_write_cycle();
            check_value($sformatf("puerto de escritura %0d", write_port),
                        debug_register_values[write_port + 2],
                        make_test_value(write_port + 2, write_port, 16'h2000));
        end

        // T5 ------------------------------------------------------------------
        start_test("T5", "7 escrituras simultaneas a registros distintos");
        @(posedge clk); #1;
        for (int write_port = 0; write_port < NUM_WRITE_PORTS; write_port++)
            prepare_write(write_port, 8 + write_port, make_test_value(8 + write_port, write_port, 16'h3000));
        stimulus_description = "write_enable[0..6] -> R8..R14, mismo ciclo";
        #0 check_value("sin conflicto", write_conflict_detected, 0);
        complete_write_cycle();
        for (int write_port = 0; write_port < NUM_WRITE_PORTS; write_port++)
            check_value($sformatf("R%0d", 8 + write_port),
                        debug_register_values[8 + write_port],
                        make_test_value(8 + write_port, write_port, 16'h3000));

        // T6 ------------------------------------------------------------------
        start_test("T6", "9 lecturas simultaneas a registros distintos");
        // El puerto de lectura p lee el registro 14 - p (R14, R13, ..., R6)
        for (int read_port = 0; read_port < NUM_READ_PORTS; read_port++)
            read_register_index[read_port] = REGISTER_INDEX_WIDTH'(14 - read_port);
        #1;
        stimulus_description = "read_register_index[0..8] = R14..R6";
        // Esperado: R8..R14 escritos en T5; R6 y R7 escritos en T4 (puertos 4 y 5)
        for (int read_port = 0; read_port < NUM_READ_PORTS; read_port++) begin
            int register_being_read;
            register_being_read = 14 - read_port;
            check_value($sformatf("lectura puerto %0d, R%0d", read_port, register_being_read),
                        read_register_value[read_port],
                        (register_being_read >= 8)
                            ? make_test_value(register_being_read, register_being_read - 8, 16'h3000)
                            : make_test_value(register_being_read, register_being_read - 2, 16'h2000));
        end

        // T7 ------------------------------------------------------------------
        start_test("T7", "Lo escrito en negedge se lee en el mismo ciclo");
        read_register_index[0] = 4'd5;
        @(posedge clk); #1;
        prepare_write(0, 5, 32'hCAFE_0005);
        stimulus_description = "escribir R5=0xcafe0005; leer antes/despues";
        check_value("antes del negedge: valor viejo", read_register_value[0], make_test_value(5, 3, 16'h2000));
        @(negedge clk); #1;
        write_enable = '0;
        check_value("despues del negedge: nuevo", read_register_value[0], 32'hCAFE_0005);
        #3;   // justo antes del siguiente posedge, que es cuando ID/EX captura
        check_value("antes del siguiente posedge", read_register_value[0], 32'hCAFE_0005);

        // T8 ------------------------------------------------------------------
        start_test("T8", "Conflicto: los 7 puertos al mismo registro");
        @(posedge clk); #1;
        for (int write_port = 0; write_port < NUM_WRITE_PORTS; write_port++)
            prepare_write(write_port, 1, make_test_value(1, write_port, 16'h4000));
        stimulus_description = "write_enable[0..6] -> R1, mismo ciclo";
        #0 check_value("conflicto detectado", write_conflict_detected, 1);
        complete_write_cycle();
        check_value("gana el puerto 0 (S0)", debug_register_values[1], make_test_value(1, 0, 16'h4000));

        // T9 ------------------------------------------------------------------
        start_test("T9", "Prioridad entre cada par de puertos vecinos");
        for (int higher_priority_port = 0; higher_priority_port < NUM_WRITE_PORTS - 1; higher_priority_port++) begin
            int lower_priority_port;
            lower_priority_port = higher_priority_port + 1;
            @(posedge clk); #1;
            prepare_write(lower_priority_port,  3, make_test_value(3, lower_priority_port,  16'h5000));
            prepare_write(higher_priority_port, 3, make_test_value(3, higher_priority_port, 16'h5000));
            stimulus_description = $sformatf("puertos %0d y %0d -> R3",
                                             higher_priority_port, lower_priority_port);
            complete_write_cycle();
            check_value($sformatf("gana el puerto %0d", higher_priority_port),
                        debug_register_values[3],
                        make_test_value(3, higher_priority_port, 16'h5000));
        end

        // T10 -----------------------------------------------------------------
        start_test("T10", "LW.INC con rd == rbase: gana el dato");
        @(posedge clk); #1;
        prepare_write(2, 12, 32'hDA7A_0000);   // puerto 2: dato cargado de memoria
        prepare_write(3, 12, 32'h0000_4004);   // puerto 3: base incrementada
        stimulus_description = "puerto 2 (dato) y puerto 3 (base) -> R12";
        complete_write_cycle();
        check_value("R12 = dato cargado", debug_register_values[12], 32'hDA7A_0000);

        // T11 -----------------------------------------------------------------
        start_test("T11", "write_enable=0 no escribe nada");
        @(posedge clk); #1;
        write_register_index = '0;   // todos los puertos apuntan a R0...
        write_value          = '1;   // ...con 0xFFFFFFFF, pero write_enable = 0
        stimulus_description = "indice=R0, valor=0xffffffff, enable=0";
        complete_write_cycle();
        check_value("R0 sin cambio", debug_register_values[0], make_test_value(0, 0, 16'h1000));
        check_value("sin conflicto con enable=0", write_conflict_detected, 0);

        // T12 -----------------------------------------------------------------
        // Convención del curso: escribir en negedge, leer (capturar) en posedge.
        //   ciclo k : posedge -> negedge (WB escribe R9) -> posedge (ID/EX captura)
        // El posedge que ABRE el ciclo k debe capturar el valor viejo y el que
        // lo CIERRA debe capturar el nuevo: la escritura de WB llega a tiempo
        // para el bundle que está en ID en ese mismo ciclo.
        start_test("T12", "Escribir en negedge, capturar en posedge");
        read_register_index[0] = 4'd9;
        @(posedge clk); #1;
        stimulus_description = "WB escribe R9=0x0BADC0DE en este ciclo";
        check_value("posedge que abre el ciclo: viejo", operand_captured_by_id_ex,
                    make_test_value(9, 1, 16'h3000));
        prepare_write(0, 9, 32'h0BAD_C0DE);
        complete_write_cycle();
        @(posedge clk); #1;
        check_value("posedge que cierra el ciclo: nuevo", operand_captured_by_id_ex, 32'h0BAD_C0DE);

        // T13 -----------------------------------------------------------------
        start_test("T13", "Reset borra todo despues de escribir");
        @(posedge clk); #1;
        reset_n = 1'b0;
        stimulus_description = "reset_n=0 durante un negedge";
        @(negedge clk); #1;
        reset_n = 1'b1;
        for (int register_number = 0; register_number < NUM_REGISTERS; register_number++)
            check_value($sformatf("R%0d", register_number),
                        debug_register_values[register_number], 32'd0);

        // ---------------- Resumen --------------------------------------------
        print_test_subtotal();
        $display("==================================================");
        if (total_failures == 0)
            $display(" PASS  regfile: %0d verificaciones OK", total_checks);
        else
            $display(" FAIL  regfile: %0d errores de %0d verificaciones", total_failures, total_checks);
        $display("==================================================");
        if (total_failures != 0) $fatal(1, "tb_regfile: hubo errores");
        $finish;
    end

    // Corta la simulación si algo se queda colgado
    initial begin
        #100000;
        $display("TIMEOUT: la simulacion no termino a tiempo");
        $finish;
    end

endmodule