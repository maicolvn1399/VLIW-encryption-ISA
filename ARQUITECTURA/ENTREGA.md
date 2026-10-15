# Procesador CERBERO

Esta carpeta contiene el RTL, los testbenches, las herramientas y la
especificación de la arquitectura CERBERO. El compilador Nova está en el
directorio padre.

## Requisitos y pruebas

Se necesita Icarus Verilog (`iverilog`, `vvp`), Python 3 y GNU Make. Desde
`ARQUITECTURA/src/build`:

```sh
make sim
make lint
make clean
```

La integración con el compilador Nova se ejecuta desde la raíz del proyecto:

```sh
make prueba-rtl
```
