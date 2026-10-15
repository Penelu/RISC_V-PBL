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
    localparam logic [6:0] OP_LOAD  = 7'b0000011; // lw, lbu
    localparam logic [6:0] OP_STORE = 7'b0100011; // sw, sb
    localparam logic [6:0] OP_BRANCH = 7'b1100011; // beq, bne, blt, bge
    localparam logic [6:0] OP_JAL    = 7'b1101111; // jal
    localparam logic [6:0] OP_JALR   = 7'b1100111; // jalr
    localparam logic [6:0] OP_LUI    = 7'b0110111; // lui
    localparam logic [6:0] OP_AUIPC  = 7'b0010111; // auipc

    // ---- funct3 (instr[14:12]) ---------------------------------------------
    localparam logic [2:0] F3_ADD = 3'b000;
    localparam logic [2:0] F3_B   = 3'b000;       // sb: one byte
    localparam logic [2:0] F3_W   = 3'b010;       // lw, sw: whole word
    localparam logic [2:0] F3_BU  = 3'b100;       // lbu: one byte, zero extended
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
    // instruction.
    typedef enum logic [2:0] {
        IMM_I,                       // addi, lw: instr[31:20]
        IMM_S,                       // sw: instr[31:25] + instr[11:7]
        IMM_B,                       // beq...: like S, scrambled, in 2-byte steps
        IMM_J,                       // jal: instr[31:12], scrambled, in 2-byte steps
        IMM_U                        // lui, auipc: instr[31:12], low 12 bits are 0
    } imm_src_t;

    // ---- where the next pc comes from ---------------------------------------
    typedef enum logic [1:0] {
        PC_PLUS4,                    // the next instruction
        PC_TARGET,                   // pc + imm: taken branch, jal
        PC_ALU                       // rs1 + imm: jalr
    } pc_src_t;

    // ---- what is written into rd --------------------------------------------
    typedef enum logic [2:0] {
        RES_ALU,                     // add, addi...
        RES_MEM,                     // lw, lbu
        RES_PC4,                     // jal, jalr: the return address
        RES_IMM,                     // lui: the immediate itself
        RES_TARGET                   // auipc: pc + imm
    } result_src_t;

endpackage
