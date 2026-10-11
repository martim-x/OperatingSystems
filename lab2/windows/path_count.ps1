# path_count.ps1 - подсчёт исполняемых и неисполняемых команд в PATH (уровень 8)
$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================================"
Write-Host " СТАТИСТИКА ПО КАТАЛОГАМ PATH"
Write-Host "============================================================"

$env:PATH -split ';' | Where-Object { $_ -ne '' } | ForEach-Object {
    $dir = $_
    if (Test-Path $dir) {
        $items = @(Get-ChildItem -Path $dir -File)
        $exec = @($items | Where-Object { $_.Extension -match '^\.(exe|com|bat|cmd|ps1)$' })
        $nonexec = $items.Count - $exec.Count
        $total = $items.Count
        $pct = if ($total -gt 0) { [math]::Round(100.0 * $exec.Count / $total, 1) } else { 0 }
        "{0,-52} {1,8} {2,8} {3,6}%" -f $dir, $exec.Count, $nonexec, $pct
    } else {
        "{0,-52} {1,8}" -f $dir, "нет такого каталога"
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host(" ИТОГО ПО PATH")
Write-Host "============================================================"

$allexec = 0; $allnonexec = 0; $found = 0
$env:PATH -split ';' | Where-Object { $_ -ne '' } | ForEach-Object {
    if (Test-Path $_) {
        $found++
        $items = @(Get-ChildItem -Path $_ -File)
        $allexec += @($items | Where-Object { $_.Extension -match '^\.(exe|com|bat|cmd|ps1)$' }).Count
        $allnonexec += @($items | Where-Object { $_.Extension -notmatch '^\.(exe|com|bat|cmd|ps1)$' }).Count
    }
}
Write-Host "Каталогов в PATH:        $found"
Write-Host "Исполняемых команд:      $allexec"
Write-Host "Неисполняемых файлов:    $allnonexec"
Write-Host "Всего файлов:            $($allexec + $allnonexec)"
if (($allexec + $allnonexec) -gt 0) {
    $share = [math]::Round(100.0 * $allexec / ($allexec + $allnonexec), 1)
    Write-Host "Доля исполняемых:        $share%"
}
