//------------------------------------------------------------------------------
// control - main decoder
//------------------------------------------------------------------------------
// Looks at the instruction and tells every block what to do. The opcode says
// which group the instruction belongs to; funct3 and funct7 say which
// operation inside the group.
//
// Only the instructions used by the Genius program are recognised. Anything
// else leaves reg_write at 0, so an unknown instruction changes no state.
//------------------------------------------------------------------------------

module control
    import cpu_pkg::*;
(
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic       funct7_5,     // instr[30]: picks sub/sra over add/srl
    input  logic       eq,           // rs1 == rs2
    input  logic       lt,           // rs1 <  rs2, signed
    output logic       reg_write,    // 1: write the result into rd
    output logic       alu_src,      // 0: ALU b = rs2, 1: ALU b = immediate
    output alu_op_t    alu_op,
    output imm_src_t   imm_src,      // which immediate format to decode
    output logic       mem_write,    // 1: write rs2 into data memory
    output result_src_t result_src,  // what rd gets: ALU, memory or pc + 4
    output pc_src_t    pc_src        // where the next pc comes from
);

    always_comb begin
        // defaults: do nothing
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = ALU_ADD;
        imm_src    = IMM_I;
        mem_write  = 1'b0;
        result_src = RES_ALU;
        pc_src     = PC_PLUS4;

        case (opcode)
            // ---- register and immediate: addi, andi, xori, srli ----------
            OP_IMM: begin
                alu_src = 1'b1;
                case (funct3)
                    F3_ADD: begin alu_op = ALU_ADD; reg_write = 1'b1; end
                    F3_AND: begin alu_op = ALU_AND; reg_write = 1'b1; end
                    F3_XOR: begin alu_op = ALU_XOR; reg_write = 1'b1; end
                    F3_SRL: if (!funct7_5) begin     // srai is not supported
                                alu_op = ALU_SRL; reg_write = 1'b1;
                            end
                    default: ;
                endcase
            end

            // ---- register and register: add, and, xor --------------------
            OP_REG: begin
                alu_src = 1'b0;
                if (!funct7_5) begin                 // sub is not supported
                    case (funct3)
                        F3_ADD: begin alu_op = ALU_ADD; reg_write = 1'b1; end
                        F3_AND: begin alu_op = ALU_AND; reg_write = 1'b1; end
                        F3_XOR: begin alu_op = ALU_XOR; reg_write = 1'b1; end
                        default: ;
                    endcase
                end
            end

            // ---- load: lw  (address = rs1 + imm) -------------------------
            OP_LOAD: begin
                if (funct3 == F3_W) begin
                    alu_src    = 1'b1;
                    imm_src    = IMM_I;
                    result_src = RES_MEM;
                    reg_write  = 1'b1;
                end
            end

            // ---- store: sw  (address = rs1 + imm, data = rs2) ------------
            OP_STORE: begin
                if (funct3 == F3_W) begin
                    alu_src   = 1'b1;
                    imm_src   = IMM_S;
                    mem_write = 1'b1;
                end
            end

            // ---- branch: jump to pc + imm when the comparison holds ------
            OP_BRANCH: begin
                imm_src = IMM_B;
                case (funct3)
                    F3_BEQ:  if ( eq) pc_src = PC_TARGET;
                    F3_BNE:  if (!eq) pc_src = PC_TARGET;
                    F3_BLT:  if ( lt) pc_src = PC_TARGET;
                    F3_BGE:  if (!lt) pc_src = PC_TARGET;
                    default: ;
                endcase
            end

            // ---- jal: rd = pc + 4, jump to pc + imm ----------------------
            OP_JAL: begin
                imm_src    = IMM_J;
                pc_src     = PC_TARGET;
                result_src = RES_PC4;
                reg_write  = 1'b1;
            end

            // ---- jalr: rd = pc + 4, jump to rs1 + imm --------------------
            OP_JALR: begin
                if (funct3 == F3_ADD) begin
                    alu_src    = 1'b1;
                    imm_src    = IMM_I;
                    pc_src     = PC_ALU;
                    result_src = RES_PC4;
                    reg_write  = 1'b1;
                end
            end

            default: ;
        endcase
    end

endmodule
