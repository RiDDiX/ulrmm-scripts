# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Installs a third-party antivirus product unattended, or starts its installer for the signed-in user, after checking
#   the installer's Authenticode publisher.
# Variables: PRODUCT (required) eset-home, eset-endpoint-antivirus, eset-endpoint-security, bitdefender-gravityzone,
#   bitdefender-total-security, kaspersky-endpoint, kaspersky-home, avast-free, avg-free, malwarebytes; MODE (silent;
#   attended starts the vendor wizard in the session of the signed-in user, needs run as user); LICENSE_KEY ("",
#   silent only); INSTALLER_URL ("" = vendor default, https); GZ_PACKAGE_ID ("" GravityZone package id); BIRTH_DATE
#   ("" YYYY-MM-DD, kaspersky-home); ALLOW_EXISTING (false); TIMEOUT_MINUTES (40, silent only).
# Exit: 0 installed or already installed (also with a pending reboot), attended: installer started; 1 failed; 3 bad
#   input, unsupported system or mode, another antivirus is active, attended without a signed-in user.

$ProgressPreference = 'SilentlyContinue'

# Publisher = organization (O) of the Authenticode signer, compared exactly. Match = DisplayName in the uninstall keys.
# Modes = the MODE values a product supports, silent when not set.
$products = @{
    'eset-home'                  = @{ Name = 'ESET HOME Security'; Client = $true; Modes = @('silent', 'attended')
        Url = 'https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_nt64.exe'
        Publisher = @('ESET, spol. s r.o.'); Exe = '--silent --accepteula'
        Match = '^ESET (Security|NOD32 Antivirus|Internet Security|Smart Security)' }
    'eset-endpoint-antivirus'    = @{ Name = 'ESET Endpoint Antivirus'
        Url = 'https://download.eset.com/com/eset/apps/business/eea/windows/latest/eea_nt64.msi'
        Publisher = @('ESET, spol. s r.o.'); Msi = 'ACTIVATION_DLG_SUPPRESS=1'; License = 'ACTIVATION_DATA=key:{0}'
        Match = '^ESET Endpoint Antivirus' }
    'eset-endpoint-security'     = @{ Name = 'ESET Endpoint Security'
        Url = 'https://download.eset.com/com/eset/apps/business/ees/windows/latest/ees_nt64.msi'
        Publisher = @('ESET, spol. s r.o.'); Msi = 'ACTIVATION_DLG_SUPPRESS=1'; License = 'ACTIVATION_DATA=key:{0}'
        Match = '^ESET Endpoint Security' }
    'bitdefender-gravityzone'    = @{ Name = 'Bitdefender GravityZone'
        Url = 'https://download.bitdefender.com/SMB/Hydra/release/bst_win/downloaderWrapper/BEST_downloaderWrapper.msi'
        Publisher = @('Bitdefender SRL'); Msi = 'GZ_PACKAGE_ID="{1}"'; NeedsPackageId = $true
        Match = '^Bitdefender Endpoint Security' }
    'bitdefender-total-security' = @{ Name = 'Bitdefender Total Security'; Client = $true; Modes = @('attended')
        Url = 'https://download.bitdefender.com/windows/desktop/connect/cl/2023/all/bitdefender_ts_27_64b.exe'
        Publisher = @('Bitdefender SRL'); Match = '^Bitdefender Total Security' }
    'kaspersky-endpoint'         = @{ Name = 'Kaspersky Endpoint Security'
        Url = ''; Publisher = @('AO Kaspersky Lab', 'Kaspersky Lab JSC')
        Exe = '/s /pEULA=1 /pPRIVACYPOLICY=1 /pKSN=0 /pSKIPPRODUCTCHECK=1'; Msi = 'EULA=1 PRIVACYPOLICY=1'
        Match = '^Kaspersky Endpoint Security' }
    'kaspersky-home'             = @{ Name = 'Kaspersky Standard, Plus or Premium'; Client = $true
        Url = ''; Publisher = @('AO Kaspersky Lab'); NeedsBirthDate = $true
        Exe = '/s /mybirthdate={2} /pAGREETOEULA=1 /pAGREETOPRIVACYPOLICY=1'; License = '/pACTIVATIONCODE={0}'
        Match = '^Kaspersky( (Basic|Standard|Plus|Premium|Anti-Virus|Internet Security|Total Security))?$' }
    'avast-free'                 = @{ Name = 'Avast Free Antivirus'; Client = $true
        Url = 'https://files.avast.com/iavs9x/avast_free_antivirus_setup_offline.exe'
        Publisher = @('Gen Digital Inc.'); Exe = '/silent'; Match = '^Avast (Free Antivirus|Premium Security|One)' }
    'avg-free'                   = @{ Name = 'AVG AntiVirus Free'; Client = $true
        Url = 'https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_WIN_AVG/installertype_FULL/build_RELEASE/cookie_mmm_bav_998_999_000_m?alt=en-us'
        Publisher = @('Gen Digital Inc.'); Exe = '/silent'; Match = '^AVG (AntiVirus|Internet Security)' }
    'malwarebytes'               = @{ Name = 'Malwarebytes'; Client = $true
        Url = 'https://downloads.malwarebytes.com/file/mb-windows'
        Publisher = @('Malwarebytes Inc', 'Malwarebytes Inc.'); Exe = '/VERYSILENT /NORESTART'; Match = '^Malwarebytes' }
}

function Stop-Script([int]$Code, [string]$Result) {
    if ($script:work -and (Test-Path -LiteralPath $script:work)) {
        Remove-Item -LiteralPath $script:work -Recurse -Force -ErrorAction SilentlyContinue
    }
    [Console]::Out.WriteLine("RESULT: $Result")
    exit $Code
}

function Get-Uninstall {
    $keys = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
}

function Get-Installed([string]$Pattern) {
    Get-Uninstall | Where-Object { $_.DisplayName -match $Pattern } | Select-Object -First 1
}

# Follows redirects itself, because .NET Framework would follow a redirect from https to http.
function Save-Https([string]$Url, [string]$Path) {
    for ($hop = 0; $hop -lt 10; $hop++) {
        $req = [Net.WebRequest]::Create($Url)
        $req.AllowAutoRedirect = $false
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WindowsPowerShell/5.1'
        $req.Timeout = 120000
        $req.ReadWriteTimeout = 300000
        $resp = $req.GetResponse()
        try {
            if ([int]$resp.StatusCode -ge 300 -and [int]$resp.StatusCode -lt 400) {
                $next = New-Object Uri([Uri]$Url, [string]$resp.Headers['Location'])
                if ($next.Scheme -ne 'https') { throw "redirect to $($next.Scheme)://$($next.Host) refused" }
                $Url = $next.AbsoluteUri
                continue
            }
            $out = [IO.File]::Create($Path)
            try { $resp.GetResponseStream().CopyTo($out) } finally { $out.Dispose() }
            return
        } finally { $resp.Close() }
    }
    throw 'too many redirects'
}

$productId = "$env:PRODUCT".Trim().ToLower()
$mode = "$env:MODE".Trim().ToLower()
if (-not $mode) { $mode = 'silent' }
$licenseKey = "$env:LICENSE_KEY".Trim()
$urlOverride = "$env:INSTALLER_URL".Trim()
$packageId = "$env:GZ_PACKAGE_ID".Trim()
$birthDate = "$env:BIRTH_DATE".Trim()
$allowExisting = "$env:ALLOW_EXISTING".Trim().ToLower()
$timeoutText = "$env:TIMEOUT_MINUTES".Trim()
if (-not $timeoutText) { $timeoutText = '40' }

if (-not $products.ContainsKey($productId)) {
    Stop-Script 3 "failed PRODUCT must be one of: $(($products.Keys | Sort-Object) -join ', ')"
}
$p = $products[$productId]
if ($mode -notin @('silent', 'attended')) { Stop-Script 3 'failed MODE must be silent or attended' }
$modes = @('silent')
if ($p.Modes) { $modes = $p.Modes }
if ($modes -notcontains $mode) { Stop-Script 3 "failed $($p.Name) supports MODE=$($modes -join ' or MODE=') only" }
if ($mode -eq 'attended' -and $licenseKey) {
    Write-Output 'LICENSE_KEY is ignored in attended mode: the person activates the product in its own interface'
    $licenseKey = ''
}
if ($licenseKey -and $licenseKey -notmatch '^[A-Za-z0-9-]{4,64}$') { Stop-Script 3 'failed LICENSE_KEY may only contain letters, digits and dashes' }
if ($packageId -and $packageId -notmatch '^[A-Za-z0-9+/=_-]{8,512}$') { Stop-Script 3 'failed GZ_PACKAGE_ID has unexpected characters' }
if ($allowExisting -notin @('', 'true', 'false')) { Stop-Script 3 'failed ALLOW_EXISTING must be true or false' }
if ($timeoutText -notmatch '^\d{1,3}$' -or [int]$timeoutText -lt 5 -or [int]$timeoutText -gt 180) {
    Stop-Script 3 'failed TIMEOUT_MINUTES must be 5-180'
}
$url = $p.Url
if ($urlOverride) {
    $uri = $null
    if (-not [Uri]::TryCreate($urlOverride, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
        Stop-Script 3 'failed INSTALLER_URL must be an absolute https URL'
    }
    $url = $uri.AbsoluteUri
}
if (-not $url) { Stop-Script 3 "failed $($p.Name) has no public download, set INSTALLER_URL to your distribution kit" }
if ($p.NeedsPackageId -and -not $packageId) {
    Stop-Script 3 'failed GZ_PACKAGE_ID is required (the part in brackets of setupdownloader_[...].exe from the console)'
}
if ($p.NeedsBirthDate) {
    $bd = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($birthDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$bd)) {
        Stop-Script 3 'failed BIRTH_DATE (YYYY-MM-DD) is required, the installer needs it for a silent install'
    }
}
if ($licenseKey -and -not $p.License) {
    Write-Output "LICENSE_KEY is not used: $($p.Name) cannot be activated from the command line, activate it in its own interface"
}

$me = [Security.Principal.WindowsIdentity]::GetCurrent()
if ($mode -eq 'attended') {
    # A wizard started as SYSTEM or in session 0 is invisible and waits forever.
    if ($me.IsSystem) { Stop-Script 3 'failed runs as SYSTEM: run this entry as the signed-in user; nobody is signed in on this device' }
    if ([Diagnostics.Process]::GetCurrentProcess().SessionId -eq 0) {
        Stop-Script 3 'failed no interactive session: run this entry as the signed-in user; nobody is signed in on this device'
    }
} elseif (-not (New-Object Security.Principal.WindowsPrincipal($me)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Stop-Script 3 'failed must run as SYSTEM or administrator'
}
$os = Get-CimInstance -ClassName Win32_OperatingSystem
if ($p.Client -and $os.ProductType -ne 1) { Stop-Script 3 "failed $($p.Name) is a home product and does not support $($os.Caption)" }

$existing = Get-Installed $p.Match
if ($existing) {
    Write-Output "Already installed: $($existing.DisplayName) $($existing.DisplayVersion)"
    Stop-Script 0 "installed $($existing.DisplayName) $($existing.DisplayVersion)"
}

# Two real-time scanners on one machine cause hangs and blue screens; Defender steps aside by itself.
$others = @()
try {
    $others = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
            Where-Object { $_.displayName -notmatch '^(Windows|Microsoft) Defender' -and ($_.productState -band 0x1000) } |
            ForEach-Object { $_.displayName })
} catch {
    $vendors = '^(ESET|Bitdefender|Kaspersky|Avast|AVG (AntiVirus|Internet)|Avira|Malwarebytes|Sophos|Norton|McAfee|F-Secure|WithSecure|Trend Micro|G DATA|Symantec|Webroot|Panda)'
    $others = @(Get-Uninstall |
            Where-Object { $_.DisplayName -match $vendors -and $_.DisplayName -notmatch 'Management Agent|Remover|Uninstall|Browser|VPN|Password|WebAdvisor' } |
            ForEach-Object { $_.DisplayName } | Sort-Object -Unique)
}
if ($others.Count -gt 0) {
    if ($allowExisting -ne 'true') {
        Stop-Script 3 "failed another antivirus is active: $($others -join ', '). Remove it first or set ALLOW_EXISTING"
    }
    Write-Output "Continuing although another antivirus is active: $($others -join ', ')"
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]12288
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Working directory only SYSTEM and Administrators can write, created with its ACL in one step.
$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
foreach ($sid in 'S-1-5-18', 'S-1-5-32-544') {
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        (New-Object System.Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
$workName = 'ulrmm-av-' + [Guid]::NewGuid().ToString('N')
try {
    if ($mode -eq 'attended') {
        # The user's own temp folder: the same account writes, verifies and starts the installer.
        $script:work = Join-Path ([IO.Path]::GetTempPath()) $workName
        $null = [System.IO.Directory]::CreateDirectory($script:work)
    } else {
        $script:work = Join-Path $env:SystemRoot "Temp\$workName"
        $null = [System.IO.Directory]::CreateDirectory($script:work, $acl)
    }
} catch {
    Stop-Script 1 "failed cannot create the working directory: $($_.Exception.Message)"
}

Write-Output "Downloading $($p.Name) from $(([Uri]$url).Host)"
$raw = Join-Path $script:work 'download.bin'
try {
    Save-Https $url $raw
} catch {
    Stop-Script 1 "failed download: $($_.Exception.Message)"
}
# The file type decides how it runs, not the URL.
$head = New-Object byte[] 4
$fs = [IO.File]::OpenRead($raw)
$null = $fs.Read($head, 0, 4)
$fs.Dispose()
$magic = [BitConverter]::ToString($head)
if ($magic -like '4D-5A-*') { $kind = 'exe' }
elseif ($magic -eq 'D0-CF-11-E0') { $kind = 'msi' }
else { Stop-Script 1 'failed the download is neither an .exe nor an .msi, not run' }
$file = Join-Path $script:work "installer.$kind"
Move-Item -LiteralPath $raw -Destination $file
$size = [math]::Round((Get-Item -LiteralPath $file).Length / 1MB, 1)

$sig = Get-AuthenticodeSignature -FilePath $file
$signer = ''
if ($sig.SignerCertificate) {
    $dn = $sig.SignerCertificate.SubjectName.Decode([Security.Cryptography.X509Certificates.X500DistinguishedNameFlags]'UseNewLines, DoNotUseQuotes')
    $orgs = @($dn -split "`r?`n" | Where-Object { $_ -like 'O=*' })
    if ($orgs.Count -eq 1) { $signer = $orgs[0].Substring(2) }
}
if ($sig.Status -ne 'Valid') { Stop-Script 1 "failed signature is $($sig.Status) (signer '$signer'), not run" }
if (-not ($p.Publisher -ccontains $signer)) { Stop-Script 1 "failed signed by '$signer', expected '$($p.Publisher -join "' or '")', not run" }
Write-Output "Signature valid: $signer ($size MB)"

# Not awaited: the person may take minutes, and elevation is the installer's own prompt. Started is not installed.
if ($mode -eq 'attended') {
    $start = @{ FilePath = $file; WorkingDirectory = $script:work; ErrorAction = 'Stop' }
    if ($kind -eq 'msi') {
        $start.FilePath = Join-Path $env:SystemRoot 'System32\msiexec.exe'
        $start.ArgumentList = "/i `"$file`""
    }
    Write-Output "Starting the $($p.Name) installer on the screen of $($me.Name)"
    try {
        Start-Process @start
    } catch {
        Stop-Script 1 "failed the installer did not start: $($_.Exception.Message)"
    }
    Write-Output "The installer stays in $script:work while it runs; delete the folder after the wizard"
    Write-Output 'Started is not installed: run this entry again after the wizard to confirm the installed version'
    $script:work = $null
    Stop-Script 0 "started $($p.Name) installer for $($me.Name); finish the wizard on the device"
}

$extra = ''
if ($p.License -and $licenseKey) { $extra = $p.License -f $licenseKey }
if ($kind -eq 'msi') {
    if (-not $p.Msi) { Stop-Script 3 "failed $($p.Name) expects an .exe installer" }
    $log = Join-Path $script:work 'msi.log'
    $argText = "/i `"$file`" /qn /norestart $($p.Msi -f $licenseKey, $packageId, $birthDate) $extra /l*v `"$log`""
    $exePath = Join-Path $env:SystemRoot 'System32\msiexec.exe'
} else {
    if (-not $p.Exe) { Stop-Script 3 "failed $($p.Name) expects an .msi installer" }
    $argText = "$($p.Exe -f $licenseKey, $packageId, $birthDate) $extra"
    $exePath = $file
}

Write-Output "Installing $($p.Name), timeout $timeoutText minutes"
$before = @(Get-Uninstall | ForEach-Object { $_.PSChildName })
$deadline = (Get-Date).AddMinutes([int]$timeoutText)
$proc = Start-Process -FilePath $exePath -ArgumentList $argText -WorkingDirectory $script:work -WindowStyle Hidden -PassThru
$null = $proc.Handle
if (-not $proc.WaitForExit([int]$timeoutText * 60000)) {
    $null = & "$env:SystemRoot\System32\taskkill.exe" /PID $proc.Id /T /F 2>&1
    Stop-Script 1 "failed installer did not finish within $timeoutText minutes and was stopped"
}
$code = $proc.ExitCode
$reboot = $code -in 3010, 1641
Write-Output "Installer exit code: $code"
if ($code -ne 0 -and -not $reboot -and $kind -eq 'msi' -and (Test-Path -LiteralPath $log)) {
    $lines = Get-Content -LiteralPath $log -ErrorAction SilentlyContinue |
        Where-Object { $_ -match 'error \d{4}|Return value 3' } | Select-Object -First 5
    foreach ($l in $lines) {
        if ($licenseKey) { $l = $l.Replace($licenseKey, '****') }
        Write-Output $l.Substring(0, [math]::Min(200, $l.Length))
    }
}
if ($code -eq 1618) { Stop-Script 1 'failed another installation is in progress, try again later' }

# Stub installers return while their setup child keeps running; wait for it, then up to 3 minutes for registration.
$grace = (Get-Date).AddMinutes(3)
$found = Get-Installed $p.Match
while (-not $found) {
    $busy = @(Get-CimInstance -ClassName Win32_Process -Filter "ParentProcessId=$($proc.Id)" -ErrorAction SilentlyContinue).Count
    if ($busy -and (Get-Date) -lt $deadline) {
        $grace = (Get-Date).AddMinutes(3)
    } elseif ((Get-Date) -gt $grace) { break }
    Start-Sleep -Seconds 10
    $found = Get-Installed $p.Match
}
if (-not $found) {
    $found = Get-Uninstall | Where-Object { $before -notcontains $_.PSChildName } | Select-Object -First 1
    if ($found) { Write-Output "Registered as '$($found.DisplayName)', not under the expected name" }
}
if (-not $found) { Stop-Script 1 "failed installer exit code $code and $($p.Name) is not registered" }
if ($reboot) { Write-Output 'A reboot is required to finish the installation' }
if ($code -ne 0 -and -not $reboot) { Write-Output "Installer reported $code but the product is registered" }
if (-not $p.License -or -not $licenseKey) { Write-Output 'Activation: open the product on the device or use the vendor console' }
Stop-Script 0 "installed $($found.DisplayName) $($found.DisplayVersion)"
