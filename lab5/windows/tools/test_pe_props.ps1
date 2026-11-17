param(
    [string]$PePath = 'C:\Tools\ProcessExplorer\procexp64.exe',
    [string]$Tools = $PSScriptRoot,
    [string]$Shot = ''
)
$ErrorActionPreference = 'Stop'
if (-not $Shot) {
    $base = $env:TMPDIR
    if (-not $base) { $base = Join-Path $env:LOCALAPPDATA 'hermes\cache\scratch' }
    $Shot = Join-Path $base 'lab5_pe_props_integration.png'
}
if (-not (Test-Path -LiteralPath $PePath)) { throw ('Process Explorer not found: ' + $PePath) }
$p = Get-Process procexp64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) {
    Start-Process -FilePath $PePath | Out-Null
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $p = Get-Process procexp64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($p) { break }
    }
}
if (-not $p) { throw 'Process Explorer window did not appear' }
$propsScript = Join-Path $Tools 'pe_props.ps1'
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $propsScript -Row 2 -Shot $Shot 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { Write-Output ([string]$_) }
if ($code -ne 0) { throw ('pe_props returned exit ' + $code) }
if (-not (Test-Path -LiteralPath $Shot)) { throw ('Properties screenshot missing: ' + $Shot) }
$item = Get-Item -LiteralPath $Shot
if ($item.Length -lt 10000) { throw ('Properties screenshot unexpectedly small: ' + $item.Length) }
Write-Output ('PASS properties dialog screenshot bytes=' + $item.Length)
