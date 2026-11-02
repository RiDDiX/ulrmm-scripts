# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists user profiles with path, last use, loaded state and optionally the size on disk. Deletes nothing.
# Variables: SIZES (checkbox, default false, adds the folder size and can take minutes on large profiles)
# Exit: 0 listed, 3 profile information unavailable
$ErrorActionPreference = 'Stop'
$sizes = ([string]$env:SIZES).Trim().ToLower() -eq 'true'

function Get-DirBytes([string]$Path) {
    $total = [long]0
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Path)
    while ($stack.Count -gt 0) {
        $dir = New-Object System.IO.DirectoryInfo($stack.Pop())
        try {
            foreach ($f in $dir.GetFiles()) { $total += $f.Length }
            foreach ($d in $dir.GetDirectories()) {
                if (-not ($d.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { $stack.Push($d.FullName) }
            }
        } catch {
            Write-Verbose ('skipped ' + $dir.FullName)
        }
    }
    return $total
}

try {
    $profiles = @(Get-CimInstance -ClassName Win32_UserProfile | Where-Object { -not $_.Special })
} catch {
    Write-Output ('Cannot read the profile list: ' + $_.Exception.Message)
    exit 3
}
Write-Output ('{0} user profile(s)' -f $profiles.Count)
foreach ($p in ($profiles | Sort-Object LocalPath)) {
    $name = $p.SID
    try {
        $name = (New-Object System.Security.Principal.SecurityIdentifier($p.SID)).Translate([System.Security.Principal.NTAccount]).Value
    } catch {
        $name = $p.SID + ' (unresolved)'
    }
    $last = if ($p.LastUseTime) { '{0:yyyy-MM-dd}' -f $p.LastUseTime } else { 'n/a' }
    $line = '{0} | {1} | lastuse={2} | loaded={3}' -f $name, $p.LocalPath, $last, $p.Loaded
    if ($sizes -and $p.LocalPath -and (Test-Path -LiteralPath $p.LocalPath)) {
        $line += ' | size={0:N0} MB' -f ((Get-DirBytes $p.LocalPath) / 1MB)
    }
    Write-Output $line
}
exit 0
