#!/usr/bin/env python3
"""
probar_archivos.py - Pruebas de load_file.py y extract_data.py.

CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4

Las dos herramientas son inversas una de la otra, y eso hace que la prueba
obvia, cargar y volver a extraer, sea mas debil de lo que parece: un error en el
formato que fuera simetrico entre las dos pasaria igual. Por eso aqui hay dos
clases de caso.

Las de IDA Y VUELTA comprueban que el archivo recuperado sea identico al
original, con los tamanos que rompen las cosas: vacio, un byte, exactamente un
bloque, un byte mas que un bloque, y sobre todo un archivo que TERMINA EN CERO,
que es el que distingue un formato con cabecera de uno sin ella.

Las de DISPOSICION fijan el formato contra palabras escritas a mano, calculadas
sin usar las herramientas. Si las dos se equivocaran igual, estas las agarran.

    python3 probar_archivos.py
"""

import contextlib
import io
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import extract_data                                        # noqa: E402
import load_file                                           # noqa: E402
from formato_buffer import (desempaquetar, empaquetar,      # noqa: E402
                            escribir_hex, leer_hex)

casos = 0
fallidos = 0
tmp = Path(tempfile.mkdtemp(prefix="cerbero_arch_"))


@contextlib.contextmanager
def callado():
    """Silencia lo que imprimen las herramientas, para que la salida se lea."""
    with contextlib.redirect_stdout(io.StringIO()):
        yield


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


def ida_y_vuelta(nombre, datos, base=0x4000, palabras=16384):
    """Carga los bytes, los extrae y exige que vuelvan identicos."""
    entrada = tmp / "entrada.bin"
    imagen = tmp / "imagen.hex"
    salida = tmp / "salida.bin"
    entrada.write_bytes(datos)

    with callado():
        r = load_file.main([str(entrada), "-o", str(imagen),
                            "--base", hex(base), "--palabras", str(palabras)])
    if r != 0:
        check(nombre, False, f"load_file devolvio {r}")
        return
    with callado():
        r = extract_data.main([str(imagen), "-o", str(salida),
                               "--base", hex(base)])
    if r != 0:
        check(nombre, False, f"extract_data devolvio {r}")
        return
    recuperado = salida.read_bytes()
    check(f"{nombre} ({len(datos)} byte(s))", recuperado == datos,
          f"original   {datos!r}\nrecuperado {recuperado!r}")


print("=== probar_archivos: load_file y extract_data ===")
print("")
print("[1] ida y vuelta, con los tamanos que rompen las cosas")

ida_y_vuelta("archivo vacio", b"")
ida_y_vuelta("un solo byte", b"A")
ida_y_vuelta("siete bytes, uno menos que un bloque", b"1234567")
ida_y_vuelta("ocho bytes, exactamente un bloque", b"12345678")
ida_y_vuelta("nueve bytes, uno mas que un bloque", b"123456789")

# El caso que justifica la cabecera: sin la cantidad de bytes, estos ceros del
# final serian indistinguibles del relleno y el archivo saldria truncado
ida_y_vuelta("un archivo que termina en cero", b"\x01\x00")
ida_y_vuelta("un archivo de puros ceros", bytes(5))
ida_y_vuelta("un archivo de puros 0xFF", b"\xFF" * 9)

# Binario arbitrario, incluido todo el rango de bytes
ida_y_vuelta("los 256 valores de byte", bytes(range(256)))

# Algo mas grande, para que cruce varias palabras y bloques
ida_y_vuelta("texto de 1000 bytes", (b"CERBERO-1 " * 100))

print("")
print("[2] la disposicion, contra palabras escritas a mano")

# b"ABCD": 4 bytes, hacen falta 4 de relleno, 1 bloque.
# little-endian: 'A' = 0x41 va en la parte baja de la palabra.
#   palabra 0  cantidad de bytes   = 0x00000004
#   palabra 1  cantidad de bloques = 0x00000001
#   palabra 2  "ABCD"              = 0x44434241
#   palabra 3  relleno             = 0x00000000
esperado = [0x00000004, 0x00000001, 0x44434241, 0x00000000]
check("empaquetar b'ABCD' da la cabecera y el dato little-endian",
      empaquetar(b"ABCD") == esperado,
      f"obtenido {[f'{p:08X}' for p in empaquetar(b'ABCD')]}\n"
      f"esperado {[f'{p:08X}' for p in esperado]}")

# Nueve bytes: 2 bloques, 7 de relleno
p = empaquetar(bytes(range(1, 10)))
check("nueve bytes dan dos bloques", p[1] == 2, p[1])
check("y la cabecera guarda los nueve bytes", p[0] == 9, p[0])
check("y el buffer ocupa 2 + 4 palabras", len(p) == 6, len(p))

# El primer byte del archivo va en los bits [7:0] de su palabra
p = empaquetar(b"\x11\x22\x33\x44")
check("el primer byte del archivo va en los bits bajos",
      p[2] == 0x44332211, f"{p[2]:08X}")

# desempaquetar es la inversa exacta
check("desempaquetar deshace empaquetar",
      desempaquetar(empaquetar(b"hola mundo")) == b"hola mundo")

print("")
print("[3] el archivo .hex")

ruta = tmp / "x.hex"
escribir_hex(ruta, [0xDEADBEEF, 1, 0], total=5)
lineas = ruta.read_text().split()
check("escribe ocho digitos por linea y en mayuscula",
      lineas[:3] == ["DEADBEEF", "00000001", "00000000"], lineas[:3])
check("y rellena hasta el total pedido", len(lineas) == 5, len(lineas))
check("leer_hex devuelve lo que escribio escribir_hex",
      leer_hex(ruta) == [0xDEADBEEF, 1, 0, 0, 0], leer_hex(ruta))

# $writememh usa marcas @direccion cuando el volcado tiene huecos
ruta = tmp / "y.hex"
ruta.write_text("// volcado\n@00000002\nAAAAAAAA\nBBBBBBBB\n")
check("leer_hex entiende las marcas @direccion de $writememh",
      leer_hex(ruta) == [0, 0, 0xAAAAAAAA, 0xBBBBBBBB], leer_hex(ruta))

ruta = tmp / "z.hex"
ruta.write_text("11111111 22222222   // dos en una linea\n\n33333333\n")
check("leer_hex acepta varias palabras por linea y comentarios",
      leer_hex(ruta) == [0x11111111, 0x22222222, 0x33333333], leer_hex(ruta))

print("")
print("[4] lo que debe fallar")


def falla(nombre, fn, fragmento):
    global casos, fallidos
    casos += 1
    try:
        fn()
    except Exception as e:                       # noqa: BLE001
        if fragmento.lower() in str(e).lower():
            print(f"  ok     {nombre}")
            return
        fallidos += 1
        print(f"  FALLA  {nombre}")
        print(f"           fallo por otro motivo: {e}")
        return
    fallidos += 1
    print(f"  FALLA  {nombre}")
    print("           no fallo y debia fallar")


falla("un volcado sin cabecera completa",
      lambda: desempaquetar([5]), "no alcanza")

falla("una cabecera que pide mas palabras de las que hay",
      lambda: desempaquetar([8, 100, 0, 0]), "y el volcado solo trae")

falla("una cabecera incoherente: mas bytes que bloques",
      lambda: desempaquetar([99, 1, 0, 0]), "incoherente")

falla("una cabecera incoherente: menos bytes que bloques",
      lambda: desempaquetar([1, 2, 0, 0, 0, 0]), "incoherente")

def _hex_mal():
    r = tmp / "mal.hex"
    r.write_text("11111111\nnoesunnumero\n")
    return r


falla("hexadecimal mal formado",
      lambda: leer_hex(_hex_mal()), "no es hexadecimal")


# Una base desalineada se rechaza en la linea de comandos
entrada = tmp / "e.bin"
entrada.write_bytes(b"hola")
with callado():
    r = load_file.main([str(entrada), "-o", str(tmp / "s.hex"),
                        "--base", "0x4002"])
check("load_file rechaza una base desalineada", r == 2, r)

# Un buffer que no cabe en el limite de palabras
with callado():
    r = load_file.main([str(entrada), "-o", str(tmp / "s.hex"),
                        "--base", "0x4000", "--palabras", "16"])
check("load_file rechaza un buffer que no cabe", r == 1, r)

# Una base mas alla del final del volcado
imagen = tmp / "corta.hex"
escribir_hex(imagen, [1, 2, 3])
with callado():
    r = extract_data.main([str(imagen), "-o", str(tmp / "s.bin"),
                           "--base", "0x4000"])
check("extract_data rechaza una base fuera del volcado", r == 1, r)

print("")
print("[5] el modo crudo")

# Con --crudo no se mira la cabecera: sirve para ver un volcado a mano
imagen = tmp / "crudo.hex"
escribir_hex(imagen, [0x44332211, 0x88776655])
salida = tmp / "crudo.bin"
with callado():
    r = extract_data.main([str(imagen), "-o", str(salida), "--base", "0",
                           "--crudo"])
check("extract_data --crudo no mira la cabecera", r == 0, r)
check("y saca las palabras tal cual, little-endian",
      salida.read_bytes() == bytes([0x11, 0x22, 0x33, 0x44,
                                    0x55, 0x66, 0x77, 0x88]),
      salida.read_bytes())

print("---")
print(f"casos: {casos}   fallidos: {fallidos}")
if fallidos:
    print("RESULTADO: FALLA")
    sys.exit(1)
print("RESULTADO: OK")
