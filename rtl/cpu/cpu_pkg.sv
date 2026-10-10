//------------------------------------------------------------------------------
// cpu_pkg - constants shared by the processor modules
//------------------------------------------------------------------------------
// Keeping the opcodes and ALU operations in one place means control and alu
// always agree on what each number means.
//------------------------------------------------------------------------------

package cpu_pkg;

    // ---- opcodes (instr[6:0]) ----------------------------------------------
    localparam logic [6:0] OP_IMM = 7'b0010011;   // addi, andi, xori, srli
    localparam logic [6:0] OP_REG = 7'b0110011;   // add, and, xor

    // ---- funct3 (instr[14:12]) ---------------------------------------------
    localparam logic [2:0] F3_ADD = 3'b000;
    localparam logic [2:0] F3_XOR = 3'b100;
    localparam logic [2:0] F3_SRL = 3'b101;
    localparam logic [2:0] F3_AND = 3'b111;

    // ---- ALU operations -----------------------------------------------------
    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_AND,
        ALU_XOR,
        ALU_SRL
    } alu_op_t;

endpackage
