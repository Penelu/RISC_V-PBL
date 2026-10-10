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
    localparam logic [6:0] OP_LOAD  = 7'b0000011; // lw
    localparam logic [6:0] OP_STORE = 7'b0100011; // sw
    localparam logic [6:0] OP_BRANCH = 7'b1100011; // beq, bne, blt, bge

    // ---- funct3 (instr[14:12]) ---------------------------------------------
    localparam logic [2:0] F3_ADD = 3'b000;
    localparam logic [2:0] F3_W   = 3'b010;       // lw, sw: whole word
    localparam logic [2:0] F3_XOR = 3'b100;
    localparam logic [2:0] F3_SRL = 3'b101;
    localparam logic [2:0] F3_AND = 3'b111;

    // branches reuse funct3 to say which comparison to make
    localparam logic [2:0] F3_BEQ = 3'b000;
    localparam logic [2:0] F3_BNE = 3'b001;
    localparam logic [2:0] F3_BLT = 3'b100;
    localparam logic [2:0] F3_BGE = 3'b101;

    // ---- ALU operations -----------------------------------------------------
    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_AND,
        ALU_XOR,
        ALU_SRL
    } alu_op_t;

    // ---- immediate formats --------------------------------------------------
    // Each format keeps the immediate bits in a different place of the
    // instruction; later stages add J and U.
    typedef enum logic [2:0] {
        IMM_I,                       // addi, lw: instr[31:20]
        IMM_S,                       // sw: instr[31:25] + instr[11:7]
        IMM_B                        // beq...: like S, scrambled, in 2-byte steps
    } imm_src_t;

endpackage
