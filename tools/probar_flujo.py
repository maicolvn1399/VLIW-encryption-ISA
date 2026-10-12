#!/usr/bin/env python3
"""
probar_flujo.py - El flujo completo, de archivo a archivo.

CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4

Cierra la cadena del proyecto sobre un volcado DE VERDAD de la simulacion:

    archivo original
      -> load_file.py            imagen de DMEM
      -> tb_archivo.sv           el procesador cifra  ($writememh)
      -> extract_data.py         el criptograma como archivo
      -> modelo de referencia     descifrado en Python
      -> debe dar el archivo original, byte por byte

El ultimo paso es el que hace que esto valga la pena. tb_archivo.sv ya comprueba
que el hardware descifra lo que cifro, pero eso se cumpliria igual si F4E y F4D
estuvieran mal de forma inversa. Aqui el descifrado lo hace un modelo escrito en
Python a partir de la formula del enunciado, que no comparte una sola linea con
el RTL ni con el ensamblador. Si el criptograma que produjo el procesador se
deshace con ese modelo, entonces el procesador implementa Feistel4 y no otra
cosa parecida.

Se corre despues de tb_archivo, porque necesita el volcado que ese testbench
escribe:

    make archivo flujo

"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_data                                   # noqa: E402
from formato_buffer import empaquetar                  # noqa: E402

AQUI = Path(__file__).resolve().parent
ORIGINAL = AQUI / "programas" / "archivo_prueba.txt"

# La llave que instala vault_sesion.s, una palabra por ronda
LLAVE = [0x11111111, 0x22222222, 0x33333333, 0x44444444]

M = 0xFFFFFFFF

casos = 0
fallidos = 0


def check(nombre, condicion, detalle=""):
    global casos, fallidos
    casos += 1
    if condicion:
        print(f"  ok     {nombre}")
    else:
        fallidos += 1
        print(f"  FALLA  {nombre}")
        if detalle:
            for linea in str(detalle).splitlines():
                print(f"           {linea}")


# -----------------------------------------------------------------------------
# Modelo de referencia, escrito solo desde la formula del enunciado
#
#   F(x,k) = (ROL32(x,5) + k) XOR ROL32(x,13)
#   cifrar:    (L,R) -> (R, L XOR F(R,k))     rondas 0 a 3
#   descifrar: (L,R) -> (R XOR F(L,k), L)     rondas 3 a 0
# -----------------------------------------------------------------------------


def rol(x, n):
    return ((x << n) | (x >> (32 - n))) & M


def f_ronda(x, k):
    return ((rol(x, 5) + k) & M) ^ rol(x, 13)


def descifrar_bloque(L, R):
    for r in reversed(range(4)):
        L, R = R ^ f_ronda(L, LLAVE[r]), L
    return L, R


def cifrar_bloque(L, R):
    for r in range(4):
        L, R = R, L ^ f_ronda(R, LLAVE[r])
    return L, R


def main(volcado):
    print("=== probar_flujo: de archivo a archivo, sobre el volcado real ===")
    print("")

    original = ORIGINAL.read_bytes()
    print(f"  archivo original: {len(original)} bytes")

    ruta_volcado = Path(volcado)
    if not ruta_volcado.is_file():
        print(f"  FALLA  no se encontro el volcado {volcado}")
        print("           hay que correr antes el testbench: make archivo")
        return 1

    # --- el criptograma que produjo el procesador ---------------------------
    cifrado = AQUI / "programas" / "cifrado_de_la_simulacion.bin"
    import contextlib
    import io
    with contextlib.redirect_stdout(io.StringIO()):
        r = extract_data.main([str(ruta_volcado), "-o", str(cifrado)])
    check("extract_data lee el volcado de $writememh", r == 0, f"devolvio {r}")
    if r != 0:
        return 1

    datos_cif = cifrado.read_bytes()
    check("y recupera un archivo del mismo tamano que el original",
          len(datos_cif) == len(original),
          f"{len(datos_cif)} contra {len(original)}")
    check("que no es el original: el procesador si cifro",
          datos_cif != original)

    # --- el modelo de referencia lo deshace ---------------------------------
    pal = empaquetar(datos_cif)
    n_bloques = pal[1]
    claro = []
    for b in range(n_bloques):
        i = 2 + 2 * b
        L, R = descifrar_bloque(pal[i], pal[i + 1])
        claro += [L, R]

    recuperado = b"".join(p.to_bytes(4, "little") for p in claro)[:len(original)]

    check("el modelo de referencia descifra lo que cifro el hardware",
          recuperado == original,
          f"original   {original!r}\nrecuperado {recuperado!r}")

    # --- y en el otro sentido: el modelo cifra lo mismo que el hardware -----
    pal_claro = empaquetar(original)
    esperado = []
    for b in range(pal_claro[1]):
        i = 2 + 2 * b
        L, R = cifrar_bloque(pal_claro[i], pal_claro[i + 1])
        esperado += [L, R]
    bytes_esperados = b"".join(
        p.to_bytes(4, "little") for p in esperado)[:len(original)]

    check("y cifra byte por byte lo mismo que el hardware",
          datos_cif == bytes_esperados,
          f"hardware {datos_cif.hex()}\nmodelo   {bytes_esperados.hex()}")

    print("")
    print(f"  claro    {original!r}")
    print(f"  cifrado  {datos_cif.hex()}")
    print("")
    print("---")
    print(f"casos: {casos}   fallidos: {fallidos}")
    if fallidos:
        print("RESULTADO: FALLA")
        return 1
    print("RESULTADO: OK")
    return 0


if __name__ == "__main__":
    volcado = sys.argv[1] if len(sys.argv) > 1 else "cifrado_volcado.hex"
    sys.exit(main(volcado))
