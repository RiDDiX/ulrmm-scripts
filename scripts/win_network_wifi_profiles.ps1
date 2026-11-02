# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Lists the saved Wi-Fi profiles with name, authentication, encryption and connection mode. Keys are never read or printed.
# Variables: none.
# Exit: 0 report printed, 1 a profile could not be read.
$root = Join-Path $env:ProgramData 'Microsoft\Wlansvc\Profiles\Interfaces'
if (-not (Test-Path -LiteralPath $root)) { Write-Output 'No Wi-Fi profiles (no wireless adapter was ever configured)'; exit 0 }
$files = @(Get-ChildItem -LiteralPath $root -Filter '*.xml' -Recurse -File -ErrorAction SilentlyContinue)
if ($files.Count -eq 0) { Write-Output 'No saved Wi-Fi profiles'; exit 0 }
$bad = 0
Write-Output "$($files.Count) saved Wi-Fi profile(s)"
foreach ($f in $files) {
    try {
        $x = [xml](Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 -ErrorAction Stop)
        $p = $x.WLANProfile
        $sec = $p.MSM.security
        Write-Output ("{0}: auth {1}, encryption {2}, mode {3}" -f $p.name, $sec.authEncryption.authentication, $sec.authEncryption.encryption, $p.connectionMode)
    } catch {
        Write-Output "Could not read $($f.Name)"
        $bad++
    }
}
if ($bad -gt 0) { exit 1 }
exit 0
