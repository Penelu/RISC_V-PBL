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
    output logic       reg_write,    // 1: write the result into rd
    output logic       alu_src,      // 0: ALU b = rs2, 1: ALU b = immediate
    output alu_op_t    alu_op
);

    always_comb begin
        // defaults: do nothing
        reg_write = 1'b0;
        alu_src   = 1'b0;
        alu_op    = ALU_ADD;

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

            default: ;
        endcase
    end

endmodule
