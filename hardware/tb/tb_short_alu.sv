`timescale 1ns/1ps

module tb_short_alu;

    logic        i_bit;
    logic [2:0]  subop;
    logic [31:0] rd_val;
    logic [31:0] rs2_val;
    logic [4:0]  imm5;
    logic [31:0] result;

    short_alu uut (
        .i_bit(i_bit),
        .subop(subop),
        .rd_val(rd_val),
        .rs2_val(rs2_val),
        .imm5(imm5),
        .result(result)
    );

    initial begin
        $dumpfile("sim_short_alu.vcd");
        $dumpvars(0, tb_short_alu);

        rd_val  = 32'h0000_000F;
        rs2_val = 32'h0000_0001;
        imm5    = 5'd5;

        // Pruebas modo Registro (i = 0)
        i_bit = 0;
        subop = 3'b000; #10; // ADD.S: 15 + 1 = 16
        subop = 3'b001; #10; // SUB.S: 15 - 1 = 14
        subop = 3'b100; #10; // XOR.S: 15 ^ 1 = 14

        // Pruebas modo Inmediato (i = 1)
        i_bit = 1;
        subop = 3'b000; #10; // ADDI.S: 15 + 5 = 20
        subop = 3'b101; #10; // MOVI.S: result = 5

        $display("Simulación de ALU Corta completada con éxito.");
        $finish;
    end

endmodule