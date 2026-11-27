#!/usr/bin/env python3
"""
cesar_mips_simple.py

Cifra o descifra una frase con Cesar y genera instrucciones MIPS
para el microprocesador monociclo de la FPGA DE10-Lite.

Se conserva el funcionamiento del programa original:
- Maximo 17 caracteres.
- Maximo 256 instrucciones (capacidad de la ROM de instrucciones).
- Una palabra de RAM por caracter.
- Resultado en RAM desde la direccion 72.
- Archivo instrucciones.txt con bytes en orden little-endian.
"""

import argparse
import os
import sys

# 1. CONFIGURACION

MAX_CHARS = 17
MAX_INSTR = 256
OUT_OFFSET = 72
COMPLETION_MARKER = 0x5A5A

# ------------------------------------------------------------
# CAMBIAR AQUI EL NOMBRE DEL ARCHIVO DE SALIDA:
# Si deseas otro nombre, reemplaza "instrucciones.txt".
# Este nombre se usa tambien para la copia opcional de Quartus.
ARCHIVO_INSTRUCCIONES = "instrucciones.txt"
# ------------------------------------------------------------

# Registros MIPS utilizados por el ensamblador.
REGS = {"$zero": 0}

for i in range(8):
    REGS[f"$t{i}"] = 8 + i
    REGS[f"$s{i}"] = 16 + i

REGS["$t8"] = 24
REGS["$t9"] = 25

# Codigo de funcion para instrucciones tipo R.
R_FUNCT = {
    "add": 0x20,
    "addu": 0x21,
    "sub": 0x22,
    "subu": 0x23,
    "and": 0x24,
    "or": 0x25,
    "xor": 0x26,
    "nor": 0x27,
    "slt": 0x2A,
}

# Opcode para instrucciones tipo I.
I_OP = {
    "addi": 0x08,
    "addiu": 0x09,
    "slti": 0x0A,
    "andi": 0x0C,
    "ori": 0x0D,
    "xori": 0x0E,
    "lui": 0x0F,
    "lw": 0x23,
    "sw": 0x2B,
    "beq": 0x04,
}

# Opcode para instrucciones tipo J.
J_OP = {"j": 0x02}

# Numero de instrucciones independientes necesarias entre una escritura y
# la siguiente lectura del registro en el pipeline sin forwarding.
NOP_HAZARD_COUNT = 3
BRANCH_DELAY_SLOTS = 3
JUMP_DELAY_SLOTS = 1
JUMP_TARGET_GUARD_NOPS = 3

# 2. GENERACION DEL PROGRAMA MIPS

def generar_asm(frase, clave, modo):
    """
    Construye una lista de instrucciones MIPS.

    Primero carga la frase en RAM. Despues agrega las instrucciones
    que recorren los caracteres y aplican el cifrado o descifrado.
    """
    instrucciones = []

    # Instrucciones que se alternan para cargar cada caracter.
    cargar_ops = ["addi", "ori", "addiu"]

    # --------------------------------------------------------
    # Cargar la frase en RAM: un caracter por palabra.
    # --------------------------------------------------------
    instrucciones.append("# --- carga de la frase en RAM (1 caracter por palabra) ---")

    for i, caracter in enumerate(frase):
        operacion = cargar_ops[i % 3]
        instrucciones.append(
            f"{operacion} $t6, $zero, {ord(caracter)}   # '{caracter}'"
        )
        instrucciones.append(f"sw $t6, {4 * i}($zero)")

    # --------------------------------------------------------
    # Cargar constantes y preparar registros.
    # --------------------------------------------------------
    instrucciones += [
        "# --- constantes ---",
        "lui   $s0, 0                  # puntero = 0",
        f"addi  $s1, $zero, {4 * len(frase)}          # fin = 4*n",
        f"addi  $s2, $zero, {clave}                  # clave k",
        "ori   $t8, $zero, 32          # bit 5 (0x20)",
        "nor   $s3, $t8, $zero         # mascara para convertir a mayuscula",
        "xori  $s5, $zero, 1           # constante 1",
        "addi  $s6, $zero, 26          # tamano del alfabeto",
        "addi  $s7, $zero, 90          # caracter Z",
        "# --- bucle principal ---",
    ]

    cifrar = modo == "cifrar"

    # --------------------------------------------------------
    # Leer un caracter y comprobar si es una letra.
    # --------------------------------------------------------
    instrucciones += [
        "ciclo: lw    $t0, 0($s0)           # c = RAM[ptr]",
        f"{'add' if cifrar else 'or '}   $t3, $t0, $zero        # salida = c",
        "and   $t1, $t0, $s3           # convertir temporalmente a mayuscula",
        "slti  $t2, $t1, 65            # C < 'A' ?",
        "beq   $t2, $s5, guardar       # si no es letra, copiar",
        "slt   $t2, $s7, $t1           # 'Z' < C ?",
        "beq   $t2, $s5, guardar       # si no es letra, copiar",
    ]

    # --------------------------------------------------------
    # Aplicar el desplazamiento Cesar.
    # --------------------------------------------------------
    if cifrar:
        instrucciones += [
            "addu  $t3, $t1, $s2           # C + k",
            "slt   $t2, $s7, $t3           # comprobar si supera Z",
            "beq   $t2, $zero, nowrap",
            "sub   $t3, $t3, $s6           # regresar al inicio del alfabeto",
        ]
    else:
        instrucciones += [
            "subu  $t3, $t1, $s2           # C - k",
            "slti  $t2, $t3, 65            # comprobar si queda antes de A",
            "beq   $t2, $zero, nowrap",
            "add   $t3, $t3, $s6           # regresar al final del alfabeto",
        ]

    # --------------------------------------------------------
    # Recuperar si la letra original era minuscula.
    # Guardar el resultado en la zona de salida de RAM.
    # --------------------------------------------------------
    instrucciones += [
        "nowrap: xor   $t4, $t0, $t1       # diferencia entre original y mayuscula",
        "andi  $t4, $t4, 32            # conservar el bit de minuscula",
        "or    $t3, $t3, $t4           # restaurar mayusculas/minusculas",
        f"guardar: sw   $t3, {OUT_OFFSET}($s0)      # guardar resultado",
        "addiu $s0, $s0, 4             # avanzar al siguiente caracter",
    ]

    # Condicion para terminar el recorrido.
    if cifrar:
        instrucciones.append("beq   $s0, $s1, fin          # fin de la frase")
    else:
        instrucciones += [
            "sub   $t9, $s0, $s1           # ptr - fin",
            "beq   $t9, $zero, fin",
        ]

    instrucciones += [
        "j     ciclo",
        f"fin: addi $t9, $zero, {COMPLETION_MARKER}  # marca de programa terminado",
        "sw   $t9, 252($zero)           # RAM[63] indica que el resultado esta listo",
        "detener: j detener             # detener el programa",
    ]

    return instrucciones

# 3. ENSAMBLADOR: MIPS A CODIGO MAQUINA

def registros_usados(linea):
    """Regresa los registros leidos y escritos por una instruccion."""
    partes = linea.replace(",", " ").split()
    mnemonico = partes[0]
    operandos = partes[1:]

    if mnemonico in R_FUNCT:
        return operandos[1:3], operandos[0]

    if mnemonico == "lui":
        return [], operandos[0]

    if mnemonico in ("lw", "sw"):
        registro_base = operandos[1].rstrip(")").split("(")[1]
        if mnemonico == "lw":
            return [registro_base], operandos[0]
        return [operandos[0], registro_base], None

    if mnemonico == "beq":
        return operandos[0:2], None

    if mnemonico in I_OP:
        return [operandos[1]], operandos[0]

    if mnemonico in J_OP or mnemonico == "nop":
        return [], None

    raise ValueError(f"Instruccion no soportada: {linea}")


def insertar_nops_hazards(instrucciones, etiquetas_originales):
    """Inserta NOPs de datos y control, y ajusta las direcciones de etiquetas."""
    instrucciones_ajustadas = []
    indice_ajustado = []
    ultima_escritura = {}
    destinos_jump = {
        etiquetas_originales[linea.split()[1]]
        for linea in instrucciones
        if linea.split()[0] in J_OP
    }

    for indice, linea in enumerate(instrucciones):
        indice_ajustado.append(len(instrucciones_ajustadas))
        if indice in destinos_jump:
            instrucciones_ajustadas.extend(
                ["nop"] * JUMP_TARGET_GUARD_NOPS
            )

        registros_leidos, registro_escrito = registros_usados(linea)
        nops_necesarios = 0

        for registro in registros_leidos:
            if registro == "$zero" or registro not in ultima_escritura:
                continue

            instrucciones_intermedias = (
                len(instrucciones_ajustadas) - ultima_escritura[registro] - 1
            )
            nops_necesarios = max(
                nops_necesarios,
                NOP_HAZARD_COUNT - instrucciones_intermedias
            )

        instrucciones_ajustadas.extend(
            ["nop"] * max(0, nops_necesarios)
        )
        instrucciones_ajustadas.append(linea)

        if registro_escrito and registro_escrito != "$zero":
            ultima_escritura[registro_escrito] = len(instrucciones_ajustadas) - 1

        mnemonico = linea.split()[0]
        if mnemonico == "beq":
            instrucciones_ajustadas.extend(["nop"] * BRANCH_DELAY_SLOTS)
        elif mnemonico in J_OP:
            instrucciones_ajustadas.extend(["nop"] * JUMP_DELAY_SLOTS)

    indice_ajustado.append(len(instrucciones_ajustadas))
    etiquetas_ajustadas = {
        etiqueta: indice_ajustado[indice]
        for etiqueta, indice in etiquetas_originales.items()
    }

    return instrucciones_ajustadas, etiquetas_ajustadas

def ensamblar(lineas):
    """
    Convierte instrucciones MIPS a palabras de 32 bits.

    Regresa una lista de tuplas:
    (direccion, instruccion_original, palabra_binaria_como_entero).
    """

    instrucciones_limpias = []
    etiquetas_originales = {}

    # --------------------------------------------------------
    # Primera pasada: quitar comentarios y registrar etiquetas.
    # --------------------------------------------------------
    for linea in lineas:
        linea = linea.split("#")[0].strip()

        if not linea:
            continue

        while ":" in linea:
            etiqueta, linea = linea.split(":", 1)
            etiquetas_originales[etiqueta.strip()] = len(instrucciones_limpias)
            linea = linea.strip()

        if linea:
            instrucciones_limpias.append(linea)

    instrucciones_limpias, etiquetas = insertar_nops_hazards(
        instrucciones_limpias, etiquetas_originales
    )

    # --------------------------------------------------------
    # Segunda pasada: convertir cada instruccion a 32 bits.
    # --------------------------------------------------------
    programa = []

    for indice, linea in enumerate(instrucciones_limpias):
        mnemonico, _, operandos_texto = linea.partition(" ")

        if operandos_texto.strip():
            operandos = [op.strip() for op in operandos_texto.split(",")]
        else:
            operandos = []

        # NOP: SLL $zero, $zero, 0 (codificacion MIPS canonica).
        if mnemonico == "nop":
            palabra = 0

        # Instrucciones tipo R: add, sub, and, or, etc.
        elif mnemonico in R_FUNCT:
            rd, rs, rt = (REGS[op] for op in operandos)

            palabra = (
                (rs << 21)
                | (rt << 16)
                | (rd << 11)
                | R_FUNCT[mnemonico]
            )

        # LUI tiene un formato especial dentro de las tipo I.
        elif mnemonico == "lui":
            palabra = (
                (I_OP[mnemonico] << 26)
                | (REGS[operandos[0]] << 16)
                | (int(operandos[1], 0) & 0xFFFF)
            )

        # LW y SW usan el formato desplazamiento(registro).
        elif mnemonico in ("lw", "sw"):
            desplazamiento, registro_base = operandos[1].rstrip(")").split("(")

            palabra = (
                (I_OP[mnemonico] << 26)
                | (REGS[registro_base] << 21)
                | (REGS[operandos[0]] << 16)
                | (int(desplazamiento, 0) & 0xFFFF)
            )

        # BEQ usa un desplazamiento relativo a la siguiente instruccion.
        elif mnemonico == "beq":
            rs = REGS[operandos[0]]
            rt = REGS[operandos[1]]
            desplazamiento = etiquetas[operandos[2]] - (indice + 1)

            palabra = (
                (I_OP[mnemonico] << 26)
                | (rs << 21)
                | (rt << 16)
                | (desplazamiento & 0xFFFF)
            )

        # Resto de instrucciones tipo I.
        elif mnemonico in I_OP:
            rt = REGS[operandos[0]]
            rs = REGS[operandos[1]]
            inmediato = int(operandos[2], 0)

            palabra = (
                (I_OP[mnemonico] << 26)
                | (rs << 21)
                | (rt << 16)
                | (inmediato & 0xFFFF)
            )

        # Instrucciones tipo J.
        elif mnemonico in J_OP:
            palabra = (J_OP[mnemonico] << 26) | etiquetas[operandos[0]]

        else:
            raise ValueError(f"Instruccion no soportada: {linea}")

        programa.append((indice * 4, linea, palabra & 0xFFFFFFFF))

    return programa

# 4. SIMULADOR DEL MICROPROCESADOR MIPS

def simular(palabras, max_pasos=5000):
    """
    Ejecuta las palabras de codigo maquina.

    Simula los 32 registros, las 64 palabras de RAM y el contador
    de programa (PC), siguiendo las operaciones implementadas
    en el Verilog del microprocesador.
    """
    registros = [0] * 32
    ram = [0] * 64
    pc = 0
    mascara_32 = 0xFFFFFFFF
    estados_vistos = set()

    # Convertir un numero de 32 bits a entero con signo.
    def con_signo_32(numero):
        if numero & 0x80000000:
            return numero - (1 << 32)
        return numero

    # Convertir un inmediato de 16 bits a entero con signo.
    def con_signo_16(numero):
        if numero & 0x8000:
            return numero - 0x10000
        return numero

    for _ in range(max_pasos):
        estado = (pc, tuple(registros), tuple(ram))
        if estado in estados_vistos:
            return ram
        estados_vistos.add(estado)

        palabra = palabras[pc // 4]

        # Separar los campos de la instruccion.
        opcode = palabra >> 26
        rs = (palabra >> 21) & 31
        rt = (palabra >> 16) & 31
        rd = (palabra >> 11) & 31
        funcion = palabra & 63
        inmediato = palabra & 0xFFFF

        A = registros[rs]
        B = registros[rt]
        siguiente_pc = pc + 4

        # NOP: no modifica el estado del procesador.
        if palabra == 0:
            pass

        # ----------------------------------------------------
        # Tipo R: operaciones entre registros.
        # ----------------------------------------------------
        elif opcode == 0:
            operaciones = {
                0x20: A + B,                    # add
                0x21: A + B,                    # addu
                0x22: A - B,                    # sub
                0x23: A - B,                    # subu
                0x24: A & B,                    # and
                0x25: A | B,                    # or
                0x26: A ^ B,                    # xor
                0x27: ~(A | B),                 # nor
                0x2A: int(con_signo_32(A) < con_signo_32(B)),  # slt
            }

            resultado = operaciones[funcion] & mascara_32

            if rd != 0:
                registros[rd] = resultado

        # ----------------------------------------------------
        # ADDI y ADDIU.
        # ----------------------------------------------------
        elif opcode in (0x08, 0x09):
            if rt != 0:
                registros[rt] = (A + con_signo_16(inmediato)) & mascara_32

        # SLTI.
        elif opcode == 0x0A:
            if rt != 0:
                registros[rt] = int(
                    con_signo_32(A) < con_signo_16(inmediato)
                )

        # ANDI.
        elif opcode == 0x0C:
            if rt != 0:
                registros[rt] = A & inmediato

        # ORI.
        elif opcode == 0x0D:
            if rt != 0:
                registros[rt] = A | inmediato

        # XORI.
        elif opcode == 0x0E:
            if rt != 0:
                registros[rt] = A ^ inmediato

        # LUI.
        elif opcode == 0x0F:
            if rt != 0:
                registros[rt] = (inmediato << 16) & mascara_32

        # LW: leer una palabra de RAM.
        elif opcode == 0x23:
            if rt != 0:
                direccion = (A + con_signo_16(inmediato)) & mascara_32
                indice_ram = (direccion >> 2) & 63
                registros[rt] = ram[indice_ram]

        # SW: guardar una palabra en RAM.
        elif opcode == 0x2B:
            direccion = (A + con_signo_16(inmediato)) & mascara_32
            indice_ram = (direccion >> 2) & 63
            ram[indice_ram] = B

        # BEQ: saltar si los registros son iguales.
        elif opcode == 0x04:
            if A == B:
                siguiente_pc = pc + 4 + (con_signo_16(inmediato) << 2)

        # J: salto directo.
        elif opcode == 0x02:
            siguiente_pc = (palabra & 0x3FFFFFF) << 2

            # Un salto a la misma direccion detiene el programa.
            if siguiente_pc == pc:
                return ram

        else:
            raise RuntimeError(f"opcode no soportado {opcode:#x}")

        pc = siguiente_pc

    raise RuntimeError("el programa no termino")

# 5. FUNCIONES AUXILIARES: RESULTADO Y ARCHIVO

def cesar_py(texto, clave, modo):
    """
    Calcula el resultado esperado usando Python.
    Esta funcion sirve para comprobar el resultado del simulador.
    """
    if modo == "descifrar":
        clave = -clave

    resultado = ""

    for caracter in texto:
        if caracter.isalpha():
            base = 65 if caracter.isupper() else 97
            nuevo_codigo = (ord(caracter) - base + clave) % 26 + base
            resultado += chr(nuevo_codigo)
        else:
            resultado += caracter

    return resultado

def escribir_txt(palabras, ruta):
    """
    Escribe cada instruccion en cuatro lineas de 8 bits y completa el archivo
    hasta tener 1024 lineas.

    Se escribe primero el byte menos significativo (little-endian),
    tal como lo necesita la ROM del proyecto.
    """
    lineas = len(palabras) * 4
    if lineas > 1024:
        raise ValueError("El archivo admite como maximo 256 instrucciones.")

    with open(ruta, "w", newline="") as archivo:
        for palabra in palabras:
            for byte in range(4):
                valor_byte = (palabra >> (8 * byte)) & 0xFF
                archivo.write(f"{valor_byte:08b}\r\n")
        for _ in range(1024 - lineas -1):
            archivo.write("00000000\n")

def escribir_mif(palabras, ruta):
    """Escribe una imagen MIF de bytes para inicializar la ROM en Quartus."""
    if len(palabras) > MAX_INSTR:
        raise ValueError(f"La ROM solo admite {MAX_INSTR} instrucciones.")

    datos = [
        (palabra >> (8 * byte)) & 0xFF
        for palabra in palabras
        for byte in range(4)
    ]
    datos.extend([0] * (MAX_INSTR * 4 - len(datos)))

    with open(ruta, "w", newline="\n") as archivo:
        archivo.write(
            "WIDTH=8;\n"
            f"DEPTH={MAX_INSTR * 4};\n"
            "ADDRESS_RADIX=UNS;\n"
            "DATA_RADIX=BIN;\n"
            "CONTENT BEGIN\n"
        )
        for direccion, valor in enumerate(datos):
            archivo.write(f"    {direccion} : {valor:08b};\n")
        archivo.write("END;\n")

def mostrar_datos_entrada(frase):
    """Muestra los codigos ASCII y HEX de cada caracter."""
    print("\nASCII:", " ".join(str(ord(c)) for c in frase))
    print("HEX  :", " ".join(f"{ord(c):02X}" for c in frase))

def mostrar_programa(programa, cantidad_caracteres, modo):
    """
    Muestra TODAS las instrucciones ensambladas, agrupadas por etapa.
    Las direcciones, el binario y el hexadecimal corresponden al código
    máquina que se escribe en instrucciones.txt.
    """
    n = cantidad_caracteres
    inicio_constantes = 2 * n
    inicio_lectura = inicio_constantes + 8
    inicio_algoritmo = inicio_lectura + 7
    inicio_restauracion = inicio_algoritmo + 4
    inicio_control = inicio_restauracion + 5

    etapas = [
        (0, inicio_constantes, "1. CARGA DE LA FRASE EN RAM"),
        (inicio_constantes, inicio_lectura, "2. PREPARACION DE CONSTANTES"),
        (inicio_lectura, inicio_algoritmo, "3. LECTURA Y VALIDACION DEL CARACTER"),
        (inicio_algoritmo, inicio_restauracion,
         "4. CIFRADO" if modo == "cifrar" else "4. DESCIFRADO"),
        (inicio_restauracion, inicio_control,
         "5. RESTAURACION DE MAYUSCULAS/MINUSCULAS Y ALMACENAMIENTO"),
        (inicio_control, len(programa), "6. CONTROL DEL BUCLE Y FIN"),
    ]

    print(f"\\n=== LISTADO COMPLETO DE ENSAMBLADOR ({len(programa)}/{MAX_INSTR}) ===")
    etapa_actual = 0

    for direccion, texto, palabra in programa:
        indice = direccion // 4

        while etapa_actual < len(etapas) and indice >= etapas[etapa_actual][1]:
            etapa_actual += 1

        if etapa_actual < len(etapas):
            inicio, fin, titulo = etapas[etapa_actual]
            if indice == inicio:
                print(f"\\n--- {titulo} ---")

        instruccion = texto.split("#")[0].strip()
        print(f"{direccion:03d}: {palabra:032b}  {palabra:08X}  {instruccion}")

def verificar_resultado(ram, frase, clave, modo):
    """Muestra entrada, resultado esperado en Python y resultado obtenido de RAM."""
    resultado_ram = "".join(
        chr(ram[(OUT_OFFSET // 4) + i])
        for i in range(len(frase))
    )
    esperado = cesar_py(frase, clave, modo)
    correcto = resultado_ram == esperado

    print("\\n=== COMPROBACION DEL RESULTADO ===")
    print(f"Palabra/frase ingresada       : {frase!r}")
    print(f"Resultado esperado (Python)   : {esperado!r}")
    print(f"Resultado simulado (RAM)      : {resultado_ram!r}")
    print(f"Estado de la comprobacion     : {'CORRECTO' if correcto else 'ERROR'}")

    if not correcto:
        print("El resultado de RAM no coincide con el resultado esperado.")

    print(
        "Codigos ASCII del resultado  :",
        " ".join(str(ord(c)) for c in resultado_ram)
    )

def obtener_destinos(salida, copiar_quartus):
    """Determina en que rutas se guardara instrucciones.txt."""
    carpeta_actual = os.path.dirname(os.path.abspath(__file__))

    if os.path.isdir(os.path.join(os.path.dirname(carpeta_actual), "src")):
        raiz = os.path.dirname(carpeta_actual)
    else:
        raiz = carpeta_actual

    destinos = [salida or os.path.join(raiz, ARCHIVO_INSTRUCCIONES)]

    if copiar_quartus:
        destinos.append(
            os.path.join(raiz, "quartus", ARCHIVO_INSTRUCCIONES)
        )

    return destinos

def guardar_archivos(palabras, destinos):
    """Crea los archivos de instrucciones de simulacion y sintesis."""
    for destino in destinos:
        ya_existia = os.path.exists(destino)

        os.makedirs(os.path.dirname(destino) or ".", exist_ok=True)
        escribir_txt(palabras, destino)

        estado = "Actualizado" if ya_existia else "Creado"
        print(f"{estado}: {destino}  ({len(palabras) * 4} bytes)")

        ruta_mif = os.path.join(
            os.path.dirname(destino), "instrucciones.mif"
        )
        mif_existia = os.path.exists(ruta_mif)
        escribir_mif(palabras, ruta_mif)
        estado_mif = "Actualizado" if mif_existia else "Creado"
        print(f"{estado_mif}: {ruta_mif}")

# 6. PROGRAMA PRINCIPAL

def obtener_argumentos():
    """Lee los parametros escritos al ejecutar el programa."""
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawTextHelpFormatter
    )

    parser.add_argument("-m", "--modo", choices=["cifrar", "descifrar"])
    parser.add_argument("-f", "--frase")
    parser.add_argument("-k", "--clave", type=int)
    parser.add_argument("-o", "--salida", help="ruta alternativa del archivo de instrucciones")
    parser.add_argument(
        "--quartus",
        action="store_true",
        help="copiar tambien a quartus/instrucciones.txt"
    )

    return parser.parse_args()

def decodificar_salida_fpga(texto):
    """Convierte una salida binaria de la FPGA en caracteres ASCII.

    Acepta bits continuos o separados en grupos por espacios o saltos
    de linea. Si el texto no parece una cadena binaria, lo deja igual.
    """
    bits = "".join(texto.split())

    # Solo interpretamos como binario una cadena formada por 0 y 1.
    if not bits or any(bit not in "01" for bit in bits):
        return texto, False

    if len(bits) % 8 != 0:
        raise ValueError(
            "La salida binaria debe contener grupos completos de 8 bits."
        )

    caracteres = []
    for inicio in range(0, len(bits), 8):
        byte = bits[inicio:inicio + 8]
        codigo = int(byte, 2)

        if codigo > 127:
            raise ValueError(
                f"El byte {byte} no representa un caracter ASCII valido."
            )

        caracteres.append(chr(codigo))

    return "".join(caracteres), True


def obtener_datos(args):
    """Obtiene el modo, la frase y la clave desde argumentos o preguntas."""
    if args.modo:
        modo = args.modo
    else:
        respuesta = input("Modo [1=cifrar, 2=descifrar]: ").strip()
        modo = "descifrar" if respuesta == "2" else "cifrar"

    if args.frase is not None:
        frase = args.frase
    elif modo == "cifrar":
        frase = input("Frase a cifrar: ")
    else:
        frase = input("Texto cifrado (salida de la FPGA): ")

    if args.clave is not None:
        clave = args.clave
    else:
        clave = int(input("Clave (1-25): "))

    # Al descifrar, aceptar directamente la salida binaria de la FPGA.
    if modo == "descifrar":
        try:
            frase, era_binario = decodificar_salida_fpga(frase)
        except ValueError as error:
            sys.exit(f"Error en la salida de la FPGA: {error}")

        if era_binario:
            print("\nSalida binaria de la FPGA detectada.")
            print("Texto ASCII recibido:", repr(frase))

    return modo, frase, clave

def validar_datos(frase, clave):
    """Comprueba que la frase y la clave cumplan las restricciones."""
    if not 0 < len(frase) <= MAX_CHARS:
        sys.exit(
            f"Error: la frase debe tener entre 1 y {MAX_CHARS} caracteres."
        )

    if any(ord(caracter) > 127 for caracter in frase):
        sys.exit("Error: solo caracteres ASCII (sin acentos ni enie).")

    if not 0 <= clave <= 25:
        sys.exit("Error: la clave debe estar entre 0 y 25.")

def mostrar_bienvenida():
    """Presenta el objetivo del programa antes de solicitar los datos."""
    print("\\n---------------- Bienvenidos al Programa ----------------")
    print(
        "Este programa genera instrucciones en ensamblador MIPS para cifrar o descifrar un texto con el codigo Cesar.\n"
        "Despues convierte cada instruccion a codigo binario de 32 bits, "
        "separa sus bytes en orden little-endian (del byte menos "
        "significativo al mas significativo) y los guarda en "
        f"{ARCHIVO_INSTRUCCIONES}."
    )
    print("----------------------------------------------------------\\n")


def main():
    """Coordina todas las etapas del programa."""
    mostrar_bienvenida()
    args = obtener_argumentos()
    modo, frase, clave = obtener_datos(args)

    validar_datos(frase, clave)
    mostrar_datos_entrada(frase)

    # 1. Generar instrucciones MIPS.
    lineas_asm = generar_asm(frase, clave, modo)

    # 2. Ensamblar las instrucciones a palabras de 32 bits.
    programa = ensamblar(lineas_asm)

    if len(programa) > MAX_INSTR:
        sys.exit(
            f"Error: {len(programa)} instrucciones; "
            f"la ROM solo admite {MAX_INSTR}."
        )

    palabras = [palabra for _, _, palabra in programa]
    mostrar_programa(programa, len(frase), modo)

    # 3. Simular el microprocesador.
    ram = simular(palabras)

    # 4. Comprobar el resultado con el algoritmo de Python.
    verificar_resultado(ram, frase, clave, modo)

    # 5. Guardar instrucciones.txt.
    destinos = obtener_destinos(args.salida, args.quartus)
    guardar_archivos(palabras, destinos)

    print(
        f"\\nArchivo cargado o sobrescrito correctamente en "
        f"{ARCHIVO_INSTRUCCIONES}."
    )
    print(
        "Nota: al ejecutar el diseño en la FPGA tambien se actualizaran "
        "memram.txt y registersData.txt, si esos archivos estan "
        "configurados en tu proyecto de hardware."
    )

if __name__ == "__main__":
    main()