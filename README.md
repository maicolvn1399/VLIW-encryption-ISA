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

make            # compila y ejecuta los siete testbenches
make lint       # análisis estático de las seis unidades
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

---

## Cobertura actual

| Unidad | Casos | Qué verifica |
|---|---:|---|
| `alu` | 334 | Los 32 opcodes, extensión de signo, enmascarado del desplazamiento, las cuatro banderas, los ocho códigos de condición de `SETcc`, las dos fuentes de `ILLOP` |
| `bru` | 295 | Las ocho condiciones, destino relativo e indirecto, enlace, detención, bits reservados del tipo J |
| `crypto_unit` | 93 | Cifrado y descifrado ronda a ronda, decodificación del par, aislamiento de la subllave sin permiso |
| `key_vault` | 100 | Protocolo completo, `KVALID`, auto-logout, las tres causas de falla, fuga de subllave |
| `lsu` | 241 | Los cuatro carriles en los dos sentidos, postincremento, `ILLOP`, `MISALIGN`, `RANGE` y su prioridad |
| `short_alu` | 92 | Las ocho suboperaciones en las dos formas, aritmética envolvente, combinaciones reservadas |
| `crypto_vault` | 90 | **Integración**: bóveda y unidad de ronda juntas, contra el modelo de referencia |
| **Total** | **1245** | |

### Autoprueba del arnés

Un testbench que siempre pasa no prueba nada. Los siete aceptan `-DFORCE_FAIL`,
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
    │   ├── cerbero_defs.svh     Opcodes, campos, condiciones y causas
    │   ├── alu.sv               S0 y S1
    │   ├── lsu.sv               S2
    │   ├── crypto_unit.sv       S3, ronda Feistel4
    │   ├── key_vault.sv         S3, bóveda
    │   ├── short_alu.sv         S3, ALU corta
    │   └── bru.sv               S4
    └── tb/
        ├── key_vault_model.sv   Modelo de bóveda para probar crypto_unit sola
        ├── tb_<unidad>.sv       Un testbench por unidad
        └── tb_crypto_vault.sv   Cosimulación de bóveda y ronda
```

### `cerbero_defs.svh`

Única fuente de verdad para los números del ISA: anchos, posiciones de campo,
opcodes de los cinco slots, códigos de condición, bits del PSW y causas de
falla. Lo incluyen los seis módulos y los testbenches, de modo que renumerar un
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
- **Combinacional.** Ninguna unidad registra su resultado salvo la bóveda, que
  tiene estado propio. El reparto por etapas vive en el datapath, que es quien
  debe respetar la latencia de 3 bundles.
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
| Datapath: `fetch`, `dispatch`, `regfile`, `psw`, `wb_arbiter` | Pendiente |
| Memorias `imem` y `dmem` | Pendiente |
| Registros de segmentación del pipeline | Pendiente |
| Ensamblador propio | Pendiente |
| `load_file.py` y `extract_data.py` | Pendiente |
| Subrutina `__divmod32` | Pendiente |
