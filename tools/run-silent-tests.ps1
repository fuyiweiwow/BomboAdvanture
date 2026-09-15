[CmdletBinding()]
param(
    [string]$Godot = "",
    [string]$Project = "",
    [string]$Runner = "res://src/tests/silent_test_runner.gd",
    [switch]$Import,
    [switch]$VerboseOutput,
    [switch]$AllowEngineErrors
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

function Test-EngineErrors([string[]]$Lines) {
    $fatalPatterns = @(
        '^SCRIPT ERROR:',
        '^ERROR:',
        'Parse Error:',
        'Compile Error:',
        'Failed to load script',
        'Failed to instantiate an autoload'
    )
    foreach ($line in $Lines) {
        foreach ($pattern in $fatalPatterns) {
            if ($line -match $pattern) { return $true }
        }
    }
    return $false
}

if ($Import) {
    # Import assets once, then stop. A timeout prevents a broken plugin from
    # leaving CI hanging forever.
    $proc = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--editor", "--path", $Project, "--quit") -PassThru -NoNewWindow
    if (-not $proc.WaitForExit(60000)) { $proc.Kill(); throw "Godot import timed out after 60 seconds" }
    if ($proc.ExitCode -ne 0) { exit $proc.ExitCode }
}

$args = @("--headless", "--path", $Project, "--script", $Runner)
$stdoutPath = Join-Path ([IO.Path]::GetTempPath()) ("bombo-test-{0}.out" -f [guid]::NewGuid())
$stderrPath = Join-Path ([IO.Path]::GetTempPath()) ("bombo-test-{0}.err" -f [guid]::NewGuid())
try {
    $proc = Start-Process -FilePath $Godot -ArgumentList $args -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    $output = @(@(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue) + @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue))
    $exitCode = $proc.ExitCode
}
finally {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
}
if ($VerboseOutput) { $output | Write-Output }
else { $output | Where-Object { $_ -match '^\{' -or $_ -match '^\}' -or $_ -match '"passed"' -or $_ -match '"tests"' -or $_ -match '"name"' -or $_ -match '"failures"' } | Write-Output }

if ($exitCode -ne 0) { exit $exitCode }
if (-not $AllowEngineErrors -and (Test-EngineErrors $output)) {
    Write-Error "Godot reported engine/script errors; silent tests are considered failed. Rerun with -VerboseOutput for details."
    exit 2
}
exit 0
