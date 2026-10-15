//------------------------------------------------------------------------------
// cpu - single-cycle RISC-V processor, top level
//------------------------------------------------------------------------------
// Every instruction is fetched, decoded, executed and written back in one
// clock cycle:
//
//   pc -> imem -> control + regfile -> alu -> regfile
//
//   alu -> dmem -> regfile               (lw, sw)
//   pc + imm -> pc                       (taken branch, jal)
//   alu      -> pc                       (jalr)
//
// Stage 6: every instruction of the Genius program:
//          add, addi, and, andi, xor, xori, srli, lw, sw, lbu, sb,
//          beq, bne, blt, bge, jal, jalr, lui, auipc.
//------------------------------------------------------------------------------

module cpu
    import cpu_pkg::*;
#(
    parameter MEM_FILE = ""          // program loaded into the instruction memory
)(
    input  logic clk,
    input  logic reset               // active-high, asynchronous
);

    // ---- fetch --------------------------------------------------------------
    logic [31:0] pc_cur, pc_next, pc_plus4, pc_target, alu_y, instr;
    pc_src_t     pc_src;

    assign pc_plus4 = pc_cur + 32'd4;

    // jalr clears bit 0 of its target, as the RISC-V spec asks
    always_comb begin
        case (pc_src)
            PC_TARGET: pc_next = pc_target;
            PC_ALU:    pc_next = {alu_y[31:1], 1'b0};
            default:   pc_next = pc_plus4;
        endcase
    end

    pc u_pc (
        .clk     (clk),
        .reset   (reset),
        .pc_next (pc_next),
        .pc      (pc_cur)
    );

    imem #(.MEM_FILE(MEM_FILE)) u_imem (
        .addr  (pc_cur),
        .instr (instr)
    );

    // ---- decode -------------------------------------------------------------
    logic [6:0]  opcode;
    logic [2:0]  funct3;
    logic        funct7_5;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] imm;

    assign opcode   = instr[6:0];
    assign funct3   = instr[14:12];
    assign funct7_5 = instr[30];
    assign rd       = instr[11:7];
    assign rs1      = instr[19:15];
    assign rs2      = instr[24:20];

    logic        reg_write, alu_src, mem_write, mem_byte;
    result_src_t result_src;
    logic        eq, lt;             // branch comparison, made in execute
    alu_op_t     alu_op;
    imm_src_t    imm_src;

    control u_control (
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7_5   (funct7_5),
        .eq         (eq),
        .lt         (lt),
        .reg_write  (reg_write),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .imm_src    (imm_src),
        .mem_write  (mem_write),
        .mem_byte   (mem_byte),
        .result_src (result_src),
        .pc_src     (pc_src)
    );

    // immediate, sign extended from instr[31] in every format
    always_comb begin
        case (imm_src)
            IMM_I:   imm = {{20{instr[31]}}, instr[31:20]};
            IMM_S:   imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            IMM_B:   imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            IMM_J:   imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            IMM_U:   imm = {instr[31:12], 12'd0};
            default: imm = 32'd0;
        endcase
    end

    // ---- register file ------------------------------------------------------
    logic [31:0] rs1_val, rs2_val, result;

    regfile u_regfile (
        .clk (clk),
        .we  (reg_write),
        .ra1 (rs1),
        .ra2 (rs2),
        .wa  (rd),
        .wd  (result),
        .rd1 (rs1_val),
        .rd2 (rs2_val)
    );

    // ---- execute ------------------------------------------------------------
    logic [31:0] alu_b;

    assign alu_b = alu_src ? imm : rs2_val;

    alu u_alu (
        .a  (rs1_val),
        .b  (alu_b),
        .op (alu_op),
        .y  (alu_y)
    );

    // ---- branch -------------------------------------------------------------
    assign eq        = (rs1_val == rs2_val);
    assign lt        = ($signed(rs1_val) < $signed(rs2_val));
    assign pc_target = pc_cur + imm;

    // ---- memory -------------------------------------------------------------
    logic [31:0] mem_rd;

    dmem u_dmem (
        .clk     (clk),
        .we      (mem_write),
        .byte_en (mem_byte),
        .addr    (alu_y),
        .wd      (rs2_val),
        .rd      (mem_rd)
    );

    // ---- write back ---------------------------------------------------------
    always_comb begin
        case (result_src)
            RES_MEM:    result = mem_rd;
            RES_PC4:    result = pc_plus4;
            RES_IMM:    result = imm;
            RES_TARGET: result = pc_target;
            default:    result = alu_y;
        endcase
    end

endmodule
