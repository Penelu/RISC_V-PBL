# ex01_sum_registers.s
# Soma dois registradores: a2 = a0 + a1
# Entrada:  a0 = primeiro operando, a1 = segundo operando
# Saida:    a2 = resultado

.globl main

.text
main:
    li      a0, 5           # a0 = 5   (valor de teste)
    li      a1, 3           # a1 = 3   (valor de teste)

    add     a2, a0, a1      # a2 = a0 + a1  -> 8

    #li      a7, 1          # ecall 10 = exit, 1 = print
    #ecall