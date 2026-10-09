// =============================================================================
// regfile.sv  -  Banco de registros de CERBERO
// CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4
// -----------------------------------------------------------------------------
// Qué implementa (isa.md, secciones 1.1 y 9):
//   - 16 registros de propósito general de 32 bits (R0..R15).
//     NINGUNO está cableado a cero: R0 es un registro normal.
//   - 9 puertos de lectura y 7 puertos de escritura, que es lo máximo que un
//     bundle de 5 slots puede pedir en un mismo ciclo.
//
// Temporización (convención del curso: leer en posedge, escribir en negedge):
//   - ESCRITURA en el flanco NEGATIVO del reloj.
//   - LECTURA combinacional; el registro de segmentación ID/EX la captura en el
//     flanco POSITIVO. Así, un valor que WB escribe a mitad de ciclo ya es
//     visible para ID antes del siguiente posedge: con eso se cumple la
//     latencia uniforme de 3 bundles del ISA sin forwarding.
//
// Asignación de puertos (sugerida para top/dispatch; este módulo no la impone).
// El número de puerto de escritura ES su prioridad: 0 = prioridad máxima.
//
//   Puerto de lectura                  Puerto de escritura
//   0  S0  rs1                         0  S0  rd
//   1  S0  rs2                         1  S1  rd
//   2  S1  rs1                         2  S2  rd (dato cargado de memoria)
//   3  S1  rs2                         3  S2  rbase (post-incremento .INC)
//   4  S2  rbase                       4  S3  L del par / rd de la ALU corta
//   5  S2  rs_dato (dato del store)    5  S3  R del par
//   6  S3  L del par / rd ALU corta    6  S4  R15 (enlace de JAL/JALR)
//   7  S3  R del par / rs ALU corta
//   8  S4  rs (destino de JR/JALR)
//
// Conflicto de escritura: si dos puertos habilitados escriben el mismo
// registro, gana el de MENOR número de puerto. Con la asignación de arriba:
//   - Se cumple la prioridad del ISA S0 > S1 > S2 > S3 > S4.
//   - En LW.INC con rd == rbase gana el dato cargado (puerto 2 antes que 3),
//     como pide isa.md sección 4.
// La salida `write_conflict_detected` solo avisa; la detección oficial de
// WCONF para el PSW se hace en la etapa ID (dispatch).
//
// Escrituras anuladas: si un slot falló, quien arma el bundle pone en 0 el
// `write_enable` de ese puerto. Este módulo no sabe nada de fallas.
// =============================================================================

module regfile #(
    parameter  int NUM_REGISTERS        = 16,  // cantidad de registros (R0..R15)
    parameter  int REGISTER_WIDTH       = 32,  // bits por registro
    parameter  int NUM_READ_PORTS       = 9,   // lecturas simultáneas por ciclo
    parameter  int NUM_WRITE_PORTS      = 7,   // escrituras simultáneas por ciclo
    localparam int REGISTER_INDEX_WIDTH = $clog2(NUM_REGISTERS)  // bits para nombrar un registro (4)
)(
    input  logic clk,
    input  logic reset_n,   // reset síncrono, activo en bajo (actúa en el negedge)

    // ---- Lectura (combinacional) -------------------------------------------
    // read_register_index[p] : qué registro lee el puerto de lectura p
    // read_register_value[p] : valor actual de ese registro
    input  logic [NUM_READ_PORTS-1:0][REGISTER_INDEX_WIDTH-1:0]  read_register_index,
    output logic [NUM_READ_PORTS-1:0][REGISTER_WIDTH-1:0]        read_register_value,

    // ---- Escritura (flanco negativo) ---------------------------------------
    // write_enable[p]         : 1 = el puerto de escritura p escribe este ciclo
    // write_register_index[p] : a qué registro escribe
    // write_value[p]          : qué valor escribe
    input  logic [NUM_WRITE_PORTS-1:0]                           write_enable,
    input  logic [NUM_WRITE_PORTS-1:0][REGISTER_INDEX_WIDTH-1:0] write_register_index,
    input  logic [NUM_WRITE_PORTS-1:0][REGISTER_WIDTH-1:0]       write_value,

    // ---- Diagnóstico -------------------------------------------------------
    output logic                                                 write_conflict_detected, // 2+ puertos habilitados al mismo registro
    output logic [NUM_REGISTERS-1:0][REGISTER_WIDTH-1:0]         debug_register_values    // los 16 registros, para testbenches
);

    // -------------------------------------------------------------------------
    // Almacenamiento: register_storage[n] es el registro Rn
    // -------------------------------------------------------------------------
    logic [REGISTER_WIDTH-1:0] register_storage [0:NUM_REGISTERS-1];

    // -------------------------------------------------------------------------
    // Lectura combinacional: un multiplexor 16 a 1 por puerto de lectura.
    // El registro de segmentación ID/EX captura estos valores en el posedge.
    // -------------------------------------------------------------------------
    genvar read_port;
    generate
        for (read_port = 0; read_port < NUM_READ_PORTS; read_port++) begin : g_read_ports
            assign read_register_value[read_port] =
                register_storage[read_register_index[read_port]];
        end
    endgenerate

    // Copia directa de los 16 registros para que los testbenches los revisen
    // sin gastar puertos de lectura.
    genvar register_number;
    generate
        for (register_number = 0; register_number < NUM_REGISTERS; register_number++) begin : g_debug_values
            assign debug_register_values[register_number] = register_storage[register_number];
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Escritura en el flanco negativo, con prioridad por número de puerto.
    //
    // Los puertos se recorren del de MENOR prioridad (el último) al de MAYOR
    // prioridad (el 0). Con asignaciones no bloqueantes (<=), si un mismo
    // registro recibe varias asignaciones en el mismo flanco, gana la última
    // que se ejecuta, que siempre es la del puerto de número más bajo.
    // -------------------------------------------------------------------------
    integer write_port;
    integer register_to_clear;
    always_ff @(negedge clk) begin
        if (!reset_n) begin
            for (register_to_clear = 0; register_to_clear < NUM_REGISTERS; register_to_clear++)
                register_storage[register_to_clear] <= '0;
        end else begin
            for (write_port = NUM_WRITE_PORTS - 1; write_port >= 0; write_port--)
                if (write_enable[write_port])
                    register_storage[write_register_index[write_port]] <= write_value[write_port];
        end
    end

    // -------------------------------------------------------------------------
    // Detección de conflicto (solo diagnóstico, no cambia lo que se escribe).
    //
    // Se compara cada par de puertos (first_write_port < second_write_port):
    // con 7 puertos son 7*6/2 = 21 comparadores. Cada resultado se guarda en
    // pair_targets_same_register en la posición
    //     first_write_port * NUM_WRITE_PORTS + second_write_port.
    // Las posiciones con first >= second (pares repetidos o un puerto contra
    // sí mismo) se dejan en 0.
    // -------------------------------------------------------------------------
    logic [NUM_WRITE_PORTS*NUM_WRITE_PORTS-1:0] pair_targets_same_register;

    genvar first_write_port, second_write_port;
    generate
        for (first_write_port = 0; first_write_port < NUM_WRITE_PORTS; first_write_port++) begin : g_first_port
            for (second_write_port = 0; second_write_port < NUM_WRITE_PORTS; second_write_port++) begin : g_second_port
                if (first_write_port < second_write_port) begin : g_compare_pair
                    assign pair_targets_same_register[first_write_port*NUM_WRITE_PORTS + second_write_port] =
                        write_enable[first_write_port] &&
                        write_enable[second_write_port] &&
                        (write_register_index[first_write_port] == write_register_index[second_write_port]);
                end else begin : g_unused_pair
                    assign pair_targets_same_register[first_write_port*NUM_WRITE_PORTS + second_write_port] = 1'b0;
                end
            end
        end
    endgenerate

    // OR de todos los pares: 1 si cualquier par habilitado choca
    assign write_conflict_detected = |pair_targets_same_register;

endmodule