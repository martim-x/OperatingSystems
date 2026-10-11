# tree_sizes.ps1 - вывод дерева каталогов с размерами файлов (уровень 8)
# Для каталогов - количество файлов внутри, для файлов - размер
# в KB/MB/GB (десятичные) и в KiB/MiB/GiB (двоичные).
param([string]$Path = ".")

$ErrorActionPreference = "SilentlyContinue"

function Format-Decimal($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}

function Format-Binary($bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GiB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MiB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KiB" -f ($bytes / 1KB) }
    return "$bytes B"
}

Write-Host ""
Write-Host "============================================================"
Write-Host " ДЕРЕВО КАТАЛОГОВ: $Path"
Write-Host " Формат размера файла: <десятичные> / <двоичные>"
Write-Host "============================================================"

$items = @(Get-ChildItem -Path $Path -Recurse | Sort-Object { $_.FullName })
Write-Host "[DIR ] $($Path.PadRight(45)) размер: $(Format-Decimal 0) / $(Format-Binary 0)"

foreach ($i in $items) {
    $rel = $i.FullName.Replace((Get-Location).Path, ".")
    if ($i.PSIsContainer) {
        $count = @(Get-ChildItem -Path $i.FullName -File -Recurse).Count
        Write-Host ("[DIR ] {0,-45} файлов: {1}, размер: {2} / {3}" -f $rel.PadRight(45), $count, (Format-Decimal 0), (Format-Binary 0))
    } else {
        Write-Host ("[FILE] {0,-45} {1} / {2}" -f $rel.PadRight(45), (Format-Decimal $i.Length).PadLeft(12), (Format-Binary $i.Length).PadLeft(12))
    }
}
Write-Host "============================================================"
