# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Points Windows and volume-licensed Office at a KMS host and activates them.
# Variables:
#   ACTION        activate (default), status, clear
#   KMS_HOST      host name or IP of the KMS host; host:port is accepted
#   KMS_PORT      1688
#   PRODUCTS      all (default), windows, office
#   INSTALL_GVLK  false. true first replaces the Windows key with the generic volume
#                 license key of this edition when Windows is not a KMS client yet.
# Exit codes: 0 ok, 1 activation failed or a product is not licensed, 3 bad input or nothing to do

$ErrorActionPreference = 'Stop'

$windowsApp = '55c92734-d682-4d71-983e-d6ec3f16059f'
$officeApp = '0ff1ce15-a989-479d-af46-f275c6370663'
$states = @('unlicensed', 'licensed', 'initial grace period', 'additional grace period',
    'non-genuine grace period', 'notification', 'extended grace period')
$hints = @{
    'C004F074' = 'the KMS host did not answer'
    'C004F038' = 'the KMS host has not reached its minimum client count yet'
    'C004F042' = 'the KMS host has no key for this product'
    'C004F06C' = 'the clocks of this computer and the KMS host differ too much'
}

# Generic volume license keys as published by Microsoft, by EditionID.
$gvlk = @{
    'Professional'             = 'W269N-WFGWX-YVC9B-4J6C9-T83GX'
    'ProfessionalN'            = 'MH37W-N47XK-V7XM9-C7227-GCQG9'
    'ProfessionalWorkstation'  = 'NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J'
    'ProfessionalWorkstationN' = '9FNHH-K3HBT-3W4TD-6383H-6XYWF'
    'ProfessionalEducation'    = '6TP4R-GNPTD-KYYHQ-7B7DP-J447Y'
    'ProfessionalEducationN'   = 'YVWGF-BXNMC-HTQYQ-CPQ99-66QFC'
    'Education'                = 'NW6C2-QMPVW-D7KKK-3GKT6-VCFB2'
    'EducationN'               = '2WH4N-8QGBV-H22JP-CT43Q-MDWWJ'
    'Enterprise'               = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'
    'EnterpriseN'              = 'DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4'
    'EnterpriseG'              = 'YYVX9-NTFWV-6MDM3-9PT4T-4M68B'
    'EnterpriseGN'             = '44RPN-FTY23-9VTTB-MP9BX-T84FV'
}
# Server and LTSC keys change with the release: EditionID, then build number.
$gvlkByBuild = @{
    'EnterpriseS'      = @{ 14393 = 'DCPHK-NFMTC-H88MJ-PFHPY-QJ4BJ'; 17763 = 'M7XTQ-FN8P6-TTKYV-9D4CC-J462D'; 19044 = 'M7XTQ-FN8P6-TTKYV-9D4CC-J462D'; 26100 = 'M7XTQ-FN8P6-TTKYV-9D4CC-J462D' }
    'EnterpriseSN'     = @{ 14393 = 'QFFDN-GRT3P-VKWWX-X7T3R-8B639'; 17763 = '92NFX-8DJQP-P6BBQ-THF9C-7CG2H'; 19044 = '92NFX-8DJQP-P6BBQ-THF9C-7CG2H'; 26100 = '92NFX-8DJQP-P6BBQ-THF9C-7CG2H' }
    'IoTEnterpriseS'   = @{ 19044 = 'KBN8V-HFGQ4-MGXVD-347P6-PDQGT'; 26100 = 'KBN8V-HFGQ4-MGXVD-347P6-PDQGT' }
    'ServerStandard'   = @{ 14393 = 'WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY'; 17763 = 'N69G4-B89J2-4G8F4-WWYCC-J464C'; 20348 = 'VDYBN-27WPP-V4HQT-9VMD4-VMK7H'; 26100 = 'TVRH6-WHNXV-R9WG3-9XRFY-MY832' }
    'ServerDatacenter' = @{ 14393 = 'CB7KF-BWN84-R7R2Y-793K2-8XDDG'; 17763 = 'WMDGN-G9PQG-XVVXX-R3X43-63DFG'; 20348 = 'WX4NM-KYWYW-QJJR4-XV3QB-6VM33'; 26100 = 'D764K-2NDRG-47T6Q-P8T8W-YP6DF' }
    'ServerTurbine'    = @{ 20348 = 'NTBV8-9K7Q8-V27C6-M2BTV-KHMXV'; 26100 = 'XGN3F-F394H-FD2MY-PP6FD-8MCRC' }
    'ServerSolution'   = @{ 14393 = 'JCKRF-N37P4-C2D82-9YXRT-4M63B'; 17763 = 'WVDHN-86M7X-466P6-VHXV7-YY726' }
}

function Stop-Script([string]$Message, [int]$Code) {
    [Console]::Out.WriteLine($Message)
    exit $Code
}

function Get-Choice([string]$Name, [string]$Value, [string[]]$Allowed) {
    $v = "$Value".Trim().ToLower()
    if (-not $v) { return $Allowed[0] }
    if ($Allowed -notcontains $v) { Stop-Script "$Name must be one of: $($Allowed -join ', ')." 3 }
    return $v
}

function Get-License([string]$AppId) {
    @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='$AppId' AND PartialProductKey IS NOT NULL" |
            Where-Object { -not $_.LicenseIsAddon })
}

function Get-Channel($Product) {
    if ("$($Product.Description)" -match ',\s*(\S+) channel') { return $Matches[1] }
    return 'unknown'
}

function Format-License($Product) {
    $index = [int]$Product.LicenseStatus
    $state = if ($index -ge 0 -and $index -lt $states.Count) { $states[$index] } else { "status $index" }
    $line = '{0}: {1}, {2} key' -f $Product.Name, $state, (Get-Channel $Product)
    if ($Product.GracePeriodRemaining -gt 0) {
        $line += ', {0} days left' -f [math]::Floor($Product.GracePeriodRemaining / 1440)
    }
    return $line
}

# The licensing error sits in the WMI error record when there is one.
function Get-ErrorCode($ErrorRecord) {
    $ex = $ErrorRecord.Exception
    $value = $ex.HResult
    if ($ex.PSObject.Properties['ErrorData'] -and $ex.ErrorData) {
        $prop = $ex.ErrorData.CimInstanceProperties['error_Code']
        if ($prop -and $null -ne $prop.Value) { $value = $prop.Value }
    }
    return '{0:X8}' -f $value
}

function Test-KmsPort([string]$Name, [int]$Port) {
    try { $addresses = [System.Net.Dns]::GetHostAddresses($Name) } catch { return $false }
    foreach ($address in $addresses) {
        $client = New-Object System.Net.Sockets.TcpClient($address.AddressFamily)
        try {
            $pending = $client.BeginConnect($address, $Port, $null, $null)
            if ($pending.AsyncWaitHandle.WaitOne(5000)) {
                $client.EndConnect($pending)
                return $true
            }
        }
        catch { continue }
        finally { $client.Close() }
    }
    return $false
}

# Returns an empty string when the product is licensed afterwards, else the reason.
function Invoke-Activation($Service, $Product) {
    try {
        Invoke-CimMethod -InputObject $Product -MethodName Activate | Out-Null
    }
    catch {
        $code = Get-ErrorCode $_
        $hint = if ($hints.ContainsKey($code)) { $hints[$code] } else { "$($_.Exception.Message)".Trim() }
        return "0x$code $hint".Trim()
    }
    Invoke-CimMethod -InputObject $Service -MethodName RefreshLicenseStatus | Out-Null
    $after = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ID='$($Product.ID)'"
    if ($after.LicenseStatus -ne 1) { return 'the product is still not licensed' }
    return ''
}

$action = Get-Choice 'ACTION' $env:ACTION @('activate', 'status', 'clear')
$products = Get-Choice 'PRODUCTS' $env:PRODUCTS @('all', 'windows', 'office')
$installGvlk = (Get-Choice 'INSTALL_GVLK' $env:INSTALL_GVLK @('false', 'true')) -eq 'true'
$doWindows = $products -ne 'office'
$doOffice = $products -ne 'windows'

try {
    $service = Get-CimInstance -ClassName SoftwareLicensingService
}
catch {
    Stop-Script "The software licensing service cannot be read: $($_.Exception.Message)" 1
}

if ($action -eq 'status') {
    $all = @()
    if ($doWindows) { $all += Get-License $windowsApp }
    if ($doOffice) { $all += Get-License $officeApp }
    if (-not $all) { Stop-Script 'No licensed product found.' 3 }
    $open = @($all | Where-Object { $_.LicenseStatus -ne 1 }).Count
    Write-Output ('{0} of {1} products licensed' -f ($all.Count - $open), $all.Count)
    foreach ($p in $all) { Write-Output (Format-License $p) }
    $set = "$($service.KeyManagementServiceMachine)".Trim()
    $found = "$($service.DiscoveredKeyManagementServiceMachineName)".Trim()
    if ($set) {
        Write-Output "KMS host set for Windows: ${set}:$($service.KeyManagementServicePort)"
    }
    elseif ($found) {
        Write-Output "KMS host found by DNS for Windows: ${found}:$($service.DiscoveredKeyManagementServiceMachinePort)"
    }
    else {
        Write-Output 'KMS host for Windows: none set, DNS discovery'
    }
    if ($open) { exit 1 }
    exit 0
}

if ($action -eq 'clear') {
    if ($doWindows) {
        Invoke-CimMethod -InputObject $service -MethodName ClearKeyManagementServiceMachine | Out-Null
        Invoke-CimMethod -InputObject $service -MethodName ClearKeyManagementServicePort | Out-Null
        Write-Output 'Windows: KMS host removed, DNS discovery applies again.'
    }
    if ($doOffice) {
        foreach ($p in (Get-License $officeApp | Where-Object { (Get-Channel $_) -eq 'VOLUME_KMSCLIENT' })) {
            Invoke-CimMethod -InputObject $p -MethodName ClearKeyManagementServiceMachine | Out-Null
            Invoke-CimMethod -InputObject $p -MethodName ClearKeyManagementServicePort | Out-Null
            Write-Output "$($p.Name): KMS host removed."
        }
    }
    exit 0
}

$kmsHost = "$env:KMS_HOST".Trim()
$kmsPort = "$env:KMS_PORT".Trim()
if ($kmsHost -match '^\[([0-9A-Fa-f:]+)\]:(\d{1,5})$' -or $kmsHost -match '^([^:\[\]]+):(\d{1,5})$') {
    $kmsHost = $Matches[1]
    $kmsPort = $Matches[2]
}
if (-not $kmsHost) { Stop-Script 'KMS_HOST is required: host name or IP of your KMS host.' 3 }
$address = $null
$isName = $kmsHost -match '^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$'
if (-not $isName -and -not [System.Net.IPAddress]::TryParse($kmsHost, [ref]$address)) {
    Stop-Script 'KMS_HOST is not a host name or an IP address.' 3
}
if (-not $kmsPort) { $kmsPort = '1688' }
if ($kmsPort -notmatch '^\d{1,5}$' -or [int]$kmsPort -lt 1 -or [int]$kmsPort -gt 65535) {
    Stop-Script 'KMS_PORT must be a number from 1 to 65535.' 3
}
$kmsPort = [int]$kmsPort

if (-not (Test-KmsPort $kmsHost $kmsPort)) {
    Stop-Script "The KMS host ${kmsHost}:$kmsPort cannot be reached over TCP." 1
}

$done = 0
$failed = 0

if ($doWindows) {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $edition = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID -replace '^(Server\w+)Cor$', '$1'
    $windows = @(Get-License $windowsApp | Sort-Object { (Get-Channel $_) -ne 'VOLUME_KMSCLIENT' })[0]
    $channel = if ($windows) { Get-Channel $windows } else { 'no' }

    if ($channel -ne 'VOLUME_KMSCLIENT') {
        $key = $gvlk[$edition]
        if (-not $key -and $gvlkByBuild.ContainsKey($edition)) { $key = $gvlkByBuild[$edition][[int]$os.BuildNumber] }
        if ($edition -like 'Core*') {
            Write-Output 'Windows: Home editions cannot be activated by KMS.'
        }
        elseif (-not $installGvlk) {
            Write-Output "Windows: uses a $channel key. Set INSTALL_GVLK to replace it with the volume license key of this edition."
        }
        elseif (-not $key) {
            Write-Output "Windows: no volume license key known for edition $edition, build $($os.BuildNumber)."
        }
        else {
            try {
                Invoke-CimMethod -InputObject $service -MethodName InstallProductKey -Arguments @{ ProductKey = $key } | Out-Null
                Invoke-CimMethod -InputObject $service -MethodName RefreshLicenseStatus | Out-Null
                Write-Output "Windows: volume license key for $edition installed, replacing the $channel key."
                $windows = @(Get-License $windowsApp | Where-Object { (Get-Channel $_) -eq 'VOLUME_KMSCLIENT' })[0]
            }
            catch {
                Write-Output "Windows: the volume license key was refused (0x$(Get-ErrorCode $_))."
                $failed++
                $windows = $null
            }
        }
        if ($windows -and (Get-Channel $windows) -ne 'VOLUME_KMSCLIENT') { $windows = $null }
    }

    if ($windows) {
        Invoke-CimMethod -InputObject $service -MethodName SetKeyManagementServiceMachine -Arguments @{ MachineName = $kmsHost } | Out-Null
        Invoke-CimMethod -InputObject $service -MethodName SetKeyManagementServicePort -Arguments @{ PortNumber = [uint32]$kmsPort } | Out-Null
        $reason = Invoke-Activation $service $windows
        if ($reason) {
            Write-Output "Windows: activation failed, $reason"
            $failed++
        }
        else {
            Write-Output "Windows: activated through ${kmsHost}:$kmsPort"
            $done++
        }
    }
}

if ($doOffice) {
    $office = @(Get-License $officeApp | Where-Object { (Get-Channel $_) -eq 'VOLUME_KMSCLIENT' })
    if (-not $office) {
        Write-Output 'Office: no volume-licensed Office found. Microsoft 365 Apps and retail Office do not use KMS.'
    }
    foreach ($p in $office) {
        Invoke-CimMethod -InputObject $p -MethodName SetKeyManagementServiceMachine -Arguments @{ MachineName = $kmsHost } | Out-Null
        Invoke-CimMethod -InputObject $p -MethodName SetKeyManagementServicePort -Arguments @{ PortNumber = [uint32]$kmsPort } | Out-Null
        $reason = Invoke-Activation $service $p
        if ($reason) {
            Write-Output "$($p.Name): activation failed, $reason"
            $failed++
        }
        else {
            Write-Output "$($p.Name): activated through ${kmsHost}:$kmsPort"
            $done++
        }
    }
}

if ($failed) { exit 1 }
if (-not $done) { exit 3 }
exit 0
