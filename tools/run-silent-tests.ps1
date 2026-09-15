[CmdletBinding()]
param(
    [string]$Godot = "",
    [string]$Project = "",
    [string]$Runner = "res://src/tests/silent_test_runner.gd",
    [switch]$Import,
    [switch]$VerboseOutput
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Project)) { $Project = (Resolve-Path (Join-Path $PSScriptRoot ".." )).Path }
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = "D:\Tools\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot executable not found: $Godot" }
if (-not (Test-Path -LiteralPath (Join-Path $Project "project.godot"))) { throw "Godot project not found: $Project" }

function Invoke-Godot([string[]]$Arguments) {
    & $Godot @Arguments
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Import) {
    # Import assets once, then stop. A timeout prevents a broken plugin from
    # leaving CI hanging forever.
    $proc = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--editor", "--path", $Project, "--quit") -PassThru -NoNewWindow
    if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw "Godot import timed out after 60 seconds" }
    if ($proc.ExitCode -ne 0) { exit $proc.ExitCode }
}

$args = @("--headless", "--path", $Project, "--script", $Runner)
if ($VerboseOutput) { Invoke-Godot $args }
else {
    $output = & $Godot @args
    $exitCode = $LASTEXITCODE
    $output | Select-Object -Last 1
    exit $exitCode
}
