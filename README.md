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
vlog -work work src/datapath/*.v src/control/*.v src/processor_top.v tb/type_r_monocycle_tb.v
vsim -c -lib work type_r_monocycle_tb -do "run -all; quit -f"
```

Para abrir las señales de la ALU en el Wave de ModelSim:

```text
vsim -lib work type_r_monocycle_tb
do {tb/type_r_wave.do}
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
vlog -work work src/datapath/adder.v src/datapath/alu.v src/datapath/mux.v src/datapath/pc.v src/datapath/ram.v src/datapath/register_bank.v src/datapath/rom.v src/datapath/shiftLeft.v src/datapath/signExt.v src/control/alu_control.v src/control/control_unit.v src/processor_top.v tb/all_instructions_tb.v
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
do {tb/all_instructions_wave.do}
run 320 ns
```

## Prueba del pipeline de cinco etapas

`tb/pipeline_full_tb.v` carga un programa autocontenido en la ROM de la
simulacion y verifica las nueve operaciones tipo R, las siete tipo I, `LW`,
`SW`, `BEQ` tomado/no tomado y `J`. Comprueba resultados del banco de registros
y RAM, instrucciones que deben omitirse, y cuenta ciclos donde hay trabajo
simultaneo en IF, ID, EX, MEM y WB.

Ejecutar desde la raiz con ModelSim:

```text
vlib work
vlog -work work src/datapath/adder.v src/datapath/alu.v src/datapath/mux.v src/datapath/pc.v src/datapath/ram.v src/datapath/register_bank.v src/datapath/rom.v src/datapath/shiftLeft.v src/datapath/signExt.v src/control/alu_control.v src/control/control_unit.v src/pipeline/if_id.v src/pipeline/id_ex.v src/pipeline/ex_mem.v src/pipeline/mem_wb.v src/processor_top.v tb/pipeline_full_tb.v
vsim -c -lib work pipeline_full_tb -do "run -all; quit -f"
```

El testbench tambien ejecuta una secuencia con tres NOP entre productor y
consumidor, y comprueba que el resultado de la dependencia RAW sea correcto.
El procesador no implementa forwarding ni interlocks/stalls; sin esos NOPs,
un consumidor puede leer un valor antiguo antes de que su productor llegue a
WB. `LW` seguido de una instruccion que use su destino requiere el mismo
espaciado.

Los saltos tambien requieren cuidado: `BEQ` se resuelve en MEM y no se anulan
las instrucciones que ya entraron al pipeline; en esta implementacion se
ejecutan tres instrucciones posteriores como delay slots. `J` se selecciona
desde ID y deja una instruccion posterior en vuelo. La prueba coloca
instrucciones deliberadas en esos slots y verifica que las siguientes del
camino secuencial se omitan.

## NOPs y capacidad de instrucciones

`assembler/code.py` inserta automaticamente los NOPs para dependencias RAW,
tres NOPs despues de cada `BEQ`, uno despues de cada `J` y tres NOPs al inicio
de cada destino `J` para proteger dependencias que cruzan el salto. Al finalizar
escribe la marca `0x5A5A` en RAM[63]; el wrapper la detecta, captura el texto y
enciende LEDR8. Genera `instrucciones.txt` para simulacion y
`quartus/instrucciones.mif` para inicializar la ROM en Quartus. Tambien recalcula
las etiquetas y offsets. Esto no reemplaza forwarding ni una unidad de deteccion
de hazards.

La ROM de instrucciones ahora admite 256 palabras (1024 bytes), igual que el
limite `MAX_INSTR` del ensamblador; el test valida que el programa maximo
generado quepa. Ejecuta las pruebas Python con
`python -m unittest assembler.test_code`.

## Mostrar el resultado en la DE10-Lite

Al terminar un programa generado por `assembler/code.py`, el wrapper detecta
el bucle final, lee el texto de salida desde RAM[18..34] y lo conserva para
mostrarlo. Selecciona `SW[3:1] = 101` para ver el resultado en HEX5..HEX0; el
texto se desplaza automaticamente cada medio segundo. Los otros valores de
`SW[3:1]` conservan las vistas de depuracion existentes.

El reloj del procesador es automatico y lento: coloca `SW0` en ON para
ejecutar y en OFF para pausar. El divisor por defecto cambia el nivel del reloj
cada 5 ms, asi que produce un flanco ascendente cada 10 ms (aproximadamente
100 instrucciones por segundo). Se puede ajustar con el parametro
`CLOCK_DIVIDER_COUNT` del wrapper. `SW9` sigue siendo el reset y `LEDR8` se
enciende cuando termina el programa y se captura el resultado.

El mismo display muestra la salida de cifrado o descifrado: genera y carga el
programa de cifrado para ver el texto cifrado; despues genera/carga el programa
de descifrado con ese texto como entrada, reinicia y ejecuta para ver el texto
recuperado. Cada ejecucion muestra su propio resultado; al reiniciar, la RAM
se limpia, por lo que el display no conserva ambos textos simultaneamente. La
DE10-Lite solo puede mostrar seis caracteres a la vez y el alfabeto de 7
segmentos representa algunas letras de forma aproximada.

El test del wrapper puede ejecutarse desde la raiz con:

```text
vlog -work work src/datapath/adder.v src/datapath/alu.v src/datapath/mux.v src/datapath/pc.v src/datapath/ram.v src/datapath/register_bank.v src/datapath/rom.v src/datapath/shiftLeft.v src/datapath/signExt.v src/control/alu_control.v src/control/control_unit.v src/pipeline/if_id.v src/pipeline/id_ex.v src/pipeline/ex_mem.v src/pipeline/mem_wb.v src/processor_top.v src/de10_lite_top.v tb/de10_lite_display_tb.v
vsim -c -lib work de10_lite_display_tb -do "run -all; quit -f"
```