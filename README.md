# CERBERO-1

Procesador VLIW con ISA propia para aceleración de cifrado por bloques Feistel4.

**CE-4301 Arquitectura de Computadores I — Proyecto Grupal I — Grupo #4**
Escuela de Ingeniería en Computadores, Instituto Tecnológico de Costa Rica.

| | |
|---|---|
| Profesor | Dr.-Ing. Jeferson González Gómez |
| Integrantes | Araya Porras Luis Diego (2021086423) · Retana Murillo Braulio (2021050678) · Valverde Navarro Michael (2020044189) · Piedra Montero Joseph (2023047830) · Muñoz Alvarado Adrián (2023207992) |
| Especificación | [`docs/isa.md`](docs/isa.md) |

---

## Qué es

Un bundle de 128 bits con cinco slots de ancho desigual, siete unidades
funcionales y calendarización estática: el hardware no detecta riesgos, no
reenvía resultados y no se detiene nunca.

```
 127                96 95                 64 63                 32 31        16 15         0
+---------------------+---------------------+---------------------+------------+-----------+
|   S0: ALU-0 (32)    |   S1: ALU-1 (32)    |   S2: LSU (32)      | S3: CRP(16)| S4:BRU(16)|
+---------------------+---------------------+---------------------+------------+-----------+
```

| Slot | Unidad | Módulo |
|---|---|---|
| S0 | ALU-0, única que escribe banderas | `alu.sv` (instancia 0) |
| S1 | ALU-1 | `alu.sv` (instancia 1) |
| S2 | Acceso a memoria, con postincremento | `lsu.sv` |
| S3 | Ronda Feistel4 | `crypto_unit.sv` |
| S3 | Bóveda de llaves y autenticación | `key_vault.sv` |
| S3 | ALU corta, destructiva | `short_alu.sv` |
| S4 | Saltos y enlace | `bru.sv` |
| — | Banco de registros, 9 lecturas y 7 escrituras | `regfile.sv` |
| — | Memoria de instrucciones, 2048 bundles de 128 bits | `imem.sv` |
| — | Memoria de datos, 64 KB con escritura por carril | `dmem.sv` |
| — | Etapa ID: rebanado del bundle y enrutado de lecturas | `dispatch.sv` |
| — | PSW y resolución de fallas | `psw_fault_unit.sv` |
| — | Etapa IF: contador de programa, salto y detención | `fetch.sv` |
| — | Frontera IF/ID: el PC que acompaña al bundle | `reg_if_id.sv` |
| — | Frontera ID/EX: slots y los 9 valores leídos | `reg_id_ex.sv` |
| — | Frontera EX/MEM: los 7 puertos de escritura y las 5 fallas | `reg_ex_mem.sv` |
| — | Extracción del carril de una carga, en MEM | `load_align.sv` |
| — | **El procesador completo** | `top.sv` |

### Herramientas

| | |
|---|---|
| Ensamblador propio | `tools/cerbero_asm.py` |
| Su arnés de pruebas, 71 casos | `tools/probar_asm.py` |
| Archivo a imagen de memoria | `tools/load_file.py` |
| Volcado de memoria a archivo | `tools/extract_data.py` |
| Formato del buffer, compartido por las dos | `tools/formato_buffer.py` |
| Su arnés de pruebas, 53 casos | `tools/probar_archivos.py` |
| La llave desde la línea de comandos, y sus 19 casos | `tools/llave.py`, `tools/probar_llave.py` |
| El flujo completo contra un modelo de referencia, 7 casos | `tools/probar_flujo.py` |
| Ejecutable NOVA a imágenes de memoria (puente con CE1108) | `tools/novac_image.py` |
| Programa de cifrado Feistel4 de un bloque | `tools/programas/feistel.s` |
| **Cifra un archivo completo** | `tools/programas/cifrar_archivo.s` |
| **Lo descifra** | `tools/programas/descifrar_archivo.s` |
| Prólogo compartido: credencial, llave y cabecera | `tools/programas/cargar_llave.s` |
| Prólogo compartido: sesión de bóveda e instalación | `tools/programas/vault_sesion.s` |
| Programas de demostración, comprobados en `make` | `tools/programas/fibonacci.s`, `estadisticas.s`, `sesion_sin_logout.s` |
| Lazo de 100 000 vueltas, a mano | `tools/programas/lazo_estres.s` |
| Subrutina de división de 32 bits | `tools/programas/div32.s` |
| Programa que usa el 100% del conjunto | `tools/programas/cobertura.s` |

Las tres unidades de S3 se excluyen entre sí: el opcode del slot decide cuál
actúa. O el programa cifra, o usa la ALU corta.

---

## Requisitos

| Herramienta | Versión | Para qué |
|---|---|---|
| [Icarus Verilog](https://steveicarus.github.io/iverilog/) | 11 o superior | Simulación. La 10 no soporta `always_comb` ni `logic` |
| [Verilator](https://verilator.org/) | 5.x | Análisis estático. Opcional pero recomendado |
| [GTKWave](https://gtkwave.sourceforge.net/) | cualquiera | Ver formas de onda. Opcional |
| `make` | cualquiera | |

```bash
# Ubuntu, Debian y WSL
sudo apt install iverilog verilator gtkwave

# macOS
brew install icarus-verilog verilator gtkwave
```

---

## Cómo se ejecuta

Todo se corre desde `src/build`:

```bash
cd src/build

make            # pruebas de las herramientas, los veintiocho testbenches y el flujo
make lint       # análisis estático de las diecisiete unidades
make top        # corre los siete programas sobre el procesador completo
make archivo    # cifra y descifra un archivo completo sobre el RTL
make flujo      # y lo descifra con un modelo de referencia en Python
make cifrar ARCHIVO=ruta  # lo mismo, sobre un archivo cualquiera
make solo-cifrar ARCHIVO=ruta  # solo el cifrado, verificado contra el modelo
make solo-descifrar ORIGINAL=ruta  # descifra el .bin que dejo solo-cifrar
make credencial # con la credencial equivocada no se cifra nada
make ejemplos   # fibonacci, estadisticas y sesion_sin_logout, comprobados
make sum        # el programa que compiló novac desde NOVA, en el RTL
make correr PROG=fibonacci.s   # corre un programa y MUESTRA el resultado
make asm        # ensambla feistel.s y corre el binario en el RTL
make herramientas  # solo las pruebas de las herramientas en Python
make div        # corre la subrutina de división en el procesador
make cobertura  # comprueba que se usa el 100% del conjunto
make lsu        # solo el testbench de la LSU
make wave-lsu   # abre su forma de onda en GTKWave
make list       # lista las unidades disponibles
make clean      # borra los artefactos, incluidos los .hex ensamblados
```

Un testbench que encuentra un error llama a `$fatal`, lo que le da a `vvp` un
código de salida distinto de cero y detiene el `make`. Que `make` termine bien
significa que todas las unidades pasaron, no sólo que corrieron.

Salida esperada:

```
---- alu ----
casos: 334   fallidos: 0
RESULTADO: OK
...
==============================================================
 Todas las unidades pasaron
==============================================================
```

`tb_imem` y `tb_dmem` imprimen un aviso de Icarus, `Not enough words in the
file for the requested range`. **Esos dos son esperados y son los únicos dos que
debe haber**: los archivos de ejemplo traen menos palabras que la memoria, y
comprobar que las posiciones restantes quedan en cero es justamente uno de los
casos. No quedan indefinidas porque el módulo barre el arreglo a cero antes de
leer el archivo.

El aviso contrario, `Too many words`, nunca es intencional: significa que el
relleno con que el ensamblador generó el `.hex` no coincide con el tamaño de la
memoria del testbench que lo carga. El makefile declara el tamaño de cada
programa por separado (`BUNDLES_<programa>`) para que los dos números cuadren.

`make clean` borra también los `.hex` que produce el ensamblador, y eso tampoco
es prolijidad: las marcas de tiempo del sistema de archivos tienen granularidad
de un segundo, así que un `.s` editado y su `.hex` ya existente pueden caer en
el mismo segundo y `make` se salta el reensamblado. El resultado es una
simulación que corre el binario anterior y falla sin motivo aparente. Ante
cualquier resultado que no cuadre, `make clean && make`.

### Cifrar un archivo con una llave dada

La llave se da en la línea de comandos. No hace falta editar el ensamblador:

```bash
cd src/build
make solo-cifrar ARCHIVO=../../archivo.txt LLAVE=A1B2C3D4,11223344,55667788,99AABBCC
cmp criptograma.bin esperado.bin && echo COINCIDE
```

`LLAVE` funciona igual en `cifrar`, `solo-cifrar` y `solo-descifrar`.
`tools/llave.py` genera en `src/build/llave_gen/` una copia de los programas de
archivo con esa llave, y el testbench y el modelo de referencia reciben la
misma. Sin `LLAVE` se usa la de `cargar_llave.s`. La salida imprime cómo quedó
cada `key[i]` y los primeros bytes del criptograma.

El criptograma queda en `src/build/criptograma.bin`, **sin cabecera**: es el
archivo que se compara contra un resultado calculado por fuera del proyecto.
`cifrado_libre.bin` es el mismo criptograma con la cabecera de 8 bytes que
necesita `solo-descifrar`.

Para descifrar:

```bash
make solo-descifrar CIFRADO=cifrado_libre.bin LLAVE=A1B2C3D4,11223344,55667788,99AABBCC
make solo-descifrar CIFRADO_CRUDO=externo.bin LLAVE=A1B2C3D4,11223344,55667788,99AABBCC
```

La primera forma es para lo que cifró este proyecto: la cabecera trae el tamaño
original y el resultado sale recortado a ese tamaño. La segunda es para un
criptograma **cifrado fuera del proyecto**, sin cabecera: se carga como bloques
puros y, como el tamaño original no viaja en ningún lado, el resultado trae los
ceros de relleno del último bloque. En las dos, el resultado queda en
`src/build/descifrado_libre.bin`, y con `ORIGINAL=ruta` también se compara
contra el archivo original.

**Convenciones.** El enunciado fija la función de ronda pero no cómo se arma un
archivo en bloques. Si un resultado externo no coincide, la diferencia está en
alguna de estas filas:

| | Convención de este proyecto |
| :--- | :--- |
| Llave | La `key[4]` de la Fig. 1 del enunciado: la ronda `i` usa `key[i]`. Se escribe como cuatro palabras separadas por coma, con `key[0]` primero, o como 32 dígitos hexadecimales, donde los **primeros** ocho son `key[0]` |
| Bloques | Little-endian. `L` son los bytes 0 a 3 del bloque y `R` los bytes 4 a 7, cada uno leído como entero de 32 bits con el primer byte en la parte baja. Es lo que hace `memcpy` en un programa en C en una PC |
| Relleno | Ceros hasta completar un múltiplo de 8 bytes. Sólo afecta al último bloque |
| Modo | Cada bloque se cifra por separado. Dos bloques iguales del archivo dan el mismo criptograma |
| Salida | Los bloques completos: el criptograma mide el tamaño del archivo redondeado hacia arriba a múltiplo de 8 |
| Tamaño máximo | 49 144 bytes, lo que cabe entre `0x4008` y el final de la memoria de datos |

Con estas convenciones, el criptograma del procesador coincide byte por byte con
el de la implementación en C de la Fig. 1 del enunciado. Se comprobó con un
archivo binario de 20 003 bytes y la llave `A1B2C3D4 11223344 55667788
99AABBCC`, compilando ese código C sin cambios. En el otro sentido, el
procesador descifra con `CIFRADO_CRUDO` el criptograma que produce ese mismo
código C y recupera el archivo más su relleno.

**La interfaz del enunciado (5.4.3) también funciona.** `load_file.py` acepta
`--input`, `--output` y `--address`, y `extract_data.py` acepta `--memory`,
`--address`, `--size` y `--output`, además de las opciones de siempre. Con
`--size`, `extract_data.py` saca exactamente esa cantidad de bytes desde la
dirección sin mirar la cabecera; como el buffer empieza con 8 bytes de
cabecera, los datos de un archivo cargado en `0x4000` empiezan en `0x4008`.

---

## Cobertura actual

| Unidad | Casos | Qué verifica |
|---|---:|---|
| `alu` | 334 | Los 32 opcodes, extensión de signo, enmascarado del desplazamiento, las cuatro banderas, los ocho códigos de condición de `SETcc`, las dos fuentes de `ILLOP` |
| `bru` | 295 | Las ocho condiciones, destino relativo e indirecto, enlace, detención, bits reservados del tipo J |
| `crypto_unit` | 93 | Cifrado y descifrado ronda a ronda, decodificación del par, aislamiento de la subllave sin permiso |
| `key_vault` | 100 | Protocolo completo, `KVALID`, auto-logout, las tres causas de falla, fuga de subllave |
| `lsu` | 245 | Los cuatro carriles en los dos sentidos, postincremento, `ILLOP`, `MISALIGN`, `RANGE` y su prioridad |
| `short_alu` | 92 | Las ocho suboperaciones en las dos formas, aritmética envolvente, combinaciones reservadas |
| `regfile` | 90 | Los 7 puertos de escritura y los 9 de lectura, prioridad ante colisión, y la lectura del negedge sobre la escritura del posedge |
| `imem` | 23 | Lectura síncrona, escalado del índice, bundle nulo fuera de rango, carga por `$readmemh` |
| `dmem` | 38 | Las ocho máscaras de byte con dato replicado, los dos flancos por separado, little-endian, fuera de rango sin envolver |
| `dispatch` | 34 | Los 128 bits del bundle caen en su slot y su posición, enrutado de los 9 puertos de lectura, la excepción de `MOVH`, las 8 codificaciones de par |
| `psw_fault_unit` | 41 | Las 16 combinaciones de banderas, las 6 causas en los 5 slots, los 10 pares de prioridad, `EXC` pegajoso, `WCONF` puerto por puerto |
| `crypto_vault` | 90 | **Integración**: bóveda y unidad de ronda juntas, contra el modelo de referencia |
| `latency` | 3 | **Integración**: mide la latencia expuesta contra el modelo de pipeline y la compara con los 3 bundles del ISA |
| `reg_if_id` | 13 | Retraso de un ciclo exacto medido sobre una secuencia, independencia de `valid` y `pc` |
| `reg_id_ex` | 18 | Aislamiento de los 12 campos con huella de bits, los 9 puertos de lectura uno por uno |
| `reg_ex_mem` | 10 | Aislamiento de los 10 campos, los 7 puertos de escritura y las 5 causas elemento por elemento |
| `wconf` | 12 | **Integración**: 4000 vectores aleatorios comparando los dos detectores de conflicto de escritura, el del banco y el del PSW |
| `fetch` | 41 | Avance de 16 en 16, salto tomado, destino desalineado forzado a múltiplo de 16, `HALT` congela el PC y apaga `valid`, el reset lo libera |
| `pipeline` | 6 | **Integración**: mide la latencia expuesta sobre la cadena real de registros más el banco, y que el PC acompañe al bundle en ID y en EX |
| `fetch_flow` | 23 | **Integración**: `fetch`, `imem`, `reg_if_id` y `bru` sobre un programa de saltos; un delay slot exacto por salto, el de `HALT` se ejecuta, y el caso medido de un salto dentro de un delay slot |
| `top` | 45 | **El procesador completo** corriendo siete programas: aritmética con la latencia de 3 bundles, memoria en los tres tamaños con y sin signo, llamada y retorno, **cifrado Feistel4 completo** contra valores calculados fuera del simulador, la misma rutina denegada fuera de la región segura, `ILLOP` y `MISALIGN`, y que nada se ejecute después de `HALT` |
| `asm` | 12 | **La cadena completa**: el binario que produce `cerbero_asm.py` desde `feistel.s`, corriendo en el RTL, cifrando bien y con el cierre automático de sesión al salir de la región segura |
| `div` | 15 | **La subrutina de división** corriendo en el procesador: seis pares, con divisor cero y con el bit 31 encendido |
| `archivo` | 29 | **La cadena completa sobre un archivo real**: dos procesadores, uno cifra y el otro descifra lo que el primero dejó en memoria; criptograma contra valores calculados fuera del simulador, el archivo recuperado byte por byte, la cabecera intacta, un barrido de los 64 KB de las dos memorias buscando subllaves filtradas, y que ni la llave ni la credencial queden en el banco de registros |
| `cifrado` | 13 | **Un archivo cualquiera**: `make cifrar ARCHIVO=...` sobre un archivo y una llave dados en la línea de comandos, con `probar_flujo.py` de oráculo en vez de valores fijos |
| `credencial` | 7 | **La credencial equivocada**: el `LOGIN` no coincide, `AUTHFAIL` se enciende, las rondas se anulan con `DENIED` y el archivo queda sin cifrar |
| `ejemplos` | 23 | **Los programas de demostración, comprobados**: `fibonacci.s` contra la sucesión que el testbench calcula por su cuenta, los seis resultados de `estadisticas.s` (que llama a `__div32` con enlace y retorno) y las tres fotos del PSW de `sesion_sin_logout.s` |
| `sum` | 3 | **El compilador de CE1108**: el programa que produjo `novac` desde NOVA, corriendo en este procesador. Es el punto de contacto entre los dos cursos |
| **Total** | **1748** | |

A eso se suman **151 casos** de las herramientas en Python, que `make` corre antes y después de los testbenches:

| | |
|---|---|
| `probar_asm.py` | 71 casos: la codificación contra valores calculados a mano, las ocho validaciones que el ISA 10.3 manda rechazar, los rangos de cada operando, qué es advertencia y qué es error, y que los 63 mnemónicos del conjunto estén cubiertos |
| `probar_archivos.py` | 54 casos: ida y vuelta con los tamaños que rompen las cosas (vacío, un byte, exactamente un bloque, y sobre todo un archivo que **termina en cero**), la disposición del buffer contra palabras escritas a mano, lo que debe fallar, el contenedor del archivo cifrado, la interfaz del enunciado y el criptograma crudo |
| `probar_llave.py` | 19 casos: el orden de `key[0..3]` en las dos formas de escribir la llave, contra valores escritos a mano, y que el programa generado la arme en `r5` a `r8` |
| `probar_flujo.py` | 7 casos: toma el volcado de `$writememh` que dejó `tb_archivo` o `tb_cifrado`, lo convierte en contenedor cifrado con `extract_data.py --cifrado` y lo descifra con un **modelo de referencia escrito sólo desde la fórmula del enunciado**, que no comparte una línea con el RTL ni con el ensamblador |

El último es el que cierra el argumento. `tb_archivo` comprueba que el hardware
descifra lo que cifró, pero eso se cumpliría igual si `F4E` y `F4D` estuvieran
mal de forma inversa. Si el criptograma que produjo el procesador se deshace con
un modelo independiente, entonces el procesador implementa Feistel4 y no otra
cosa parecida.

### Autoprueba del arnés

Un testbench que siempre pasa no prueba nada. Los veinticuatro aceptan `-DFORCE_FAIL`,
que inyecta un caso deliberadamente incorrecto para comprobar que el arnés sabe
reportar una falla:

```bash
iverilog -g2012 -Wall -I ../cpu -DFORCE_FAIL -s tb_lsu -o /tmp/f.vvp \
         ../cpu/lsu.sv ../tb/tb_lsu.sv
vvp -n /tmp/f.vvp ; echo "codigo de salida: $?"     # debe ser distinto de 0
```

---

## Estructura

```
cerbero/
├── docs/
│   └── isa.md                   Especificación del ISA (contrato con CE1108)
├── tools/
│   ├── cerbero_asm.py           Ensamblador propio
│   ├── probar_asm.py            Sus pruebas, 71 casos
│   ├── load_file.py             Archivo a imagen de DMEM
│   ├── extract_data.py          Volcado de DMEM a archivo
│   ├── formato_buffer.py        El formato que comparten las dos
│   ├── probar_archivos.py       Sus pruebas, 53 casos
│   ├── llave.py                 La llave desde la línea de comandos
│   ├── probar_llave.py          Sus pruebas, 19 casos
│   ├── probar_flujo.py          El flujo completo contra el modelo de referencia
│   ├── probar_descifrado.py     El descifrado del hardware contra el modelo
│   └── programas/
│       ├── feistel.s            Cifrado de un bloque con sesión de bóveda
│       ├── cifrar_archivo.s     Cifra un archivo completo, bloque por bloque
│       ├── descifrar_archivo.s  Y lo devuelve a claro
│       ├── cargar_llave.s       Prólogo incluido por los dos: constantes
│       ├── vault_sesion.s       Prólogo incluido por los dos: sesión y llave
│       ├── archivo_prueba.txt   El archivo de 23 bytes que se cifra
│       ├── fibonacci.s          F(0) a F(46), aritmética encadenada
│       ├── estadisticas.s       Suma, máximo, mínimo y promedio con __div32
│       ├── sesion_sin_logout.s  El cierre automático de sesión, visto por el programa
│       ├── lazo_estres.s        100 000 vueltas con los cinco slots ocupados
│       ├── div32.s              Subrutina de división sin signo
│       ├── div32_prueba.s       Seis pares para probarla
│       └── cobertura.s          Usa el 100% del conjunto de instrucciones
└── src/
    ├── build/
    │   └── makefile             Punto de entrada de simulación y lint
    ├── cpu/
    │   ├── cerbero_defs.svh     Opcodes, campos, condiciones, causas y puertos
    │   ├── regfile.sv           Banco de registros
    │   ├── alu.sv               S0 y S1
    │   ├── lsu.sv               S2
    │   ├── crypto_unit.sv       S3, ronda Feistel4
    │   ├── key_vault.sv         S3, bóveda
    │   ├── short_alu.sv         S3, ALU corta
    │   ├── bru.sv               S4
    │   ├── imem.sv              Memoria de instrucciones
    │   ├── dmem.sv              Memoria de datos
    │   ├── dispatch.sv          Etapa ID
    │   ├── psw_fault_unit.sv    PSW y unidad de fallas
    │   ├── fetch.sv             Etapa IF, contador de programa
    │   ├── reg_if_id.sv         Frontera IF/ID
    │   ├── reg_id_ex.sv         Frontera ID/EX
    │   ├── reg_ex_mem.sv        Frontera EX/MEM
    │   ├── load_align.sv        Extracción del carril, usada en MEM
    │   └── top.sv               El procesador completo
    └── tb/
        ├── key_vault_model.sv   Modelo de bóveda para probar crypto_unit sola
        ├── tb_<unidad>.sv       Un testbench por unidad
        ├── tb_crypto_vault.sv   Cosimulación de bóveda y ronda
        ├── tb_latency.sv        Medición de la latencia expuesta
        ├── tb_wconf.sv          Cosimulación de los dos detectores de WCONF
        ├── tb_pipeline.sv       Latencia expuesta sobre la cadena de registros
        ├── tb_fetch_flow.sv     Búsqueda, delay slot y HALT con la BRU real
        ├── tb_top.sv            Siete programas sobre el procesador completo
        ├── tb_asm.sv            El binario del ensamblador sobre el RTL
        ├── tb_div.sv            La subrutina de división sobre el RTL
        ├── tb_archivo.sv        Cifrado y descifrado de un archivo completo
        ├── tb_cifrado.sv        Lo mismo sobre un archivo y una llave cualesquiera
        ├── tb_credencial.sv     Con la credencial equivocada no se cifra nada
        ├── tb_descifrado.sv     Descifra un .bin de disco (manual)
        ├── tb_ejemplos.sv       Los programas de demostración, comprobados
        ├── tb_programa.sv       Ejecutor con traza del pipeline (no verifica)
        ├── tb_cifrado.sv        Lo mismo sobre un archivo cualquiera
        ├── tb_credencial.sv     Con la credencial equivocada no se cifra nada
        ├── tb_descifrado.sv     Descifrar un archivo cifrado que viene de disco
        ├── imem_init.hex        Programa de ejemplo para tb_imem
        └── dmem_init.hex        Datos de ejemplo para tb_dmem
```

### `cerbero_defs.svh`

Única fuente de verdad para los números del ISA: anchos, posiciones de campo,
opcodes de los cinco slots, códigos de condición, bits del PSW y causas de
falla. Lo incluyen los diecisiete módulos y los testbenches, de modo que renumerar un
opcode se hace en una línea y el RTL y las pruebas quedan sincronizados. Si
estuviera escrito a mano en cada archivo, un testbench podría quedar probando
una codificación que el módulo ya no implementa, y ambos "pasarían".

---

## Cómo agregar una unidad

El `makefile` descubre las unidades por patrón, así que no hay que tocarlo:

1. `src/cpu/<unidad>.sv` con el módulo.
2. `src/tb/tb_<unidad>.sv` con el testbench, módulo `tb_<unidad>`.
3. Si el módulo instancia a otros, declarar la dependencia en el `makefile`:
   `DEPS_<unidad> := $(CPU)/otro.sv`

Para un testbench de integración, que no tiene un `cpu/<nombre>.sv` detrás,
agregar el nombre a `NO_RTL`.

---

## Convenciones

- **Interfaz uniforme.** Las unidades de S2 a S4 reciben el slot crudo, publican
  los índices de registro que necesitan y reciben los valores de vuelta. La etapa
  de decodificación es un rebanado de bits y cinco instancias, sin un camino
  especial para ninguna.
- **Anular y marcar.** Una falla anula la operación de su slot y deja la causa en
  el PSW. El pipeline no se detiene ni se vacía. La operación nula nunca falla,
  ni siquiera por los campos que no usa.
- **Cada falla se detecta en un solo sitio.** `ILLOP`, `MISALIGN`, `RANGE`,
  `DENIED` y `NOKEY` los detecta la unidad que ejecuta la operación, porque de
  todas formas necesita saberlo para anular su propio resultado; `psw_fault_unit`
  las recibe y resuelve la prioridad entre slots. `WCONF` es la excepción: no
  pertenece a ninguna unidad, así que lo detecta el PSW a partir de los
  habilitadores de escritura reales. La etapa ID no detecta ninguna de las dos
  cosas, y la cabecera de `dispatch.sv` explica por qué: `ILLOP` sería una
  segunda copia de la tabla de campos reservados, y `WCONF` allí es imposible
  porque depende de si cada slot escribe de verdad, que se resuelve en EX.
- **Combinacional.** Ninguna unidad funcional registra su resultado, salvo la
  bóveda, que tiene estado propio. El reparto por etapas vive en el datapath,
  que es quien debe respetar la latencia de 3 bundles. Las memorias y el banco
  de registros sí son secuenciales, por definición.
- **Dos convenciones de flanco, a propósito.** El banco de registros escribe en
  el flanco positivo y lee en el negativo, de modo que una lectura ve la
  escritura del mismo ciclo: es lo que sostiene la latencia de 3 bundles, y
  `make latency` lo mide en vez de darlo por supuesto. Las memorias van al
  revés, lectura en el positivo y escritura en el negativo, así que una lectura
  no ve la escritura de su propio ciclo y lectura y escritura no coinciden nunca
  en el mismo instante. Está documentado en la cabecera de los tres módulos
  porque dos convenciones opuestas en el mismo diseño son justo lo que alguien
  "corrige" sin darse cuenta.
- **Los registros de salida de las memorias son registros de segmentación.** El
  de `imem` es IF/ID y el de `dmem` es EX/MEM, así que no se les pone otro
  registro encima. La consecuencia práctica es que el contador de programa y la
  LSU tienen que presentar sus direcciones de forma **combinacional** durante su
  etapa: si llegaran ya registradas, el pipeline entero correría un ciclo y la
  latencia de la carga pasaría de 3 a 4 bundles.
- **Son tres registros de segmentación, no cuatro.** No hay `reg_mem_wb`: el
  banco de registros escribe en el flanco que abre WB, así que sus entradas
  tienen que estar estables durante MEM, que es donde las deja `reg_ex_mem`. Los
  biestables del banco y los del PSW *son* la frontera MEM/WB. Un registro más
  delante del banco correría la escritura al ciclo n+5 y la latencia expuesta
  pasaría a 4 bundles; `make pipeline` lo mide sobre la cadena real.
- **No hay lógica de vaciado en ninguna frontera.** La BRU resuelve el salto en
  decodificación, así que el bundle que entra detrás es el delay slot, que el
  ISA ejecuta siempre, y el destino entra justo después. Nunca se busca un
  bundle que haya que descartar. Eso es lo que se compra resolviendo en ID en
  vez de en EX: resolver en EX exigiría dos delay slots, o uno más lógica de
  vaciado en las tres fronteras.
- **`HALT` también tiene delay slot.** El ISA no decía si `HALT` cuenta como
  salto; cuenta. El bundle siguiente ya se está buscando cuando la BRU ve
  `HALT`, así que se ejecuta, y desde ese flanco el PC queda congelado y `valid`
  en cero. Los bundles en vuelo terminan normalmente; esperar a que el pipeline
  se vacíe antes de terminar la simulación le toca a quien observa `halted`.
  Sólo el reset sale de ese estado.
- **El PC siempre es múltiplo de 16.** `JR` y `JALR` saltan a `R[rs]` tal cual,
  así que `fetch.sv` borra los cuatro bits bajos del destino. `imem` los ignora
  de todas formas, pero sin el borrado la BRU vería un PC distinto del bundle
  que de verdad se buscó, y el enlace de `JAL` y la comparación de región segura
  de la bóveda saldrían corridos.
- **Nada de saltos en el delay slot.** Si el delay slot trae otro salto, los dos
  surten efecto encadenados y el destino del primero acaba siendo el delay slot
  del segundo: se ejecuta una vez y se abandona. Es definido y reproducible, y
  `make fetch_flow` lo mide, pero no es lo que pretende quien genera el código,
  así que la v1.2 del ISA lo prohíbe.
- **Cuatro cosas son responsabilidad de `top.sv` y de ningún otro archivo**, porque
  hacen falta dos o más unidades para verlas, y la cabecera de `top.sv` las
  explica una por una: gatear la ALU con `valid`, porque `alu.sv` es la única
  unidad funcional sin esa entrada; marcar `ILLOP` en el opcode `111` de S3, que
  ninguna de las tres unidades del slot reclama; repartir los puertos de
  escritura de S3 entre la ALU corta y la unidad de ronda; y sustituir el valor
  del dato cargado en MEM, que no existe todavía en EX. Los cuatro tienen su
  propio programa en `tb_top.sv`, y los cuatro se probaron con mutantes.
- **La llave y la credencial se borran de los registros en el mismo bundle que
  las usa.** `vault_sesion.s` arma la credencial en `R1`–`R4` y la llave en
  `R5`–`R8`, y `KSETW` no borra nada: sin un borrado explícito las ocho palabras
  siguen en el banco cuando el programa termina, **fuera** de la región segura,
  a la vista de cualquier código que corra después. El borrado va en las dos ALU
  de los mismos cuatro bundles que llevan los `KSETW`, así que no cuesta un solo
  ciclo: todos los slots de un bundle leen el estado de registros previo al
  bundle, de modo que cada `KSETW` toma su palabra antes de que el borrado surta
  efecto — incluso en el cuarto, donde S1 escribe `R8` y S3 lo lee. La sección 7
  de `tb_archivo` es la que obliga a que siga siendo así; sin ella el borrado se
  puede quitar y la suite entera pasa igual.
- **Un ejecutor no es un testbench.** `make correr` usa `tb_programa.sv`, que
  muestra registros, memoria, la traza del pipeline y dónde se abre y se cierra
  la sesión, pero **no compara nada**: su única condición de fracaso es que el
  programa no llegue a `HALT`. Por eso no imprime `RESULTADO: OK` como los
  demás, donde esa línea significa que pasaron todos los casos. Un programa que
  calcula mal termina igual de bien y su salida se ve idéntica. Los programas
  que sí están verificados contra valores esperados viven en `tb_ejemplos.sv`,
  que entra en `make`.
- **Todo el camino criptográfico vive dentro de la región segura.** No es una
  recomendación: el cierre automático de sesión se evalúa en el mismo flanco en
  que `LOGIN` fijaría `AUTH`, así que un `LOGIN` fuera de
  `[SEC_BASE, SEC_LIMIT]` no falla, simplemente no abre sesión, y las rondas
  posteriores se anulan con `DENIED`. Por eso los dos programas de archivo
  ponen su lazo completo en `0x7000` y entran con `JALR`, y por eso el retorno
  cierra la sesión por hardware. Lo único que puede quedar afuera es la
  construcción de las constantes. Está en la sección 8.3 del ISA, en la cabecera
  de `vault_sesion.s`, y `tb_archivo` lo comprueba.
- **Los archivos de carga entran por macro, no por parámetro.** Icarus Verilog 12
  no puede pasar un parámetro de tipo `string` de un módulo a un submódulo: falla
  en elaboración con `Unable to bind variable`. Una macro se expande como literal
  en el sitio de la instancia y no cruza ninguna frontera de módulo:
  `make top IMEM=../tb/programa.hex DMEM=../tb/datos.hex`.
- **Compilación limpia.** `iverilog -Wall` y `verilator --lint-only -Wall` sin
  avisos. Conviene correr `make lint` antes de cada commit, no sólo cuando algo
  falla: Verilator detecta anchos inconsistentes, señales no usadas y latches
  inferidos que Icarus deja pasar.

---

## Estado

**Entrega 1** — Especificación del ISA. Entregada.
**Entrega 2** — En curso.

| Componente | Estado |
|---|---|
| Las siete unidades funcionales | Completas y verificadas |
| Integración bóveda + ronda | Completa |
| `regfile.sv` | Completo y verificado |
| Memorias `imem.sv` y `dmem.sv` | Completas y verificadas |
| `dispatch.sv` y `psw_fault_unit.sv` | Completos y verificados |
| Registros de segmentación | Completos y verificados |
| `fetch.sv` y contador de programa | Completo y verificado |
| `top.sv` y su testbench | **Completo y verificado** |
| Ensamblador propio | **Completo y verificado** |
| `load_file.py` y `extract_data.py` | **Completos y verificados** |
| Subrutina `__div32` | **Completa y verificada** |
| Programa que cifra y descifra un archivo completo | **Completo y verificado** |
| Registro de cambios para CE1108 | **Escrito**, en `docs/isa.md` §14 (v1.1 a v1.6) |

**El código está completo.** Las diecisiete unidades, los tres registros de
segmentación, el procesador completo, el ensamblador, las dos herramientas de
archivo y los programas de prueba, con 1748 casos de testbench y 151 de las
herramientas, todos pasando desde cero con `make clean && make lint && make`.

Lo que queda del proyecto no es código: es el documento de la Entrega 2. El
registro de cambios que CE1108 necesita ya está escrito como la sección 14 de
`docs/isa.md`, así que entregarles este paquete cumple con esa comunicación.
