# Microprocesador Pipelined de 32 bits (Estilo MIPS) - Verilog

Proyecto de arquitectura de computadoras para la implementación de un microprocesador RISC de 32 bits en Verilog HDL, que incluye ejecución segmentada en 5 etapas (Pipeline), decodificador de instrucciones ensamblador en Python y despliegue en la placa **DE10-Lite**.

---

## 📁 Estructura del Repositorio

```text
├── src/            # Código fuente en Verilog (.v)
│   ├── datapath/   # Módulos: ALU, ROM, RAM, Banco de Registros, PC, Sign_Extend
│   ├── control/    # Unidad de Control Central, Control ALU
│   ├── pipeline/   # Registros de segmento (IF/ID, ID/EX, EX/MEM, MEM/WB), Hazard Unit, Forwarding
│   └── processor_top.v  # Módulo principal Top-Level
├── tb/             # Testbenches para simulación
├── assembler/      # Decodificador de Ensamblador a Binario en Python (.py)
├── quartus/        # Proyecto de Intel Quartus Prime para la tarjeta DE10-Lite
└── README.md
```

## Simulacion de instrucciones tipo R

El banco de pruebas `tb/type_r_monocycle_tb.v` ejecuta `add`, `sub`, `and`,
`or` y `slt`. ModelSim debe iniciarse desde la raiz del proyecto para que
encuentre `instrucciones.txt` y `registersData.txt`.

```text
vlog -work work src\datapath\*.v src\control\*.v src\processor_top.v tb\type_r_monocycle_tb.v
vsim -c -lib work type_r_monocycle_tb -do "run -all; quit -f"
```

Para abrir las señales de la ALU en el Wave de ModelSim:

```text
vsim -lib work type_r_monocycle_tb
do {tb\type_r_wave.do}
```

## Prueba completa de instrucciones

El banco de pruebas `tb/all_instructions_tb.v` prueba las instrucciones
implementadas: todas las operaciones tipo R (ADD, ADDU, SUB, SUBU, AND, OR,
XOR, NOR y SLT), las operaciones tipo I disponibles (ADDI, ADDIU, SLTI,
ANDI, ORI, XORI y LUI), BEQ, J, LW y SW.

El programa de prueba se carga desde
`instrucciones_completas.txt`. El testbench inicializa los registros y la RAM
antes de ejecutar el programa. Para ejecutar la prueba desde el directorio
raiz del proyecto:

```text
vlib work
vlog -work work src\datapath\adder.v src\datapath\alu.v src\datapath\mux.v src\datapath\pc.v src\datapath\ram.v src\datapath\register_bank.v src\datapath\rom.v src\datapath\shiftLeft.v src\datapath\signExt.v src\control\alu_control.v src\control\control_unit.v src\processor_top.v tb\all_instructions_tb.v
vsim -c -lib work all_instructions_tb -do "run -all; quit -f"
```

La salida de consola muestra el estado de cada ciclo y una linea `PASS` o
`FAIL` por verificacion. Tambien se imprime el resumen final
`PASS: todas las instrucciones implementadas fueron probadas.` cuando no hay
errores.

Para visualizar las instrucciones y los datos internos en el Wave de
ModelSim:

```text
vsim -lib work all_instructions_tb
do {tb\all_instructions_wave.do}
run 320 ns
```