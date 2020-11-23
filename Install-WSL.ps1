# Enable the Windows Subsystem for Linux (WSL)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

$wslPath = "C:\WSL"
if (!(Test-Path -Path $wslPath)) {
    New-Item -Path $wslPath -ItemType Directory | Out-Null
}

# Download distros
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri https://aka.ms/wsl-ubuntu-1804 -OutFile "$wslPath\Ubuntu.appx" -UseBasicParsing
Invoke-WebRequest -Uri https://aka.ms/wsl-kali-linux -OutFile "$wslPath\Kali.appx" -UseBasicParsing

# Install distros
Set-Location -Path $wslPath
Add-AppxPackage -Path $wslPath/Ubuntu.appx
Add-AppxPackage -Path $wslPath/Kali.appx

RefreshEnv
Ubuntu1804 install --root
Ubuntu1804 run apt update
Ubuntu1804 run apt upgrade


# Install Boxstarter - https://boxstarter.org/
# System-level configuration
Disable-BingSearch
Disable-GameBarTips

Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -EnableShowProtectedOSFiles -EnableShowFileExtensions
Set-TaskbarOptions -Size Small -Dock Bottom -Combine Full -Lock
Set-TaskbarOptions -Size Small -Dock Bottom -Combine Full -AlwaysShowIconsOn
