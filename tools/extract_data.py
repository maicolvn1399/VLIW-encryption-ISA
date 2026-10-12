#!/usr/bin/env python3
"""
extract_data.py - Recupera un archivo del volcado de la memoria de datos.

CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4

Es la inversa de load_file.py: toma el volcado de dmem que produce $writememh
despues de una corrida y vuelve a armar el archivo.

    extract_data.py volcado.hex -o cifrado.bin
    extract_data.py volcado.hex -o salida.txt --base 0x4000
    extract_data.py volcado.hex -o cifrado.bin --cifrado

La cantidad de bytes del archivo original sale de la cabecera del buffer, asi
que el resultado tiene exactamente el tamano que tenia la entrada: el relleno
que hizo falta para completar el ultimo bloque de 64 bits no aparece. Sin esa
cabecera, un archivo que terminara en 0x00 saldria truncado y uno que no
ocupara un multiplo de 8 saldria con basura al final.

Un volcado CIFRADO no se recorta: con --cifrado sale el buffer entero, que es
lo que load_file.py --cifrado necesita para volver a cargarlo y descifrarlo.

El formato del buffer esta en formato_buffer.py, el mismo modulo que usa
load_file.py para escribirlo.
"""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from formato_buffer import (BASE_POR_OMISION, a_contenedor,    # noqa: E402
                            desempaquetar, leer_hex)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Recupera un archivo del volcado de DMEM de CERBERO-1")
    ap.add_argument("volcado", help="archivo .hex que volco la simulacion")
    ap.add_argument("-o", "--salida", required=True,
                    help="archivo a escribir")
    ap.add_argument("--base", default=hex(BASE_POR_OMISION),
                    help="direccion de byte donde arranca el buffer "
                         f"(por omision {BASE_POR_OMISION:#x})")
    modo = ap.add_mutually_exclusive_group()
    modo.add_argument("--cifrado", action="store_true",
                      help="escribe el buffer entero, cabecera y bloques "
                           "completos, para un volcado cifrado que despues se "
                           "va a descifrar")
    modo.add_argument("--crudo", action="store_true",
                      help="ignora la cabecera y extrae todas las palabras "
                           "tal cual, para mirar un volcado a mano")
    args = ap.parse_args(argv)

    base = int(args.base, 0)
    if base % 4:
        print(f"error: la base {base:#x} no esta alineada a palabra",
              file=sys.stderr)
        return 2

    try:
        palabras = leer_hex(args.volcado)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    inicio = base // 4
    if len(palabras) <= inicio:
        print(f"error: el volcado trae {len(palabras)} palabras y el buffer "
              f"empieza en la {inicio}. Puede ser una base equivocada",
              file=sys.stderr)
        return 1

    buffer_ = palabras[inicio:]

    if args.crudo:
        datos = bytearray()
        for p in buffer_:
            datos += (p & 0xFFFFFFFF).to_bytes(4, "little")
        datos = bytes(datos)
        cabecera = "(ignorada)"
    else:
        convertir = a_contenedor if args.cifrado else desempaquetar
        try:
            datos = convertir(buffer_)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 1
        cabecera = f"{buffer_[0]} bytes en {buffer_[1]} bloque(s)"

    Path(args.salida).write_bytes(datos)

    print(f"{args.volcado}: {len(palabras)} palabras")
    print(f"  base      {base:#010x}")
    print(f"  cabecera  {cabecera}")
    print(f"{args.salida}: {len(datos)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
