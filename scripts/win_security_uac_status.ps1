# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Checks that User Account Control is enabled and reports its policy settings.
# Variables: none
# Exit: 0 UAC enabled, 1 UAC disabled, 3 policy key unreadable
$ErrorActionPreference = 'Stop'
$key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
try {
    $p = Get-ItemProperty -Path $key
} catch {
    Write-Output ('Cannot read ' + $key)
    exit 3
}
$lua = $p.EnableLUA
$prompt = $p.ConsentPromptBehaviorAdmin
$names = @{
    0 = 'elevate without prompting'
    1 = 'prompt for credentials on the secure desktop'
    2 = 'prompt for consent on the secure desktop'
    3 = 'prompt for credentials'
    4 = 'prompt for consent'
    5 = 'prompt for consent for non-Windows binaries'
}
if ($lua -eq 1) {
    Write-Output 'OK: UAC is enabled'
    $rc = 0
} else {
    Write-Output 'FAIL: UAC is disabled (EnableLUA is not 1)'
    $rc = 1
}
$desc = if ($null -ne $prompt -and $names.ContainsKey([int]$prompt)) { $names[[int]$prompt] } else { 'not set (default)' }
Write-Output ('Admin prompt behaviour: ' + $desc)
Write-Output ('Secure desktop prompt: ' + $p.PromptOnSecureDesktop)
Write-Output ('Admin approval mode for the built-in administrator: ' + $p.FilterAdministratorToken)
Write-Output ('Remote UAC token filter (LocalAccountTokenFilterPolicy): ' + $p.LocalAccountTokenFilterPolicy)
exit $rc
