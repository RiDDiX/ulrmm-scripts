# Antivirus scripts

What the antivirus scripts install and check, where each installer comes from, which switches they use and how far
each row has been verified. State of the research: 2026-10-06.

Running an install entry accepts the vendor's license agreement and privacy policy on that device. Use it only where
you may accept them and hold a valid license; free and home editions are often licensed for private use only.
`BIRTH_DATE` is personal data of the device user. The products named here are trademarks of their vendors, who are
not affiliated with this project.

Verification levels, from weakest to strongest:

- **documented by vendor**: the switches or commands come from the vendor's own documentation.
- **unconfirmed**: the switches come only from forums or third-party sites. The script uses them, but a failed run
  is possible. The installer timeout stops a hung installer.
- **URL confirmed**: the download URL answered with HTTP 200/206 on 2026-10-06 (with the redirect target noted).
- **signer confirmed**: the installer was downloaded (never run) and its signature read with `osslsigncode verify`
  (Windows) or from the xar table of contents of the package (macOS). For large Windows files only the certificate
  table was fetched with HTTP range requests and decoded with `openssl pkcs7`; that shows the signer, not that the
  file hash matches, which the script checks on the device.
- **executed in container**: the script ran for real in Linux containers.
- **not executed**: no Windows or macOS machine was available. The PowerShell scripts passed the parser and
  PSScriptAnalyzer (5.1 syntax and command compatibility), and the macOS scripts passed shellcheck and `bash 3.2 -n`.
  None of them has run on a real system yet.

Every installer script refuses to run a download that is not signed by the expected publisher. On Windows the
signature must be `Valid` and the organization (O) of the signer certificate must equal the expected publisher
exactly, so a look-alike name such as `ESET, spol. s r.o. Ltd` is refused. On macOS the package needs a Developer ID Installer
certificate with the expected Team ID and must pass a Gatekeeper assessment. On Linux the download must match a
sha256 or come from the distribution's signed repositories. A vendor URL that changes owner or content therefore
stops the install instead of running something else.

## Windows

`win_antivirus_install.ps1` is one engine with a table per product, selected with `PRODUCT`. It works like this:

1. If the product is already registered, the script reports the installed version and exits 0.
2. It refuses when another third-party antivirus is active. It reads Security Center (`root/SecurityCenter2`) and
   falls back to the uninstall keys on Server editions. `ALLOW_EXISTING` overrides this. Only names starting with
   `Windows Defender` or `Microsoft Defender` are skipped, so Defender never blocks and Bitdefender still counts.
3. It downloads over TLS 1.2+ into `%SystemRoot%\Temp\ulrmm-av-<guid>`. That directory is created with an ACL that
   lets only SYSTEM and Administrators write. Redirects are followed by the script, and a hop to anything but https
   stops the download.
4. It reads the file type (.exe or .msi) from the file header, not from the URL, then checks the Authenticode
   signature and the signer organization.
5. It runs the installer hidden with `Start-Process -PassThru` (not `-Wait`, which in Windows PowerShell 5.1 also waits
   for every process the installer leaves running) and kills the whole process tree after `TIMEOUT_MINUTES`. MSI
   packages run through `msiexec /qn /norestart` with a verbose log in the working directory.
6. It maps exit code 3010/1641 to "reboot required".
7. It waits while child processes of the installer still run (up to `TIMEOUT_MINUTES`), then up to 3 more minutes for
   the product to appear in the uninstall keys. If the expected name never appears but a new uninstall entry does, it
   reports that entry instead of failing. Then it cleans up.
8. The last line is `RESULT: installed <product> <version>` or `RESULT: failed <reason>`.

`LICENSE_KEY` and `INSTALLER_URL` are optional, except that both Kaspersky products need `INSTALLER_URL` and
`kaspersky-home` also needs `BIRTH_DATE`. `INSTALLER_URL` must be https, and an installer from it goes through
the same signer check. The license key is never printed, and it is masked in the msiexec log lines the script shows
on failure.

`MODE=attended` is a second mode of the same engine for home products that have no documented silent install. A
product lists the modes it supports: `bitdefender-total-security` is attended only, `eset-home` supports both, all
others are silent only. Any other combination ends with exit 3. In attended mode:

- The manifest entries run as the signed-in user, so the agent starts the script in that user's session. The script
  refuses with exit 3 when it runs as SYSTEM (the agent falls back to SYSTEM when nobody is signed in) or in session 0,
  because a wizard there is invisible and hangs.
- Steps 1 to 4 are the same except for the working directory: already installed means exit 0, another active
  antivirus means exit 3 unless `ALLOW_EXISTING` is set, and the download goes through the same https-only redirect
  handling and the same check of a `Valid` signature and the exact signer organization before anything starts.
- The working directory is a new `ulrmm-av-<guid>` folder in the user's own temp folder. The SYSTEM-only folder of the
  silent mode is not writable for the user, and here the same account downloads, checks and starts the file.
- It starts the installer visibly without switches (an .msi with `msiexec /i`) and does not wait for it, because the
  person may take minutes. Elevation is the installer's own UAC prompt, so the account needs administrator rights or
  an administrator's password. If Windows reports an error when starting it, the result is failed and the folder is
  removed. Otherwise the folder is left for the running installer and the output says where it is.
- The last line is `RESULT: started <product> installer for <user>; finish the wizard on the device`. Exit 0 means
  started, not installed: run the entry again after the wizard, and it reports the installed version.
- `LICENSE_KEY` is ignored (the output says so and never prints it) and `TIMEOUT_MINUTES` is not used. Activation
  happens in the product.

| Product and edition | Installer source | Switches used | Licensing / activation | Publisher checked | Evidence | Verification level | Limits and manual steps |
|---|---|---|---|---|---|---|---|
| ESET HOME Security (Essential, Premium, Ultimate) and ESET NOD32 Antivirus (`eset-home`) | `https://download.eset.com/com/eset/apps/home/eav/windows/latest/eav_nt64.exe`, full offline installer, 85.6 MB | `--silent --accepteula` | Not documented for the command line. ESET HOME account is mandatory for subscriptions bought after 15 November 2023 (KB3419); activate in the product | `ESET, spol. s r.o.` | Switches: forum only, https://forum.eset.com/topic/19950-silent-installation-essp/ (not readable from here, HTTP 403). ESET's offline installation help describes the wizard only: https://help.eset.com/eis/19/en-US/installation_offline.html | URL confirmed, signer confirmed (O and CN `ESET, spol. s r.o.`, 2026-10-06), switches unconfirmed, not executed | One installer for all home tiers; the license decides the tier. Client Windows only. The registered DisplayName pattern was not checked against a real install |
| ESET HOME Security and NOD32, attended (`eset-home`, `MODE=attended`) | Same installer as above, or the activated installer from ESET HOME through `INSTALLER_URL` | None. ESET's wizard runs visibly in the session of the signed-in user | The person signs in with the ESET HOME account in the wizard or the product | `ESET, spol. s r.o.` | KB3419 (installer and activation through ESET HOME), https://help.eset.com/eis/19/en-US/installation_offline.html (the wizard) | URL confirmed, signer confirmed, mode checks run under PowerShell 7 on Linux with the Windows calls replaced by stand-ins, not executed on Windows | Needs a signed-in user and administrator rights or an administrator's password for the elevation prompt. Client Windows only. Started is not installed: run the entry again to confirm |
| ESET Endpoint Antivirus (`eset-endpoint-antivirus`) | `https://download.eset.com/com/eset/apps/business/eea/windows/latest/eea_nt64.msi`, full MSI | `msiexec /i ... /qn /norestart ACTIVATION_DLG_SUPPRESS=1 [ACTIVATION_DATA=key:<key>]` | `ACTIVATION_DATA=key:` with `LICENSE_KEY`, or ESET PROTECT | `ESET, spol. s r.o.` | https://help.eset.com/eea/11/en-US/installation_command_line.html | Documented by vendor, URL confirmed, signer confirmed, not executed | Policy and management come from ESET PROTECT through the ESET Management Agent, which these scripts do not install |
| ESET Endpoint Security (`eset-endpoint-security`) | `https://download.eset.com/com/eset/apps/business/ees/windows/latest/ees_nt64.msi` | as above | as above | `ESET, spol. s r.o.` | as above | Documented by vendor, URL confirmed, signer not checked (same vendor certificate expected), not executed | as above |
| Bitdefender GravityZone security agent (BEST) (`bitdefender-gravityzone`) | `https://download.bitdefender.com/SMB/Hydra/release/bst_win/downloaderWrapper/BEST_downloaderWrapper.msi`, MSI wrapper that downloads the company package | `msiexec /i ... /qn /norestart GZ_PACKAGE_ID="<id>"` | License and policy come from the GravityZone package, so no key | `Bitdefender SRL` | https://www.bitdefender.com/site/KnowledgeBase/viewarticle2012/1695 | Documented by vendor, URL confirmed, signer confirmed, not executed | `GZ_PACKAGE_ID` is the text in brackets of `setupdownloader_[...].exe` from Network > Packages. `REBOOT_IF_NEEDED` is not set, so the agent does not reboot on its own. The DisplayName `Bitdefender Endpoint Security Tools` is not confirmed |
| Bitdefender Total Security, attended only (`bitdefender-total-security`, `MODE=attended`) | `https://download.bitdefender.com/windows/desktop/connect/cl/2023/all/bitdefender_ts_27_64b.exe`, full offline kit, 888.7 MB, linked on Bitdefender's community forum, no support article | None. Bitdefender's wizard runs visibly in the session of the signed-in user | The person signs in to Bitdefender Central in the product, which validates the subscription | `Bitdefender SRL` | https://www.bitdefender.com/consumer/support/answer/28558/ (install and subscription through Central); kit link: https://community.bitdefender.com/en/discussion/104199/bitdefender-total-security-latest-offline-installer-download | URL confirmed (HEAD again on 2026-10-06: HTTP 200, 888671128 bytes, last modified 14 September 2026), signer confirmed (O `Bitdefender SRL`, certificate table read), mode checks run under PowerShell 7 on Linux with the Windows calls replaced by stand-ins, not executed on Windows | Needs a signed-in user and administrator rights or an administrator's password for the elevation prompt. Client Windows only. Started is not installed: run the entry again to confirm. The DisplayName `Bitdefender Total Security` is not confirmed. No silent mode, see below |
| Kaspersky Endpoint Security for Windows (`kaspersky-endpoint`) | No public direct URL. You host the distribution kit and pass `INSTALLER_URL` | exe: `/s /pEULA=1 /pPRIVACYPOLICY=1 /pKSN=0 /pSKIPPRODUCTCHECK=1`; msi: `/qn /norestart EULA=1 PRIVACYPOLICY=1` | No documented key switch. Use a `setup.ini` in the kit or Kaspersky Security Center; otherwise a trial runs | `AO Kaspersky Lab` or `Kaspersky Lab JSC` | https://support.kaspersky.com/KESWIN/12.8/en-US/123468.htm | Documented by vendor, signer not checked (no download), not executed | The expected signer name is not confirmed for this kit (`AO Kaspersky Lab` signs Kaspersky's current KVRT tool). If the check refuses a genuine kit, the signer is reported in the output |
| Kaspersky Standard, Plus, Premium (`kaspersky-home`) | No public full installer. You host it and pass `INSTALLER_URL` | `/s /mybirthdate=<BIRTH_DATE> /pAGREETOEULA=1 /pAGREETOPRIVACYPOLICY=1`, plus `/pACTIVATIONCODE=<key>` | `ACTIVATIONCODE` from `LICENSE_KEY`; empty leaves activation to the user | `AO Kaspersky Lab` | https://support.kaspersky.com/kaspersky-for-windows/21.27/43538 (help for "Kaspersky Standard \| Plus \| Premium" 21.27, dated September 2026) | Switches documented by vendor. Signer: the installer could not be downloaded; `AO Kaspersky Lab` is the signer of Kaspersky's current home tool KVRT (certificate table read). Not executed | Kaspersky marks `/mybirthdate` as required for a non-interactive install and refuses users under 16. The help names one package (`saas21.exe`) for all three tiers. The web installer from kaspersky.com was not tested with these switches. The DisplayName pattern is not confirmed |
| Avast Free Antivirus (`avast-free`) | `https://files.avast.com/iavs9x/avast_free_antivirus_setup_offline.exe`, full offline installer, about 1 GB (redirects to `s-iavs9x.avcdn.net`) | `/silent` | Free edition needs no key. Premium Security is activated in the product | `Gen Digital Inc.` | Avast documents `/silent` only for business products: https://businesshelp.avast.com/Content/Products/AfB_Antivirus/AntivirusManagement/SilentAVInstallation.htm ; for the free edition only https://silentinstallhq.com/avast-free-antivirus-silent-install-how-to-guide/ | URL confirmed, signer confirmed on the offline installer (`Gen Digital Inc.`, certificate table read), switch unconfirmed, not executed | Client Windows only |
| AVG AntiVirus Free (`avg-free`) | `https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_WIN_AVG/installertype_FULL/build_RELEASE/cookie_mmm_bav_998_999_000_m?alt=en-us`, full offline installer, about 1.1 GB, linked from https://www.avg.com/en-us/installation-files-prd-gsr-free | `/silent` | Free edition needs no key | `Gen Digital Inc.` | `/silent` is documented only for AVG business products (same installer engine as Avast) | URL confirmed, signer confirmed on the offline installer (`Gen Digital Inc.`, certificate table read), switch unconfirmed, not executed | Client Windows only |
| Malwarebytes for Windows (`malwarebytes`) | `https://downloads.malwarebytes.com/file/mb-windows` (redirects to `data-cdn.mbamupdates.com/.../MBSetup.exe`), online installer | `/VERYSILENT /NORESTART` | No key switch found. Starts as free/trial and is activated in the product | `Malwarebytes Inc` | https://silentinstallhq.com/malwarebytes-silent-install-how-to-guide/ (the vendor help centre could not be read from here) | URL confirmed, signer confirmed, switches unconfirmed, not executed | Client Windows only. The business product (ThreatDown) has its own installer and is not covered |

Other Windows scripts:

| Script | What it does | Evidence | Verification level |
|---|---|---|---|
| `win_antivirus_status.ps1` | Lists Security Center antivirus products with on/off and signature state. On Server it falls back to `Get-MpComputerStatus` and the uninstall keys | `productState` is not documented by Microsoft. The script uses the widely used decoding: byte 2 `0x10` means on, byte 3 `0x10` means out of date | not executed |
| `win_antivirus_defender_status.ps1` | `Get-MpComputerStatus`: engine, real-time protection, signature age. Passes when another antivirus is the active one | Defender module cmdlet reference, https://learn.microsoft.com/powershell/module/defender/ | documented by vendor, not executed |
| `win_antivirus_defender_update.ps1` | `Update-MpSignature`, with `MpCmdRun.exe -SignatureUpdate` as fallback | as above | documented by vendor, not executed |
| `win_antivirus_defender_scan.ps1` | `Start-MpScan` quick, full or custom, then the new entries from `Get-MpThreatDetection` | as above | documented by vendor, not executed |
| `win_antivirus_defender_enable.ps1` | `Set-MpPreference`: real-time, behavior, download and script scanning on, block at first sight on, MAPS advanced, send safe samples. It keeps exclusions, reports Group Policy values instead of overwriting them, and refuses while another antivirus is active | as above | documented by vendor, not executed |
| `win_antivirus_eset_scan.ps1` | `ecls.exe /base-dir=... /log-file=... <path or /auto>` with ESET's documented exit codes 0, 1, 10, 50, 100 | https://support.eset.com/en/kb3417-eset-command-line-scanner-parameters-eclsexe-5x-and-later, https://help.eset.com/eea/11/en-US/advanced_cmd.html | documented by vendor, not executed. The log line filter is a best guess at the log format |

Kaspersky documents `avp.com SCAN` and `avp.com UPDATE` for Kaspersky Endpoint Security
(https://support.kaspersky.com/KESWin/12.4/en-US/141652.htm). There is no script for them because their exit codes
were not found.

## Linux

| Product and edition | Installer source | Switches used | Licensing / activation | Publisher checked | Evidence | Verification level | Limits and manual steps |
|---|---|---|---|---|---|---|---|
| ClamAV (`linux_antivirus_clamav_install.sh`, `_update`, `_scan`, `_status`) | Distribution repositories: apt-get, dnf/yum (EPEL on the RHEL family, added when `ENABLE_EPEL` is true), zypper, pacman, apk | Package install. `freshclam` once in the foreground, then the `clamav-freshclam` / `freshclam` systemd unit or the OpenRC service is enabled. An `Example` line in `freshclam.conf` is commented out | Free | Package manager signatures | https://docs.clamav.net/manual/Installing/Packages.html | Executed in container on Debian 13, Ubuntu 24.04, AlmaLinux 9 (EPEL), Fedora 44, openSUSE Leap 15.6, Arch and Alpine 3.22: install twice (idempotent), update, status, EICAR scan with and without exclusions, bad input. On a Debian 13 container booted with systemd the freshclam unit was enabled, paused for the update and seen by the status check | OpenRC service handling and Tumbleweed were not run. Without a running service manager the script says so and the status check warns. On Arch the script does not refresh the package databases (no partial upgrades); with stale databases it fails and asks for `pacman -Syu`. The scan only reports and never deletes or moves files |
| ESET Endpoint Antivirus for Linux (`linux_antivirus_eset_install.sh`, `PRODUCT=endpoint-antivirus`) | `eeau.x86_64.bin` from ESET's download page. No stable direct URL was found, so `INSTALLER_URL` and `INSTALLER_SHA256` are required | `sh eeau.x86_64.bin -y -f`, then `/opt/eset/eea/sbin/lic -k <key>` | `LICENSE_KEY`, or ESET PROTECT | sha256 given by the admin | https://help.eset.com/eeau/12.2/en-US/installation.html, https://support.eset.com/en/kb8759-download-install-and-activate-eset-endpoint-antivirus-for-linux | Documented by vendor, input checks executed in container, install not executed | x86_64 builds only. A new ESET release needs a new sha256 |
| ESET Server Security for Linux (`PRODUCT=server-security`) | `https://download.eset.com/com/eset/apps/business/efs/linux/latest/efs.x86_64.bin` (267.6 MB) or `INSTALLER_URL` | `-y -f`, then `/opt/eset/efs/sbin/lic -k <key>` | `LICENSE_KEY`, web interface or ESET PROTECT | sha256 given by the admin | https://support.eset.com/en/kb2283-download-and-install-eset-server-security-for-linux | URL confirmed. `-y -f` and the `lic` path are documented for the endpoint product only and assumed here (unconfirmed); not executed | Because the URL always points at the latest build, the sha256 must be updated after each ESET release |

Not covered on Linux:

- **Bitdefender GravityZone for Linux**: the kit comes from the console and is run with `./installer`. No silent
  switch is documented (https://www.bitdefender.com/site/KnowledgeBase/viewarticle2012/2319/).
- **Kaspersky Endpoint Security for Linux**: it can run unattended. Install the package, then run
  `kesl-setup.pl --autoinstall=<file>` with `EULA_AGREED=yes`, `PRIVACY_POLICY_AGREED=yes` and `INSTALL_LICENSE=`
  (https://support.kaspersky.com/kes4linux/11.2.0/en-US/205723.htm). There is no public download URL, though, and the
  12.x pages were not checked, so there is no script.

## macOS

`mac_antivirus_install.sh` follows these steps:

1. Downloads over https only, including redirects.
2. Mounts a disk image read-only and installs the package from the mounted volume, because some vendors keep side
   files next to it.
3. Requires `pkgutil --check-signature` to show a Developer ID Installer certificate whose Team ID matches.
4. Requires `spctl --assess --type install` to accept the package.
5. Runs `installer -pkg ... -target /` and checks the package receipt.
6. Refuses when another vendor's antivirus system extension is active, unless `ALLOW_EXISTING` is set.

**Root cannot approve system extensions, network filters or Full Disk Access.** Those approvals need the user at the
Mac or an MDM profile (system extension policy, PPPC and content filter payloads) installed before the package. Until
then the product is installed but does not protect. The script prints the approvals each product needs.

| Product and edition | Installer source | Switches used | Licensing / activation | Publisher checked (Team ID) | Evidence | Verification level | Limits and manual steps |
|---|---|---|---|---|---|---|---|
| Microsoft Defender for Endpoint (`defender`) | `https://go.microsoft.com/fwlink/?linkid=2097502` (wdav.pkg, 475 MB) | `installer -pkg wdav.pkg -target /` | Needs the tenant onboarding profile `WindowsDefenderATPOnboarding.mobileconfig` and a Defender for Endpoint license | Microsoft Corporation (UBF8T346G9) | https://learn.microsoft.com/en-us/defender-endpoint/mac-install-manually, https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-endpoint-mac-prerequisites | Documented by vendor, URL confirmed, signer confirmed, not executed | System extensions `com.microsoft.wdav.epsext` and `.netext`, plus Full Disk Access, through MDM |
| Malwarebytes for Mac (`malwarebytes`) | `https://downloads.malwarebytes.com/file/mb-mac` (pkg, 122 MB) | `installer -pkg` | Activate in the product | Malwarebytes Corporation (GVZRY6KDKR) | Team ID read from the package certificate | URL confirmed, signer confirmed, not executed | Full Disk Access for the protection daemon, plus a system extension for web protection |
| Avast Security for Mac (`avast`) | `https://www.avast.com/en-us/download-thank-you.php?product=MAC-FREE-ONLINE&direct=1`, online dmg with `Install Avast Security.pkg` and `config.tar` | `installer -pkg` from the mounted volume | Free edition needs no key | AVAST Software a.s. (6H4HRTU5E3) | https://businesshelp.avast.com/Content/Products/AfB_Management_Consoles/DeviceManagement/DeployingonMacOSwithJamf.htm (business: mount the dmg, run the pkg) | URL confirmed, signer confirmed, not executed | Downloads the product while it installs. System extension, Full Disk Access and content filter |
| AVG AntiVirus for Mac (`avg`) | `https://bits.avcdn.net/productfamily_ANTIVIRUS/insttype_FREE/platform_MAC_AVG/installertype_ONLINE/build_RELEASE`, online dmg | `installer -pkg` from the mounted volume | Free | AVG Technologies CZ, s.r.o. (XSJ59WMJBM) | URL built from the CDN pattern of the Avast link; not published on an AVG page that was found | URL confirmed (unconfirmed as a supported URL), signer confirmed, not executed | Approvals as for Avast (assumed) |
| ESET Endpoint Security for macOS (`eset-endpoint`) | `https://download.eset.com/com/eset/apps/business/ees/mac/g2/latest/ees_osx.dmg` (713 MB) | `installer -pkg` on the package found in the dmg | ESET PROTECT, or entered in the product | ESET, spol. s r.o. (P8DQRXPVLP) | https://help.eset.com/ees_mac/8/en-US/install_local_terminal.html, https://help.eset.com/ees_mac/8/en-US/install_remote_pre-installation_jamf.html | URL confirmed. Signer confirmed on the older (2023) build only; the layout of the current g2 dmg and its receipts were not inspected; not executed | ESET states the product cannot be fully installed remotely without MDM enrollment. Ready-made payload: https://download.eset.com/com/eset/config/enable_all_unmanaged/ees/mac/latest/ESET_enable_all.plist |
| ClamAV (`clamav`) | Latest `clamav-<version>.macos.universal.pkg` from the Cisco Talos GitHub releases | `installer -pkg` | Free | Cisco (DE8Y96K9QP) | https://github.com/Cisco-Talos/clamav/releases | URL confirmed, signer confirmed, not executed | On-demand scanner only. The install path `/usr/local/clamav` is not confirmed. The script creates `freshclam.conf` from the sample if the sample is there. Run `freshclam` before the first scan |

`mac_antivirus_status.sh` is read-only. It checks:

- Gatekeeper with `spctl --status`.
- SIP with `csrutil status`.
- The XProtect version and age: `xprotect version` on macOS 15+, otherwise the bundle's `Info.plist`. The age comes
  from the bundle's modification time. On macOS 15+ the active bundle is under `/var/protected/xprotect`.
- Active antivirus system extensions, from `systemextensionsctl list`.

Apple's overview is at https://support.apple.com/guide/security/protecting-against-malware-sec469d47bd8/web. The
`xprotect` tool and the `/var/protected` location are described only by third parties
(https://eclecticlight.co/2024/10/10/a-simple-guide-to-how-xprotect-installs-and-updates-in-sequoia/). Not executed.

## Not possible or only partly possible unattended

- **Bitdefender Total Security, Internet Security, Antivirus Plus (home): unattended no; Total Security attended from
  the RMM yes.**
  - Bitdefender's own install article installs from Bitdefender Central and says: "The product you install will
    validate its subscription from your account"
    (https://www.bitdefender.com/consumer/support/answer/28558/). Documented by vendor.
  - A full offline kit for Total Security is on Bitdefender's download server:
    https://download.bitdefender.com/windows/desktop/connect/cl/2023/all/bitdefender_ts_27_64b.exe (888.7 MB, last
    modified 14 September 2026, signer O `Bitdefender SRL`, certificate table read). The link is posted on Bitdefender's
    community forum (https://community.bitdefender.com/en/discussion/104199/bitdefender-total-security-latest-offline-installer-download).
    No Bitdefender support article for it was found. The same path has no kit for Internet Security or Antivirus Plus
    (HTTP 404). URL confirmed, again with HEAD on 2026-10-06.
  - Unattended: no. Bitdefender documents no silent switch for its home products, and the subscription is validated
    only after a sign-in to Bitdefender Central. The only forum answer gives `/silent` for the 2012
    `setupdownloader.exe` (https://community.bitdefender.com/en/discussion/28089/resolved-silent-installation).
    That is unconfirmed for the current kit and not used.
  - Attended from the RMM: yes, for Total Security with "Bitdefender Total Security - start installer (attended)"
    (`MODE=attended`, see Windows above). The RMM downloads the kit, checks the signer and starts Bitdefender's wizard
    on the screen of the signed-in user. The person at the device then accepts the elevation prompt (administrator
    rights or an administrator's password), clicks through the wizard and signs in to Bitdefender Central. Run the
    entry again afterwards to confirm the installed version. Not executed on Windows yet.
  - Internet Security and Antivirus Plus: install by hand from Bitdefender Central, or use GravityZone.
- **Kaspersky Standard, Plus, Premium (home): silent switches documented, no public full installer.**
  - Kaspersky's help for the current line documents the command-line install
    (https://support.kaspersky.com/kaspersky-for-windows/21.27/43538). It lists `/s` ("Non-interactive (silent)
    mode"), `/mybirthdate=YYYY-MM-DD` ("Required for non-interactive installation"), `/l`, `/t`, `/p<property>=<value>`
    and `/x`. The properties are `ACTIVATIONCODE=<value>`, `AGREETOEULA=1`, `AGREETOPRIVACYPOLICY=1`,
    `JOINKSN_ENHANCE_PROTECTION=1`, `JOINKSN_MARKETING=1`, `INSTALLDIR`, `KLPASSWD`, `KLPASSWDAREA`,
    `SELFPROTECTION=1`, `ALLOWREBOOT=1`, `SKIPPRODUCTCHECK=1`, `OEM_BACKUP_MODE=1` (its example spells it `OEM_BACK_MODE`),
    `AGREE_TO_MYKASPERSKY_FEATURES=1` and `SETUPREG`. A similar table, with `/s`, `/mybirthdate`, `AGREETOEULA`,
    `AGREETOPRIVACYPOLICY` and `ACTIVATIONCODE` but without the last two, is in the help for the last KTS/KAV generation:
    https://support.kaspersky.com/us/kts21/install/15413 and https://support.kaspersky.com/us/kav21/install/15407.
    Documented by vendor.
  - The installer is the gap. Kaspersky's download article
    (https://support.kaspersky.com/us/common/beforeinstall/6104) points to https://www.kaspersky.com/downloads, which
    builds the download link in a script (not resolved here). It also points to https://products.s.kaspersky-labs.com/
    for earlier versions, but that archive lists only 2019 and older products. One example is KTS 19.0.0.1088, a full
    175 MB installer signed by O `Kaspersky Lab`. On Kaspersky's forum, staff say there is no public offline installer
    for the current versions and that support can provide one
    (https://forum.kaspersky.com/topic/need-url-to-download-kaspersky-premium-offline-installer-49377/).
  - The `kaspersky-home` entry uses the documented switches with an installer you host. Kaspersky products are no
    longer sold or updated in the United States (U.S. Department of Commerce, Bureau of Industry and Security, final
    determination of 20 June 2024). On 15 March 2022 the German Federal Office for Information Security (BSI) warned
    against Kaspersky antivirus products and recommended replacing them. Its FAQ lists the warning as still in force
    (https://www.bsi.bund.de/DE/Themen/Unternehmen-und-Organisationen/Cyber-Sicherheitslage/Technische-Sicherheitshinweise-und-Warnungen/Warnungen-nach-Par-13/FAQ-Kaspersky/faq-kaspersky.html).
- **ESET HOME Security, NOD32 (home): installs with unconfirmed switches, activation needs a person.**
  - No command-line parameter for the home products was found in ESET's online help or Knowledgebase. The offline
    installation topic describes the wizard only (https://help.eset.com/eis/19/en-US/installation_offline.html). The
    "ESET CMD" topic of the home help is the command-line scanner (https://help.eset.com/eav/19/en-US/advanced_cmd.html).
  - KB3419 (https://support.eset.com/en/kb3419-download-and-install-eset-home-security-products-for-windows, updated
    14 September 2026) says: "ESET HOME account is mandatory for installation for all subscriptions purchased after
    November 15, 2023". It downloads an "activated installer file from ESET HOME".
  - `--silent --accepteula` therefore stay unconfirmed (forum only), and activation happens in the product or in
    ESET HOME.
  - Attended from the RMM: "ESET HOME Security and NOD32 - start installer (attended)" starts ESET's wizard on the
    screen of the signed-in user without any switch. The person accepts the elevation prompt and activates with the
    ESET HOME account. Not executed on Windows yet.
- **Norton 360, McAfee Total Protection / LiveSafe, Trend Micro Maximum / Internet Security, F-Secure TOTAL / SAFE,
  Sophos Home:** installers come from the customer account after sign-in, and the vendors document only the
  interactive setup. McAfee's removal tool MCPR is GUI-only in current versions. Norton's Remove and Reinstall tool is
  also GUI-only (https://support.norton.com/sp/en/us/home/current/solutions/v60392881). Trend Micro:
  https://helpcenter.trendlife.com/en-us/article/TMKA-09732/. For RMM use, install these by hand, or move to the
  vendor's business line. Those have documented silent installers, but each needs that vendor's console:
  Sophos Central `SophosSetup.exe --quiet`
  (https://docs.sophos.com/central/customer/help/en-us/PeopleAndDevices/ProtectDevices/CentralWindowsCommandLineOptions/index.html),
  WithSecure Elements MSI (https://support.withsecure.com/en/quick-start/elements-endpoint-protection/), and Trend
  Micro Apex One. None of them is scripted here.
- **G DATA (Antivirus, Internet Security, Total Security):** the consumer installer is an online stub with no
  documented silent mode. The business client takes `/_QuietInstallation="true"`, but it needs a G DATA Management
  Server
  (https://www.gdata.de/help-en/business/Configuration/Knowledgebase/CrucialConfigInformation/SetupParamenter/).
  When checked on 2026-10-06, its signature chained to a private G DATA root that is not in public trust stores.
- **Avira Free Security / Antivirus Pro:** online stub. The product is bound to an Avira account after install, and
  Avira does not document a silent switch.
- **ESET Cyber Security (macOS home), Bitdefender, Kaspersky, Sophos Home and Norton for Mac:** account-bound
  downloads. GravityZone and Kaspersky Endpoint for Mac use their own console-built packages.
- **Avast Premium Security, AVG Internet Security, ESET HOME, Malwarebytes Premium:** they install unattended as
  described above, but the paid license is activated in the product.
- **Workaround for any account-bound Windows installer:** download it once yourself and pass it through
  `INSTALLER_URL` of the matching product, or ship it as a software package of the RMM. The signer check still
  applies, and activation still happens in the product.
