#!/usr/bin/env python3
"""rvasm - tiny RISC-V assembler for the instructions of the Genius program.

Usage:  python3 rvasm.py program.s [output_prefix]

Writes two files, one 32-bit word per line in hex, ready for $readmemh:
    <prefix>.hex       the .text section, loaded into imem
    <prefix>_data.hex  the .data section, loaded into dmem
The prefix defaults to the source name without ".s".

Same memory layout as Ripes, so addresses match the PBL02 program:
.text starts at 0x00000000, .data at 0x10000000, and the I/O symbols
(D_PAD_0_BASE...) have the addresses Ripes gives them.

Supported:
    instructions  add and xor addi andi xori srli lw lbu sw sb
                  beq bne blt bge jal jalr lui auipc ecall
    pseudo        li la mv j ret nop not beqz bnez bltz bgez ble
    directives    .text .data .word .byte .zero .string
A number in place of a branch or jump target is an offset in bytes from the
instruction itself; a label is turned into that offset.
"""

import re
import sys

TEXT_BASE = 0x00000000
DATA_BASE = 0x10000000

SYMBOLS = {                                     # Ripes I/O addresses
    "D_PAD_0_BASE":      0xF0000000,
    "LED_MATRIX_0_BASE": 0xF0000010,
    "SWITCHES_0_BASE":   0xF0000020,
}

ABI = ["zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
       "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
       "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
       "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"]


class AsmError(Exception):
    pass


# ---- operands -----------------------------------------------------------------

def reg(name):
    name = name.strip()
    if name == "fp":
        return 8
    if name in ABI:
        return ABI.index(name)
    m = re.fullmatch(r"x(\d+)", name)
    if m and int(m.group(1)) < 32:
        return int(m.group(1))
    raise AsmError(f"unknown register '{name}'")


def value(text, symbols):
    text = text.strip()
    if text in symbols:
        return symbols[text]
    try:
        return int(text, 0)
    except ValueError:
        raise AsmError(f"unknown symbol '{text}'")


def mem_operand(text):
    """'12(sp)' -> ('12', 'sp')"""
    m = re.fullmatch(r"\s*(-?\w*)\s*\(\s*(\w+)\s*\)\s*", text)
    if not m:
        raise AsmError(f"expected offset(register), got '{text}'")
    return (m.group(1) or "0"), m.group(2)


def split_hi_lo(v):
    """Split v so that (hi << 12) + lo == v with lo a signed 12-bit value."""
    lo = ((v & 0xFFF) ^ 0x800) - 0x800
    hi = ((v - lo) >> 12) & 0xFFFFF
    return hi, lo


def fits12(v):
    return -2048 <= v < 2048


# ---- instruction formats ------------------------------------------------------

def check_range(v, bits, what):
    if not -(1 << (bits - 1)) <= v < (1 << (bits - 1)):
        raise AsmError(f"{what} {v} does not fit in {bits} bits")


def enc_r(f7, f3, op, rd, rs1, rs2):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(f3, op, rd, rs1, imm):
    check_range(imm, 12, "immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(f3, op, rs1, rs2, imm):
    check_range(imm, 12, "offset")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) \
        | ((imm & 0x1F) << 7) | op


def enc_b(f3, rs1, rs2, off):
    check_range(off, 13, "branch offset")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) \
        | (rs1 << 15) | (f3 << 12) | (((o >> 1) & 0xF) << 8) \
        | (((o >> 11) & 1) << 7) | 0x63


def enc_u(op, rd, imm20):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(rd, off):
    check_range(off, 21, "jump offset")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) \
        | (((o >> 11) & 1) << 20) | (((o >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


R_OPS = {"add": 0b000, "and": 0b111, "xor": 0b100}
I_OPS = {"addi": 0b000, "andi": 0b111, "xori": 0b100}
LOADS = {"lw": 0b010, "lbu": 0b100}
STORES = {"sw": 0b010, "sb": 0b000}
BRANCHES = {"beq": 0b000, "bne": 0b001, "blt": 0b100, "bge": 0b101}
# pseudo branches against zero: name -> (real branch, zero goes first?)
ZERO_BRANCHES = {"beqz": ("beq", False), "bnez": ("bne", False),
                 "bltz": ("blt", False), "bgez": ("bge", False)}


def size_of(mnem, ops, symbols):
    """Number of 32-bit words an instruction takes (li and la may take two)."""
    if mnem == "la":
        return 2
    if mnem == "li":
        return 1 if fits12(value(ops[1], symbols)) else 2
    return 1


def target(text, pc, symbols):
    """Branch/jump operand -> offset from pc."""
    text = text.strip()
    if re.fullmatch(r"-?(0x[0-9a-fA-F]+|\d+)", text):
        return int(text, 0)                     # already an offset
    return value(text, symbols) - pc


def encode(mnem, ops, pc, symbols):
    """Returns the list of words for one (pseudo) instruction."""
    n = len(ops)

    def need(count):
        if n != count:
            raise AsmError(f"'{mnem}' takes {count} operands, got {n}")

    if mnem in R_OPS:
        need(3)
        return [enc_r(0, R_OPS[mnem], 0x33, reg(ops[0]), reg(ops[1]), reg(ops[2]))]
    if mnem in I_OPS:
        need(3)
        return [enc_i(I_OPS[mnem], 0x13, reg(ops[0]), reg(ops[1]), value(ops[2], symbols))]
    if mnem == "srli":
        need(3)
        shamt = value(ops[2], symbols)
        if not 0 <= shamt < 32:
            raise AsmError(f"shift amount {shamt} out of range")
        return [enc_i(0b101, 0x13, reg(ops[0]), reg(ops[1]), shamt)]
    if mnem in LOADS:
        need(2)
        off, base = mem_operand(ops[1])
        return [enc_i(LOADS[mnem], 0x03, reg(ops[0]), reg(base), value(off, symbols))]
    if mnem in STORES:
        need(2)
        off, base = mem_operand(ops[1])
        return [enc_s(STORES[mnem], 0x23, reg(base), reg(ops[0]), value(off, symbols))]
    if mnem in BRANCHES:
        need(3)
        return [enc_b(BRANCHES[mnem], reg(ops[0]), reg(ops[1]), target(ops[2], pc, symbols))]
    if mnem == "jal":
        if n == 1:                              # jal label  ->  jal ra, label
            return [enc_j(1, target(ops[0], pc, symbols))]
        need(2)
        return [enc_j(reg(ops[0]), target(ops[1], pc, symbols))]
    if mnem == "jalr":
        if n == 2:                              # jalr rd, off(rs1)
            off, base = mem_operand(ops[1])
            return [enc_i(0b000, 0x67, reg(ops[0]), reg(base), value(off, symbols))]
        need(3)                                 # jalr rd, rs1, off
        return [enc_i(0b000, 0x67, reg(ops[0]), reg(ops[1]), value(ops[2], symbols))]
    if mnem == "lui":
        need(2)
        return [enc_u(0x37, reg(ops[0]), value(ops[1], symbols))]
    if mnem == "auipc":
        need(2)
        return [enc_u(0x17, reg(ops[0]), value(ops[1], symbols))]
    if mnem == "ecall":
        need(0)
        return [0x00000073]

    # ---- pseudo instructions ----
    if mnem == "nop":
        need(0)
        return [enc_i(0, 0x13, 0, 0, 0)]                        # addi x0, x0, 0
    if mnem == "mv":
        need(2)
        return [enc_i(0, 0x13, reg(ops[0]), reg(ops[1]), 0)]   # addi rd, rs, 0
    if mnem == "not":
        need(2)
        return [enc_i(0b100, 0x13, reg(ops[0]), reg(ops[1]), -1)]  # xori rd, rs, -1
    if mnem == "j":
        need(1)
        return [enc_j(0, target(ops[0], pc, symbols))]          # jal x0, label
    if mnem == "ret":
        need(0)
        return [enc_i(0, 0x67, 0, 1, 0)]                        # jalr x0, 0(ra)
    if mnem in ZERO_BRANCHES:
        need(2)
        real, _ = ZERO_BRANCHES[mnem]                           # bxx rs, x0, label
        return [enc_b(BRANCHES[real], reg(ops[0]), 0, target(ops[1], pc, symbols))]
    if mnem == "ble":
        need(3)                                                 # bge rs2, rs1, label
        return [enc_b(BRANCHES["bge"], reg(ops[1]), reg(ops[0]), target(ops[2], pc, symbols))]
    if mnem == "li":
        need(2)
        rd, v = reg(ops[0]), value(ops[1], symbols)
        if fits12(v):
            return [enc_i(0, 0x13, rd, 0, v)]                   # addi rd, x0, v
        hi, lo = split_hi_lo(v & 0xFFFFFFFF)
        return [enc_u(0x37, rd, hi), enc_i(0, 0x13, rd, rd, lo)]  # lui + addi
    if mnem == "la":
        need(2)
        rd = reg(ops[0])
        hi, lo = split_hi_lo((value(ops[1], symbols) - pc) & 0xFFFFFFFF)
        return [enc_u(0x17, rd, hi), enc_i(0, 0x13, rd, rd, lo)]  # auipc + addi

    raise AsmError(f"unknown instruction '{mnem}'")


# ---- source reading -----------------------------------------------------------

def strip_comment(line):
    """Drops everything after a '#' that is not inside a string."""
    in_string = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_string = not in_string
        elif ch == "#" and not in_string:
            return line[:i]
    return line


def split_operands(text):
    text = text.strip()
    return [o.strip() for o in text.split(",")] if text else []


def parse(path):
    """Yields (line number, label or None, mnemonic or None, operand text)."""
    with open(path) as f:
        for num, raw in enumerate(f, 1):
            line = strip_comment(raw).strip()
            label = None
            m = re.match(r"([A-Za-z_]\w*)\s*:(.*)", line)
            if m:
                label, line = m.group(1), m.group(2).strip()
            if not line:
                yield num, label, None, ""
                continue
            parts = line.split(None, 1)
            yield num, label, parts[0], (parts[1] if len(parts) > 1 else "")


def data_bytes(directive, args, symbols):
    if directive == ".word":
        out = b""
        for a in split_operands(args):
            out += (value(a, symbols) & 0xFFFFFFFF).to_bytes(4, "little")
        return out
    if directive == ".byte":
        return bytes(value(a, symbols) & 0xFF for a in split_operands(args))
    if directive == ".zero":
        return bytes(value(args, symbols))
    if directive == ".string":
        m = re.fullmatch(r'\s*"(.*)"\s*', args)
        if not m:
            raise AsmError(".string needs a quoted text")
        return m.group(1).encode().decode("unicode_escape").encode("latin-1") + b"\0"
    raise AsmError(f"unknown directive '{directive}'")


def assemble(path):
    lines = list(parse(path))
    symbols = dict(SYMBOLS)

    # pass 1: give every label its address
    section, pc, dc = ".text", TEXT_BASE, DATA_BASE
    for num, label, mnem, args in lines:
        try:
            if label:
                if label in symbols:
                    raise AsmError(f"label '{label}' defined twice")
                symbols[label] = pc if section == ".text" else dc
            if mnem in (".text", ".data"):
                section = mnem
            elif mnem and mnem.startswith("."):
                dc += len(data_bytes(mnem, args, symbols))
            elif mnem:
                pc += 4 * size_of(mnem, split_operands(args), symbols)
        except AsmError as e:
            sys.exit(f"{path}:{num}: {e}")

    # pass 2: encode
    section, pc = ".text", TEXT_BASE
    text, data = [], b""
    for num, label, mnem, args in lines:
        try:
            if mnem in (".text", ".data"):
                section = mnem
            elif mnem and mnem.startswith("."):
                data += data_bytes(mnem, args, symbols)
            elif mnem:
                if section != ".text":
                    raise AsmError("instruction outside .text")
                words = encode(mnem, split_operands(args), pc, symbols)
                text += words
                pc += 4 * len(words)
        except AsmError as e:
            sys.exit(f"{path}:{num}: {e}")

    data += bytes(-len(data) % 4)               # pad to a whole word
    data_words = [int.from_bytes(data[i:i + 4], "little")
                  for i in range(0, len(data), 4)]
    return text, data_words, symbols


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    src = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) == 3 else re.sub(r"\.s$", "", src)
    text, data, _ = assemble(src)
    with open(prefix + ".hex", "w") as f:
        f.writelines(f"{w:08x}\n" for w in text)
    with open(prefix + "_data.hex", "w") as f:
        f.writelines(f"{w:08x}\n" for w in data)
    print(f"{prefix}.hex: {len(text)} instructions, "
          f"{prefix}_data.hex: {len(data)} data words")


if __name__ == "__main__":
    main()
