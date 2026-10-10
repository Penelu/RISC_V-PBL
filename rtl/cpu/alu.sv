//------------------------------------------------------------------------------
// alu - arithmetic and logic unit
//------------------------------------------------------------------------------
// Only the operations the Genius program needs. Each later stage adds one line
// per new operation to the case below.
//------------------------------------------------------------------------------

module alu
    import cpu_pkg::*;
(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_t     op,
    output logic [31:0] y
);

    always_comb begin
        case (op)
            ALU_ADD: y = a + b;
            ALU_AND: y = a & b;
            ALU_XOR: y = a ^ b;
            ALU_SRL: y = a >> b[4:0];       // shift amount is the 5 low bits
            default: y = 32'd0;
        endcase
    end

endmodule
