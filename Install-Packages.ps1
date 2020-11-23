#Requires -RunAsAdministrator

# This is to satisfy the proxy authentication request
$browser = New-Object System.Net.WebClient
$browser.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

if (!(Test-Path $PROFILE)) {
    New-Item $PROFILE -ItemType File -Force
}

# Install Chocolatey
if (!(Get-Package -Name *choco*)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

choco install adobereader -y --force
choco install firefox -y --force
choco install googlechrome -y --force
choco install 7zip -y --force
choco install notepadplusplus -y --force
choco install git -y --force
choco install github-desktop -y --force
choco install vscode -y --force
choco install greenshot -y --force
choco install slack -y --force
choco install flashplayerplugin -y --force
choco install vlc -y --force
choco install notepad2 -y --force
choco install paint.net -y --force
choco install zoom -y --force

# Programming Fonts
choco install anonymouspro -y --force
choco install sourcecodepro -y --force
choco install firacode -y --force
choco install hackfont -y --force

# Install Powershell 6
Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-powershell.ps1) } -UseMSI -AddToPath"
