# RISC_V-PBL

Repositório de treinamento por PBL (laboratório QuIIN / SENAI CIMATEC) em torno do jogo **Genius**.

| PBL | O que é | Onde está |
|---|---|---|
| PBL01 | Genius em RTL, com máquina de estados | `rtl/pbl_1/`, `tb/genius_tb_top.sv` |
| PBL02 | Genius em assembly RISC-V para o simulador Ripes | `sw/pbl_1/Genius.s` |
| **PBL03** | **Processador RISC-V em SystemVerilog que roda o Genius do PBL02** | `rtl/cpu/`, `tb/cpu/`, `sw/`, `constrs/` |
| — | Lista de exercícios de assembly (RARS) | `assembly-exercices/` |
| — | Exemplo UVM do template original (somador) | `tb/env/`, `tb/tests/`, `srclist/adder*` (ver o fim deste arquivo) |

---

## PBL03 — Processador RISC-V de ciclo único

Processador RV32I de **ciclo único** (cada instrução em um clock), baseado em Harris & Harris, *Digital Design and Computer Architecture, RISC-V Edition*, cap. 7. Ele implementa só as instruções que o Genius usa, e os periféricos ficam nos **mesmos endereços do Ripes**, de modo que o programa do PBL02 roda quase sem mudanças.

**Estado:** o Genius roda inteiro em simulação, e a síntese passa no Vivado a 50 MHz. Ainda não foi testado em placa (ver *Limitações*).

### Instruções suportadas (19)

`add addi and andi xor xori srli lw sw lbu sb beq bne blt bge jal jalr lui auipc`

Qualquer outra instrução é ignorada: não escreve registrador nem memória.

### Interface

O topo do processador é `cpu` (`rtl/cpu/cpu.sv`). Para síntese, `riscv_top` (`rtl/cpu/riscv_top.sv`) é o mesmo `cpu` com o Genius já carregado.

| Porta | Direção | Descrição |
|---|---|---|
| `clk` | entrada | clock (50 MHz na síntese) |
| `reset` | entrada | ativo em alto, assíncrono; o PC volta para 0 |
| `dpad[3:0]` | entrada | setas: bit 0 cima, 1 baixo, 2 esquerda, 3 direita (1 = apertada) |
| `switches[6:0]` | entrada | chaves: bit *n* = chave *n* |
| `leds[3:0]` | saída | lentes do Genius: 1 = acesa |

Parâmetros do `cpu`: `MEM_FILE` (programa, `.hex`) e `DATA_FILE` (dados iniciais, `_data.hex`), ambos com **caminho absoluto**.

### Mapa de memória

| Endereço | Quem responde | Uso |
|---|---|---|
| `0x00000000` | `imem` (1024 palavras) | programa (`.text`) |
| `0x10000000` | `dmem` (1024 palavras) | dados (`.data`) e pilha |
| `0xF0000000` – `0x0C` | `io`: D-pad | leitura: 1 enquanto cima/baixo/esquerda/direita está apertada |
| `0xF0000010` – `0x1C` | `io`: LEDs 0 a 3 | escrita: cor do LED (0 = apagado) |
| `0xF0000020` | `io`: chaves | leitura: bit *n* = chave *n* |

Endereços com `addr[31:28] = F` vão para o `io`; o resto vai para a `dmem`, que usa só os bits baixos do endereço. Por isso `0x10000000` cai na palavra 0 e a pilha (`sp = 0x7ffffff0`) cai perto do topo. As entradas passam por um sincronizador de 2 flip-flops, então chegam ao programa 2 ciclos depois.

### Arquivos

| Arquivo | Conteúdo |
|---|---|
| `rtl/cpu/cpu_pkg.sv` | opcodes, `funct3`, enums dos sinais de controle, endereços de I/O |
| `rtl/cpu/pc.sv`, `imem.sv`, `regfile.sv`, `alu.sv`, `dmem.sv`, `io.sv` | blocos do caminho de dados |
| `rtl/cpu/control.sv` | decodificador: gera todos os sinais de controle a partir da instrução |
| `rtl/cpu/cpu.sv` | liga tudo |
| `rtl/cpu/riscv_top.sv` | topo de síntese com o Genius carregado |
| `constrs/riscv_timing.xdc` | só o clock (50 MHz); sem pinos de placa |
| `srclist/riscv_cpu.srclist` | ordem de compilação |
| `sw/rvasm.py` | montador próprio (não há toolchain RISC-V instalado) |
| `sw/genius.s` | o Genius do PBL02 sem os `ecall` e com `sp` iniciado pelo programa |
| `sw/stageN.s` / `.hex` | programas de teste de cada etapa de construção |
| `tb/cpu/cpu_tb.sv` | testbench das etapas (hoje: etapa 7, I/O) |
| `tb/cpu/genius_tb.sv` | testbench que joga o Genius |

### Como simular no Vivado (GUI)

1. **Design Sources:** todos os arquivos de `rtl/cpu/`. **Simulation Sources:** `tb/cpu/cpu_tb.sv` e `tb/cpu/genius_tb.sv`. Adicione com *Copy sources into project* desmarcado.
2. Em *Simulation Sources*, clique com o botão direito no testbench desejado e escolha **Set as Top**.
3. Clique em **Run Simulation**. O `genius_tb` precisa de ~78 ms de tempo simulado: clique em **Run All** (`F3`), ou ajuste `xsim.simulate.runtime` para `all` nas configurações de simulação.
4. O console termina com `=== N error(s)`; o esperado é 0.

Os testbenches usam caminhos absolutos (`/home/gubio/CODESPACE/RISC_V-PBL/...`) para os `.hex`. Em outra máquina, ajuste `PROGRAM`/`DATA` nos testbenches e os caminhos em `riscv_top.sv`.

Troque `genius_tb` por `cpu_tb` para o outro testbench.

### Testes

- **`cpu_tb`** roda um programa de `sw/stageN.hex` e confere registradores, memória, LEDs e o PC final (o programa termina num salto para si mesmo). Cada etapa de construção tem seu programa e sua lista de checks; o arquivo atual tem a etapa 7. As etapas anteriores estão no histórico do git, um commit por etapa.
- **`genius_tb`** é o jogador: olha os LEDs enquanto o jogo mostra a sequência e aperta as setas certas.
  - Jogo 1 (fácil, rápido, Siga): vence as 8 rodadas, placar 16.
  - Jogo 2 (PARTIDA): erra na rodada 1 e perde, placar 0.
  - Confere que REPETE toca o jogo 2 e MAIS LONGO toca o jogo 1 (o recorde).
- **Montador:** `rvasm.py` reproduz todos os `stageN.hex` feitos à mão. Um programa com rótulos, pseudo-instruções e `.data` deu os mesmos registradores no Ripes e no processador.

**Não coberto ainda:** modo Mando eu, derrota por tempo (5 s), dificuldades média e difícil, velocidade lenta, instruções fora do Genius e acesso desalinhado.

### Como montar um programa

```bash
python3 sw/rvasm.py sw/genius.s     # gera sw/genius.hex e sw/genius_data.hex
```

Rode de novo sempre que mudar o `.s`: a simulação e a síntese leem os `.hex`. O layout é o mesmo do Ripes: `.text` em `0x0`, `.data` em `0x10000000`, e os símbolos `D_PAD_0_BASE`, `LED_MATRIX_0_BASE` e `SWITCHES_0_BASE` já são conhecidos. Pseudo-instruções aceitas: `li la mv j ret nop not beqz bnez bltz bgez ble`.

### Síntese

Topo `riscv_top`, constraint `constrs/riscv_timing.xdc`, FPGA `xc7z010iclg225-1L`. Resultado (Vivado 2026.1):

| | |
|---|---|
| Erros / critical warnings | 0 / 0 |
| LUTs | 1557 de 17600 (560 como memória: `regfile` e `dmem`) |
| Flip-flops | 182 (PC, cores dos 4 LEDs, sincronizadores) |
| Block RAM | 0 (as memórias têm leitura combinacional e viram LUTRAM) |
| Timing a 50 MHz | atende, folga de 4,7 ns |
| Timing a 100 MHz | não atende (WNS −5,3 ns) |

O caminho crítico é o do ciclo único: `pc → imem → regfile → ALU → dmem → regfile`, com cerca de 15 ns depois da síntese. Os 89 avisos são todos `Port addr[...] has no load`: bits de endereço que as memórias não usam.

### Limitações e próximos passos

- **Placa:** não há arquivo de pinos (`.xdc` com `PACKAGE_PIN`/`IOSTANDARD`); falta escolher a placa.
- **Atrasos do jogo:** o `delay` e o tempo limite de 5 s contam voltas de laço calibradas para o Ripes. A 50 MHz, um "passo de 250 ms" dura cerca de 0,5 ms; para jogar de verdade, as constantes `12500` e `25000` do `genius.s` precisam ser recalculadas para o clock.
- **Debounce:** os botões têm sincronizador, mas não filtro de repique; em placa, um repique pode virar um aperto falso.
- **Placar:** os `ecall` foram removidos; o placar fica em `s3`, mas não é mostrado.
- **Registradores** não têm reset (só o PC tem); o programa escreve cada registrador antes de usá-lo.
- **Pipeline:** não feito.

---

# Template de verificação (exemplo UVM do somador)

Texto original do template, mantido como referência para a verificação.

Simple adder module for demonstration purposes.

### Implementation Status

- [x] Conception
- [x] Microarchitecture
- [x] RTL Design
- [x] TB environment
- [ ] Testcases
- [ ] Functional Verification
- [ ] RTL signoff 

### Verification Template Overview

The verification template in this repository is designed to provide a modular and reusable environment for verifying RTL designs using the Universal Verification Methodology (UVM). It includes the following components:

### Key Components
1. **Testbench Environment**:
   - The testbench is structured around UVM principles and includes agents, monitors, drivers, and sequencers.
   - The environment is defined in `tb/env/top/adder_env.sv` and instantiated in the top-level testbench `tb/adder_tb_top.sv`.

2. **Agents**:
   - The agent encapsulates the driver, monitor, and sequencer for the adder DUT.
   - Defined in `tb/env/agents/adder_agent/adder_agent.sv`.

3. **Reference Model**:
   - A behavioral model of the adder is implemented in `tb/env/ref_model/adder_ref_model.sv` to generate expected outputs for comparison.

4. **Scoreboard**:
   - The scoreboard compares the DUT's output with the reference model's output to verify correctness.
   - Implemented in `tb/env/top/adder_scoreboard.sv`.

5. **Coverage**:
   - Functional coverage is collected using `tb/env/top/adder_coverage.sv` to ensure all scenarios are tested.

6. **Sequences and Tests**:
   - Sequences generate randomized transactions for the DUT, defined in `tb/tests/sequence_lib/adder_basic_seq.sv`.
   - Tests are defined in `tb/tests/adder_basic_test.sv` and aggregated in `tb/tests/adder_test_list.sv`.

7. **Top-Level Testbench**:
   - The top-level testbench `tb/adder_tb_top.sv` instantiates the DUT, connects it to the UVM environment, and starts the simulation.

8. **Automation Scripts**:
   - A native `CMakeLists.txt` is provided to automate out-of-source builds, Xilinx Vivado compilation, elaboration, and simulation processes.

### Source Organization
- **RTL Design**: Located in the `rtl/` directory.
- **Testbench Components**: Organized under `tb/` with subdirectories for agents, reference models, and top-level environment.
- **Source Lists**: Defined in `srclist/` for easy inclusion in simulation scripts. Supports standard file paths, nested `.srclist` files (which create separate compilation libraries), and `+incdir+path/to/dir` directives for global UVM macro includes.
- **Submodules**: Located in `src/` for easy integration with git submodules and dependencies.

This template is designed to streamline the verification process, promote reusability, and ensure thorough testing of the adder design.

### How to run

### Step 1: Set up the environment
Before running the simulation, you must source the required Xilinx tools (Vivado or Vitis). This injects the EDA toolpaths into your current terminal instance.

```bash
$ source /opt/Xilinx/Vitis/2024.1/settings64.sh 
# or
$ source /opt/Xilinx/2025.2/Vivado/settings64.sh 
# or
$ source /opt/Xilinx/Vivado/2024.1/.settings64-Vivado.sh 
# or
$ source /opt/Xilinx/2025.2/Vivado/.settings64-Vivado.sh 
```

### Step 2: Configure the Build
This project uses CMake to automate the Vivado simulation flow (`xvlog`, `xelab`, `xsim`). You generate an isolated `build/` directory using the provided wrapper script.

```bash
# Sets up the default simulation environment
$ ./configure
```
Under the hood, this parses your SV files, generates dependency trees via stamp files (so they only recompile when modified), and creates dynamically bound Make targets.

#### Custom Defaults Configuration
You can bake default parameters directly into the build system at configuration time so you don't need to specify them on every make command:
```bash
# Bake in a specific test name, seed, and top module as defaults:
$ ./configure --top adder_tb_top --test adder_basic_test --seed 3
```

### Step 3: Run the simulation
Because of the smart wrapper generated in the project root, you have several ways to trigger the simulations cleanly!

#### Option A: Running from the Project Root (Smart Proxy)
You do not need to `cd build/`. You can immediately execute targets from the root, and it will intentionally forward your requests into CMake. It allows you to inject individual test names via spaces.

- **`make compile`**: Explicitly compiles the SV source code (`xvlog`) without running simulation.
- **`make elaborate`**: Elaborates the compiled design into a simulation snapshot (`xelab`) without running simulation.
- **`make sim`**: Runs the default test configuration (e.g. `adder_basic_test`) silently in terminal.
- **`make gui`**: Opens Vivado XSim GUI using your defined waveform layout.
- **`make sim_<test_name>`**: Injects the test dynamically (e.g. `make sim_adder_corner_test`) replacing defaults.
- **`make gui_<test_name>`**: Injects the test dynamically into the GUI directly (e.g. `make gui_adder_corner_test`).

##### Passing Dynamic Simulation Overrides (TEST_NAME, SEED, SIM_ARGS)
Instead of re-configuring the project, you can dynamically override UVM settings, the randomization seed, or other simulator flags directly on the `make` command line:

- **Pass a specific UVM test name, disable print verbosity, and set a specific seed**:
  ```bash
  $ make sim TEST_NAME="adder_basic_test" SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_NONE" SEED="3"
  ```
  *(This runs the `adder_basic_test` test case, disables UVM verbosity output via `SIM_ARGS`, and sets the SV randomization seed to `3` dynamically.)*

- **Pass custom plusargs and a specific seed**:
  ```bash
  $ make sim TEST_NAME="adder_basic_test" SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_NONE" SEED="3"
  ```

- **Change UVM Verbosity only**:
  ```bash
  $ make sim SIM_ARGS="--testplusarg UVM_VERBOSITY=UVM_HIGH"
  ```

- **Enable UVM Objection Tracing**:
  ```bash
  $ make sim SIM_ARGS="--testplusarg UVM_OBJECTION_TRACE"
  ```

- **Pass multiple custom plusargs dynamically**:
  ```bash
  $ make sim_adder_corner_test SIM_ARGS="--testplusarg some_arg=1 --testplusarg another_arg=0"
  ```

#### Option B: Running from inside the `build/` directory
When inside the strictly generated CMake target directory, you can utilize the auto-generated target configurations. (Note: spaces denote multiple targets inside native Make!)

```bash
$ cd build/
```
- **`make sim`**: Runs the default test configured.
- **`make <test_name>`**: Runs a specific test dynamically discovered natively (e.g. `make adder_corner_test`).
- **`make sim_<test_name>`**: Explicitly runs the auto-generated test strictly in SIM terminal mode.
- **`make gui_<test_name>`**: Explicitly runs the auto-generated test natively triggering the Vivado GUI.

#### Option C: Simulation Wrapper Script (`xrun.sh`)
For convenience, we provide a wrapper script at `scripts/xrun.sh` that automatically runs the configuration (`./configure`) and simulation (`make`) stages in one step. It supports the following options:

| Option | Description |
|---|---|
| `--top <top_name>` | Specify the top-level testbench module (default: `adder_tb_top`). |
| `--name_of_test <test_name>` | Specify the UVM test name to execute (default: `adder_basic_test`). |
| `--seed <value>` | Specify the SystemVerilog randomization seed (default: `1`). |
| `--vivado "<params>"` | Pass custom Vivado simulator arguments. E.g., `"--g"` activates GUI mode. |
| `--clean` | Perform a clean of the build directory before running the simulation. |
| `--help` | Display the help message detailing script usage. |

##### Examples of using `xrun.sh`:

- **Run the default simulation in CLI mode**:
  ```bash
  $ ./scripts/xrun.sh
  ```

- **Run a specific test case (e.g. `adder_corner_test`)**:
  ```bash
  $ ./scripts/xrun.sh --name_of_test adder_corner_test
  ```

- **Run a specific test case in the Vivado GUI**:
  ```bash
  $ ./scripts/xrun.sh --name_of_test adder_basic_test --vivado "--g"
  ```

- **Clean the build directory and run simulation**:
  ```bash
  $ ./scripts/xrun.sh --clean --name_of_test adder_basic_test
  ```

- **Run GUI mode with custom waveform config**:
  ```bash
  $ ./scripts/xrun.sh --vivado "--g -view scripts/adder_tb_top_sim.wcfg"
  ```

- **Run with a custom randomization seed (e.g. `42`)**:
  ```bash
  $ ./scripts/xrun.sh --seed 42
  ```

- **Run with a dynamically generated random seed**:
  ```bash
  $ ./scripts/xrun.sh --seed random
  ```

- **Pass `SIM_ARGS` through the wrapper script**:
  ```bash
  $ SIM_ARGS="+UVM_VERBOSITY=UVM_HIGH" ./scripts/xrun.sh --name_of_test adder_basic_test
  ```

### Step 4: Clean Build
To clean the entire build cache (safe compilation reset):
```bash
$ make clean
```

### Summary of Configure Arguments
| Variable | Default Value | Description |
|---|---|---|
| `--top` | `adder_tb_top` | Specifies the top-level testbench module to load in elaboration. |
| `--test` | `adder_basic_test` | The UVM test name passed directly to `+UVM_TESTNAME` in `xsim`. |
| `--seed` | `1` | The SystemVerilog randomization seed passed to `--sv_seed` in `xsim`. |
| `--vivado` | `--R` | Passes arbitrary flags natively to the simulation engine. (Setting `--g` turns on GUI mode) |


### Important Information

1. **Tool Versions**:
   - Ensure you are using Vivado or Vitis version 2024.1 or later for compatibility with the scripts and UVM libraries.

2. **Directory Structure**:
   - Maintain the directory structure as provided in the repository to ensure the scripts and source lists function correctly.

3. **Debugging Tips**:
   - Use the `--vivado "--g"` option to open the GUI for debugging.
   - Check the `build/` directory for logs and intermediate files if issues arise during simulation.

4. **Extending the Template**:
   - To add new tests, create sequences in `tb/tests/sequence_lib/` and include them in `tb/tests/adder_seq_list_pkg.sv` and `tb/tests/adder_test_list_pkg.sv`.
   - To add standalone shared components (like interfaces), map them to an `.srclist` module to build them as an independent library.
   - For additional coverage, extend the coverage model in `tb/env/top/adder_coverage.sv`.

5. **Support**:
   - For questions or issues, contact the maintainer at `nelsonafn@gmail.com`.

6. **License**:
   - This project is distributed under the BSD license. Refer to the `LICENSE` file for details.

This section provides essential details to ensure smooth usage and extension of the verification template.

### Install cmake
sudo apt install cmake
sudo apt install autoconf
