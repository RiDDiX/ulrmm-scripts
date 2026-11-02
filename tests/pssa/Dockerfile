FROM mcr.microsoft.com/powershell:lts-7.4-debian-12
RUN pwsh -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module PSScriptAnalyzer -RequiredVersion 1.24.0 -Scope AllUsers"
