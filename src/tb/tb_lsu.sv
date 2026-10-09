`timescale 1ns/1ps

module tb_lsu;

    logic [4:0]  opcode;
    logic [3:0]  rd_rs_idx, rbase_idx;
    logic [31:0] rbase_val, rs_data_val, mem_read_data;
    logic [18:0] imm19;

    logic [31:0] eff_addr, mem_write_data, rd_load_data, rbase_updated;
    logic        mem_we, rbase_write_en;
    logic [3:0]  byte_enable;

    lsu uut (
        .opcode(opcode),
        .rd_rs_idx(rd_rs_idx),
        .rbase_idx(rbase_idx),
        .rbase_val(rbase_val),
        .rs_data_val(rs_data_val),
        .imm19(imm19),
        .mem_read_data(mem_read_data),
        .eff_addr(eff_addr),
        .mem_write_data(mem_write_data),
        .mem_we(mem_we),
        .byte_enable(byte_enable),
        .rd_load_data(rd_load_data),
        .rbase_updated(rbase_updated),
        .rbase_write_en(rbase_write_en)
    );

    initial begin
        $dumpfile("sim_lsu.vcd");
        $dumpvars(0, tb_lsu);

        rbase_val     = 32'h0000_1000;
        rs_data_val   = 32'hAABB_CCDD;
        mem_read_data = 32'h8000_FFAB;
        imm19         = 19'd4;
        rd_rs_idx     = 4'd1;
        rbase_idx     = 4'd2;

        // 1. Prueba LW (00110)
        opcode = 5'b00110; #10; // Direction EA = 0x1004, rd_load = 0x8000_FFAB

        // 2. Prueba LW.INC (10110)
        opcode = 5'b10110; #10; // Direction EA = 0x1000, rbase_updated = 0x1004

        // 3. Prueba LBU (00011) - Unsigned Byte
        opcode = 5'b00011; #10; // Carga byte con ceros

        // 4. Prueba SW (01110)
        opcode = 5'b01110; #10; // Write enable en 1, mem_write_data = 0xAABB_CCDD

        $display("Simulación de la LSU completada con éxito.");
        $finish;
    end

endmodule