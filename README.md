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

make            # compila y ejecuta los dieciocho testbenches
make lint       # análisis estático de las catorce unidades
make lsu        # solo el testbench de la LSU
make wave-lsu   # abre su forma de onda en GTKWave
make list       # lista las unidades disponibles
make clean      # borra los artefactos
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
file for the requested range`. Es esperado: los archivos de ejemplo traen menos
palabras que la memoria, y comprobar que las posiciones restantes quedan en
cero es justamente uno de los casos. Las posiciones que el archivo no cubre no
quedan indefinidas porque el módulo barre el arreglo a cero antes de leerlo.

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
| `pipeline` | 6 | **Integración**: mide la latencia expuesta sobre la cadena real de registros más el banco, y que el PC acompañe al bundle en ID y en EX |
| `fetch` | 41 | Avance de 16 en 16, salto tomado, destino desalineado forzado a múltiplo de 16, `HALT` congela el PC y apaga `valid`, el reset lo libera |
| `fetch_flow` | 16 | **Integración**: `fetch`, `imem`, `reg_if_id` y `bru` juntos sobre un programa de saltos; exactamente un delay slot por salto y el de `HALT` sí se ejecuta |
| **Total** | **1594** | |

### Autoprueba del arnés

Un testbench que siempre pasa no prueba nada. Los dieciocho aceptan `-DFORCE_FAIL`,
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
    │   └── reg_ex_mem.sv        Frontera EX/MEM
    └── tb/
        ├── key_vault_model.sv   Modelo de bóveda para probar crypto_unit sola
        ├── tb_<unidad>.sv       Un testbench por unidad
        ├── tb_crypto_vault.sv   Cosimulación de bóveda y ronda
        ├── tb_latency.sv        Medición de la latencia expuesta
        ├── tb_wconf.sv          Cosimulación de los dos detectores de WCONF
        ├── tb_pipeline.sv       Latencia expuesta sobre la cadena de registros
        ├── tb_fetch_flow.sv     Búsqueda, delay slot y HALT con la BRU real
        ├── imem_init.hex        Programa de ejemplo para tb_imem
        └── dmem_init.hex        Datos de ejemplo para tb_dmem
```

### `cerbero_defs.svh`

Única fuente de verdad para los números del ISA: anchos, posiciones de campo,
opcodes de los cinco slots, códigos de condición, bits del PSW y causas de
falla. Lo incluyen los catorce módulos y los testbenches, de modo que renumerar un
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
- **`HALT` también tiene delay slot.** El ISA no dice si `HALT` cuenta como
  salto; se trata igual. El bundle siguiente ya se está buscando cuando la BRU
  ve `HALT`, así que se ejecuta, y desde ese flanco el PC queda congelado y
  `valid` en cero. Los bundles en vuelo terminan normalmente; esperar a que el
  pipeline se vacíe antes de terminar la simulación le toca a quien observa
  `halted`. Solo el reset sale de ese estado.
- **El PC siempre es múltiplo de 16.** `JR` y `JALR` saltan a `R[rs]` tal cual,
  así que `fetch.sv` borra los cuatro bits bajos del destino. Sin eso `imem`
  buscaría el bundle correcto, pero la BRU y la bóveda verían un PC distinto.
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
| `top.sv` | Pendiente |
| Ensamblador propio | Pendiente |
| `load_file.py` y `extract_data.py` | Pendiente |
| Subrutina `__divmod32` | Pendiente |
