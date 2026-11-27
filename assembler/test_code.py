import unittest
import os
import tempfile

from assembler.code import (
    MAX_CHARS,
    MAX_INSTR,
    COMPLETION_MARKER,
    ensamblar,
    generar_asm,
    simular,
    cesar_py,
    escribir_mif,
    OUT_OFFSET,
)


class EnsamblarHazardsTests(unittest.TestCase):
    def test_inserts_three_nops_for_immediate_raw_dependency(self):
        programa = ensamblar([
            "addi $t0, $zero, 7",
            "add $t1, $t0, $zero",
        ])

        self.assertEqual(len(programa), 5)
        self.assertEqual([palabra for _, _, palabra in programa[1:4]], [0, 0, 0])
        self.assertEqual(programa[4][2] & 0x3F, 0x20)

    def test_does_not_insert_nops_when_three_instructions_separate_dependency(self):
        programa = ensamblar([
            "addi $t0, $zero, 7",
            "addi $t1, $zero, 1",
            "addi $t2, $zero, 2",
            "addi $t3, $zero, 3",
            "add $t4, $t0, $zero",
        ])

        self.assertEqual(len(programa), 5)
        self.assertEqual(programa[4][2] & 0x3F, 0x20)

    def test_handles_load_store_and_branch_operands(self):
        programa = ensamblar([
            "lw $t0, 0($zero)",
            "sw $t0, 4($zero)",
            "beq $t0, $zero, destino",
            "addi $t1, $zero, 1",
            "destino: addi $t2, $zero, 2",
        ])

        self.assertEqual([palabra for _, _, palabra in programa[1:4]], [0, 0, 0])
        branch_index = next(
            indice for indice, (_, instruccion, _) in enumerate(programa)
            if instruccion.startswith("beq")
        )
        branch_word = programa[branch_index][2]
        self.assertEqual(branch_word & 0xFFFF, 4)

    def test_simulator_accepts_nop_encoding(self):
        programa = ensamblar([
            "nop",
            "detener: j detener",
        ])

        self.assertEqual(programa[0][2], 0)
        self.assertEqual(simular([palabra for _, _, palabra in programa]), [0] * 64)

    def test_writes_quartus_mif_in_little_endian_and_pads_rom(self):
        with tempfile.TemporaryDirectory() as directorio:
            ruta = os.path.join(directorio, "instrucciones.mif")
            escribir_mif([0x200E004A], ruta)

            with open(ruta, encoding="ascii") as archivo:
                contenido = archivo.read().splitlines()

        self.assertIn("WIDTH=8;", contenido)
        self.assertIn("DEPTH=1024;", contenido)
        self.assertIn("    0 : 01001010;", contenido)
        self.assertIn("    1 : 00000000;", contenido)
        self.assertIn("    2 : 00001110;", contenido)
        self.assertIn("    3 : 00100000;", contenido)
        self.assertIn("    1023 : 00000000;", contenido)
        self.assertEqual(contenido[-1], "END;")

    def test_inserts_branch_and_jump_delay_slots_and_relocates_labels(self):
        programa = ensamblar([
            "beq $zero, $zero, destino",
            "addi $t0, $zero, 1",
            "destino: j destino",
        ])

        self.assertEqual(
            [instruccion for _, instruccion, _ in programa[1:4]],
            ["nop", "nop", "nop"],
        )
        self.assertEqual(programa[0][2] & 0xFFFF, 4)
        self.assertEqual(
            [instruccion for _, instruccion, _ in programa[5:8]],
            ["nop", "nop", "nop"],
        )
        self.assertEqual(programa[8][1], "j destino")
        self.assertEqual(programa[9][1], "nop")
        self.assertEqual(programa[8][2] & 0x3FFFFFF, 5)

    def test_maximum_generated_program_fits_rom_and_simulates(self):
        frase = "A" * MAX_CHARS
        for modo in ("cifrar", "descifrar"):
            programa = ensamblar(generar_asm(frase, 3, modo))
            self.assertLessEqual(len(programa), MAX_INSTR)

            ram = simular([palabra for _, _, palabra in programa])
            resultado = "".join(
                chr(ram[OUT_OFFSET // 4 + indice])
                for indice in range(len(frase))
            )
            self.assertEqual(resultado, cesar_py(frase, 3, modo))
            self.assertEqual(ram[63], COMPLETION_MARKER)


if __name__ == "__main__":
    unittest.main()
