# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the largest files below a folder; reparse points (junctions, links) are not followed.
# Variables: SEARCH_PATH (C:\) folder to scan; TOP (20) number of files; MIN_MB (100) smallest size that is listed.
# Exit: 0 report printed, 3 bad input.
$root = $env:SystemDrive + '\'
if ($env:SEARCH_PATH) { $root = $env:SEARCH_PATH.Trim() }
if ($root -notmatch '^[A-Za-z]:\\' -or -not (Test-Path -LiteralPath $root -PathType Container)) { Write-Output 'SEARCH_PATH must be an existing local folder like C:\'; exit 3 }
$top = 20
if ($env:TOP) { if (-not [int]::TryParse($env:TOP.Trim(), [ref]$top) -or $top -lt 1 -or $top -gt 500) { Write-Output 'TOP must be a number from 1 to 500'; exit 3 } }
$minMb = 100
if ($env:MIN_MB) { if (-not [int]::TryParse($env:MIN_MB.Trim(), [ref]$minMb) -or $minMb -lt 0 -or $minMb -gt 1048576) { Write-Output 'MIN_MB must be a number from 0 to 1048576'; exit 3 } }
$min = [int64]$minMb * 1MB
$found = New-Object System.Collections.Generic.List[object]
$stack = New-Object System.Collections.Generic.Stack[string]
$stack.Push($root)
$skipped = 0
while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    try {
        $di = New-Object System.IO.DirectoryInfo $dir
        foreach ($f in $di.GetFiles()) { if ($f.Length -ge $min) { $found.Add($f) } }
        foreach ($d in $di.GetDirectories()) {
            if (-not ($d.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { $stack.Push($d.FullName) }
        }
    } catch { $skipped++ }
}
$list = @($found | Sort-Object -Property Length -Descending | Select-Object -First $top)
Write-Output "$($found.Count) file(s) of at least $minMb MB below $root, showing $($list.Count) ($skipped folders not readable)"
foreach ($f in $list) {
    Write-Output ('{0,9:N0} MB  {1:yyyy-MM-dd}  {2}' -f ($f.Length / 1MB), $f.LastWriteTime, $f.FullName)
}
exit 0
