#Requires -Version 5.1
<#
    run_bru.ps1 - Compila y corre el testbench de la unidad de saltos.

    No hay make en la maquina, asi que este script es el punto de entrada.

    Uso:
        .\sim\run_bru.ps1              corrida normal, debe terminar en 0
        .\sim\run_bru.ps1 -ProveFail   inyecta un caso incorrecto a proposito,
                                       debe terminar distinto de 0

    El flag -g2012 es obligatorio: sin el, Icarus rechaza always_comb,
    always_ff y logic. Cualquier advertencia de compilacion se trata como
    error, porque una advertencia de ancho implicito en esta ISA suele ser un
    bug de verdad.
#>
[CmdletBinding()]
param(
    [switch]$ProveFail
)

$ErrorActionPreference = 'Stop'

$root     = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path $PSScriptRoot 'build'

if (-not (Test-Path $buildDir)) {
    New-Item -ItemType Directory -Path $buildDir | Out-Null
}

$logOut = Join-Path $buildDir 'bru_compile.out'
$logErr = Join-Path $buildDir 'bru_compile.err'

# Las rutas que se le pasan a iverilog van relativas a la raiz del repo, no
# absolutas: la ruta del proyecto contiene un espacio ("TEC 2026") y
# Start-Process une los argumentos sin citarlos, asi que una ruta absoluta se
# parte en dos y la compilacion falla con "No such file or directory".
$vvpRel = 'sim\build\bru.vvp'
$srcRel = @('rtl\bru.sv', 'tb\tb_bru.sv')

foreach ($rel in $srcRel) {
    if (-not (Test-Path (Join-Path $root $rel))) {
        Write-Host "No existe el fuente: $rel"
        exit 1
    }
}

$ivArgs = @('-g2012', '-Wall', '-o', $vvpRel)
if ($ProveFail) {
    $ivArgs += '-DFORCE_FAIL'
    Write-Host 'Modo autoprueba: se inyecta un caso deliberadamente incorrecto.'
}
$ivArgs += $srcRel

Write-Host 'Compilando...'
$compile = Start-Process -FilePath 'iverilog' -ArgumentList $ivArgs `
    -WorkingDirectory $root -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $logOut -RedirectStandardError $logErr

$compileOut = Get-Content $logOut
$compileErr = Get-Content $logErr

if ($compile.ExitCode -ne 0) {
    Write-Host 'Compilacion fallida:'
    if ($compileOut) { $compileOut | ForEach-Object { Write-Host "  $_" } }
    if ($compileErr) { $compileErr | ForEach-Object { Write-Host "  $_" } }
    exit 1
}

if ($compileOut -or $compileErr) {
    Write-Host 'Compilacion con advertencias, se trata como error:'
    if ($compileOut) { $compileOut | ForEach-Object { Write-Host "  $_" } }
    if ($compileErr) { $compileErr | ForEach-Object { Write-Host "  $_" } }
    exit 1
}

Write-Host 'Compilacion limpia, sin advertencias.'
Write-Host 'Simulando...'

$run = Start-Process -FilePath 'vvp' -ArgumentList @($vvpRel) `
    -WorkingDirectory $root -NoNewWindow -Wait -PassThru

Write-Host "Codigo de salida de la simulacion: $($run.ExitCode)"
exit $run.ExitCode
