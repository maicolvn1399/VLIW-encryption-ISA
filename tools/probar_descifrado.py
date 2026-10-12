#!/usr/bin/env python3
"""
probar_descifrado.py - Comprueba el descifrado que hizo el procesador.

CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4

Es la mitad de verificacion de "make solo-descifrar":

    contenedor cifrado (.bin, de make solo-cifrar)
      -> load_file.py --cifrado   imagen de DMEM
      -> tb_descifrado.sv         el procesador descifra  ($writememh)
      -> extract_data.py          el archivo descifrado
      -> este script              lo compara contra el modelo de referencia

El modelo es el de probar_flujo.py, escrito solo desde la formula del
enunciado. Descifra el mismo contenedor por su cuenta y el resultado tiene que
coincidir byte por byte con lo que saco el hardware. Si ademas se da el archivo
original, tambien se compara contra el.

    probar_descifrado.py cifrado.bin volcado.hex salida.bin [original]
                         [--llave K]

"""

import argparse
import contextlib
import io
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_data                                   # noqa: E402
from formato_buffer import de_contenedor, desempaquetar  # noqa: E402
from llave import LLAVE_POR_OMISION, formato, leer_llave  # noqa: E402
from probar_flujo import descifrar_bloque             # noqa: E402

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


def main(ruta_cifrado, ruta_volcado, ruta_salida, ruta_original=None,
         llave=LLAVE_POR_OMISION):
    print("=== probar_descifrado: el descifrado del hardware contra el modelo ===")
    print("")
    print(f"  llave  {formato(llave)}")

    for ruta in (ruta_cifrado, ruta_volcado):
        if not Path(ruta).is_file():
            print(f"  FALLA  no se encontro {ruta}")
            return 1

    # --- lo que descifro el procesador --------------------------------------
    with contextlib.redirect_stdout(io.StringIO()):
        r = extract_data.main([ruta_volcado, "-o", ruta_salida])
    check("extract_data recupera el archivo del volcado", r == 0,
          f"devolvio {r}")
    if r != 0:
        return 1
    hardware = Path(ruta_salida).read_bytes()

    # --- lo que descifra el modelo con el mismo contenedor ------------------
    pal = de_contenedor(Path(ruta_cifrado).read_bytes())
    claro = []
    for b in range(pal[1]):
        i = 2 + 2 * b
        L, R = descifrar_bloque(pal[i], pal[i + 1], llave)
        claro += [L, R]
    modelo = desempaquetar(pal[:2] + claro)

    check("el archivo tiene el tamano que dice la cabecera",
          len(hardware) == pal[0], f"{len(hardware)} contra {pal[0]}")
    check("y coincide byte por byte con el modelo de referencia",
          hardware == modelo,
          f"hardware {hardware[:64]!r}\nmodelo   {modelo[:64]!r}")

    if ruta_original is not None:
        original = Path(ruta_original).read_bytes()
        check("y es identico al archivo original",
              hardware == original,
              f"original   {original[:64]!r}\ndescifrado {hardware[:64]!r}")

    print("")
    print(f"  descifrado  {hardware[:64]!r}")
    if len(hardware) > 64:
        print(f"              (primeros 64 de {len(hardware)} bytes)")
    print(f"  escrito en  {ruta_salida}")
    print("")
    print("---")
    print(f"casos: {casos}   fallidos: {fallidos}")
    if fallidos:
        print("RESULTADO: FALLA")
        return 1
    print("RESULTADO: OK")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser(
        description="Compara el descifrado del hardware con el modelo")
    ap.add_argument("cifrado")
    ap.add_argument("volcado")
    ap.add_argument("salida")
    ap.add_argument("original", nargs="?", default=None)
    ap.add_argument("--llave", default=None,
                    help="la llave con que descifro el hardware")
    args = ap.parse_args()
    try:
        clave = leer_llave(args.llave) if args.llave else LLAVE_POR_OMISION
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)
    sys.exit(main(args.cifrado, args.volcado, args.salida, args.original,
                  clave))
