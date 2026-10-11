# run_lab.ps1 - driver for LR2 on Windows
# Must run in an INTERACTIVE session (schtasks /IT), otherwise screen
# capture fails: an SSH session lives in session 0 and cannot see
# the desktop.
# Waits for commands in $QUEUE, runs each one, prints the prompt plus the
# output on screen, takes a full-screen screenshot and writes $DONE\NN.done
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# enlarge the console window so the text in the screenshot is readable
if (-not ("Win32" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@
}
[void][Win32]::ShowWindow([Win32]::GetConsoleWindow(), 3)

$SYNC  = "C:\lab2_sync"
$QUEUE = "$SYNC\queue"
$DONE  = "$SYNC\done"
$SHOTS = "$SYNC\shots"
foreach ($d in @($SYNC, $QUEUE, $DONE, $SHOTS)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    public static class Focus {
        [DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
}
"@

$LOG = "$SYNC\driver.log"
function W([string]$m) {
    $line = "{0} {1}" -f (Get-Date -Format "HH:mm:ss"), $m
    Add-Content -Path $LOG -Value $line -Encoding UTF8
    Write-Host $line
}

function Take-Shot([string]$path) {
    $b = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

# The console does not wrap long lines, so long paths run past the right edge
# and get cut off in the screenshot. Wrap them ourselves at 118 columns.
function Write-Wrapped([string]$text, [string]$Color = "", [int]$Indent = 0) {
    $width = 118
    $pad = " " * $Indent
    foreach ($line in ($text -split "`r?`n")) {
        if ($line.Length -le $width) {
            if ($Color) { Write-Host $pad$line -ForegroundColor $Color }
            else { Write-Host $pad$line }
            continue
        }
        # keep paths intact: break at separators nearest to the limit
        $rest = $line
        $first = $true
        while ($rest.Length -gt $width) {
            $cut = $width
            $cands = @(($rest.LastIndexOf("\", $width)), ($rest.LastIndexOf("/", $width)),
                       $rest.LastIndexOf(" ", $width))
            foreach ($c in $cands) { if ($c -gt 40) { $cut = $c } }
            $head = $rest.Substring(0, $cut + 1)
            if ($first) { if ($Color) { Write-Host $pad$head -ForegroundColor $Color } else { Write-Host $pad$head } }
            else { Write-Host (" " * 6)$head }
            $rest = $rest.Substring($cut + 1)
            $first = $false
        }
        if ($rest -ne "") {
            if ($first) { if ($Color) { Write-Host $pad$rest -ForegroundColor $Color } else { Write-Host $pad$rest } }
            else { Write-Host (" " * 6)$rest }
        }
    }
}

# Кодовую страницу консоли здесь НЕ меняем: chcp 65001 переключил бы и cmd,
# запускаемый из этого окна, и тот начал бы читать файлы очереди как UTF-8
# вместо OEM - кириллица в путях снова бы испортилась. Write-Host сам
# перекодирует .NET-строку в текущую страницу, поэтому в кадре кириллица
# отображается корректно без переключения.

# schtasks запускает задачу в C:\Windows\System32, а все команды задания
# используют относительные пути от каталога синхронизации. Без этого
# "cd /d OS2\..." падает с "путь не найден".
Set-Location $SYNC

Clear-Host
Write-Host "DRIVER LR2 - Windows" -ForegroundColor Green
Write-Host "queue: $QUEUE" -ForegroundColor DarkGray
Write-Host "waiting for commands..." -ForegroundColor Green
Write-Host ""
W "драйвер запущен, ждём очередь"

while ($true) {
    $cmdFile = Get-ChildItem "$QUEUE\*.cmd" -ErrorAction SilentlyContinue |
               Sort-Object Name | Select-Object -First 1
    if (-not $cmdFile) { Start-Sleep -Milliseconds 400; continue }

    # Кодировка консоли (866 или 1251) - угадывать нельзя: на этой машине
    # русские пути читаются только в фактической OEM-кодировке окна.
    $oenc = [System.Text.Encoding]::GetEncoding([int][Console]::OutputEncoding.CodePage)

    $num  = $cmdFile.BaseName.Split('_')[0]
    $slug = $cmdFile.BaseName.Substring($num.Length + 1)
    $inFile = "$QUEUE\$num`_$slug.in"
    # Оператор кладёт .cmd в кодировке консоли; читаем байты явно, иначе
    # PowerShell угадывает ANSI и ломает кириллицу в путях ещё до запуска.
    $cmd = ($oenc.GetString([System.IO.File]::ReadAllBytes($cmdFile.FullName))).Trim()

    W "взята команда $num`_$slug"
    Remove-Item $cmdFile.FullName -Force

    # Run the command through a temporary .cmd written in the OEM code page.
    # Passing the command as an argument to `cmd /c` loses Cyrillic: the
    # argument arrives in OEM encoding, so task_01i\Русский turns to mojibake.
    # Writing it to a file in CP866 first keeps the Cyrillic intact.
    $outFile = "$SYNC\tmp_out.txt"
    $runFile = "$SYNC\tmp_run.cmd"
    $enc = [System.Text.Encoding]::GetEncoding([int][Console]::OutputEncoding.CodePage)

    # Ввод и перенаправление записываем внутрь самого .cmd.
    # Если поставить ">" в PowerShell, он выполнит Out-File и запишет вывод
    # в UTF-16LE (с нулями между символами); если передать строку с кавычками
    # аргументом cmd /c, разбор команды ломается и вывод получается пустым.
    $inSpec = ""
    if (Test-Path $inFile) {
        $inSpec = " < `"$inFile`""
    }
    # Перенаправление ставим на КАЖДУЮ часть цепочки "&", а не один раз в конце.
    # В конце строки ">" действует только на последний элемент, и вывод
    # предыдущих команд (for, if, echo) уходил в stdout и терялся.
    # Обёртка в скобки тоже не годится: %PATH% содержит "Program Files (x86)",
    # и закрывающая скобка в данных обрывала блок - вывод получался пустым.
    # Разделитель ставим в КОНЕЦ предыдущей строки: строка, начинающаяся
    # с "&", cmd выполняет как "пустая команда и следующая", и следующая
    # вместе со своим перенаправлением не отрабатывает - файл остаётся
    # с выводом только первой части цепочки.
    $parts = [regex]::Split($cmd, '(&&|&)')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('@echo off')
    $first = $true
    foreach ($part in $parts) {
        if ($part -match '^&+$') { continue }
        if ($part.Trim() -eq '') { continue }
        if ($first) {
            [void]$sb.Append("`r`n")
            $first = $false
            [void]$sb.Append($part.Trim() + $inSpec + ' > "' + $outFile + '" 2>&1')
        } else {
            [void]$sb.Append(' &')
            [void]$sb.Append("`r`n")
            [void]$sb.Append($part.Trim() + $inSpec + ' >> "' + $outFile + '" 2>&1')
        }
    }
    [void]$sb.Append("`r`n")
    $body = $sb.ToString()
    [System.IO.File]::WriteAllText($runFile, $body, $enc)

    W "запуск $runFile, тело $body".Replace("`r`n", " / ")
    cmd /c call $runFile
    W "команда выполнена"

    $out = ""
    if (Test-Path $outFile) {
        $out = $oenc.GetString([System.IO.File]::ReadAllBytes($outFile))
        Remove-Item $outFile -Force
    }
    if ($null -eq $out) { $out = "" }
    $out = $out.TrimEnd()

    # The console window must be active before repainting: while it is in the
    # background, Clear-Host/Write-Host are deferred and the screenshot ends up
    # showing the previous command instead of the current one.
    [Win32.Focus]::ShowWindow([Win32.Focus]::GetConsoleWindow(), 3) | Out-Null
    [Win32.Focus]::SetForegroundWindow([Win32.Focus]::GetConsoleWindow()) | Out-Null
    Start-Sleep -Milliseconds 120

    # Build the visible frame: prompt, typed input, output.
    # Long paths do not wrap in the console, so wrap them ourselves,
    # otherwise the right part of the command is cut off in the screenshot.
    Clear-Host
    $prompt = "[User-6d4ec851@DESKTOP-9KMRHJ8 OS2]`$ $cmd"
    Write-Wrapped $prompt -Color Green -Indent 0
    if (Test-Path $inFile) {
        Write-Host ($oenc.GetString([System.IO.File]::ReadAllBytes($inFile)).TrimEnd())
    }
    Write-Host ""
    if ($out -ne "") { Write-Wrapped $out }
    Write-Host ""

    # save the text output for the report
    $txt = "### COMMAND: $cmd`r`n"
    if (Test-Path $inFile) {
        $txt += "### INPUT:`r`n" + $oenc.GetString([System.IO.File]::ReadAllBytes($inFile)) + "`r`n"
    }
    $txt += "### OUTPUT:`r`n" + $out + "`r`n"
    Set-Content "$DONE\$num.txt" $txt -Encoding UTF8

    Start-Sleep -Milliseconds 700
    W "снимок $num`_$slug"
    Take-Shot "$SHOTS\$num`_$slug.png"
    Set-Content "$DONE\$num.done" "ok" -Encoding ASCII
    W "готово $num"
    Write-Host ""
    Write-Host "[$num] $slug done" -ForegroundColor DarkGray
}