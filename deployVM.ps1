##################################################################
#
# Perform post-deploy tasks on Windows servers
#
##################################################################

$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"

Remove-Item "C:\DeployLog_*" | Out-Null
Remove-Item "C:\DeployTranscript_*" | Out-Null

$logfile = "C:\DeployLog_$(get-date -format `"yyyymmdd_hhmm`").txt"
$tracefile = "C:\DeployTranscript_$(get-date -format `"yyyymmdd_hhmm`").txt"
Start-Transcript -path $tracefile

$delimiter = "-----------------------------------------"

# http://sharepointjack.com/2013/simple-powershell-script-logging/
function log($String, $Color) {
    if ($Color -eq $null) {$Color = "White"}
    Write-Host $String -ForegroundColor $Color
    $String | Out-File -Filepath $logfile -append
}

Log "Deploy started @ $(get-date -format `"yyyy-mm-dd hh:mm`")`n" Green

# Check if running as administrator
$windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($windowsIdentity)
$windowsAdminBuiltIn = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$isAdmin = $windowsPrincipal.IsInRole($windowsAdminBuiltIn)

if ( -not $isAdmin ) {
    log "Script is not running as administrator. Please re-run as admin" Red
    exit
}

# check the version from the PowerShell
$PSVersion = $PSVersionTable.PSVersion
Log "PowerShell Version: $PSVersion"
Log $delimiter

Rename-Computer WIN2012R2

$IP = "192.168.1.50"
$MaskBits = 24 # This means subnet mask = 255.255.255.0
$Gateway = "192.168.1.1"
$Dns = "192.168.1.1"
$IPType = "IPv4"

# Retrieve the network adapter that you want to configure
$adapter = Get-NetAdapter | ? {$_.Status -eq "Up"}

# Remove any existing IP, gateway from our ipv4 adapter
If (($adapter | Get-NetIPConfiguration).IPv4Address.IPAddress) {
    $adapter | Remove-NetIPAddress -AddressFamily $IPType -Confirm:$false
}

If (($adapter | Get-NetIPConfiguration).Ipv4DefaultGateway) {
    $adapter | Remove-NetRoute -AddressFamily $IPType -Confirm:$false
}

# Configure the IP address and default gateway
$adapter | New-NetIPAddress `
    -AddressFamily $IPType `
    -IPAddress $IP `
    -PrefixLength $MaskBits `
    -DefaultGateway $Gateway

# Configure the DNS client server IP addresses
$adapter | Set-DnsClientServerAddress -ServerAddresses $DNS

# DoNotOpenServerManagerAtLogon
New-ItemProperty -Path HKCU:\Software\Microsoft\ServerManager -Name DoNotOpenServerManagerAtLogon -PropertyType DWORD -Value "0x1" -Force

# Make initial connection to the Internet
Log "Establish initial connection to the Internet..."
if (Get-Process 'iexplore' -ErrorAction SilentlyContinue) {Stop-Process -Name iexplore}
Start-Sleep -s 5
$browser = new-object -com "InternetExplorer.Application"
$browser.navigate("www.google.com")
# Often times the proxy will need to have successfully established a connection
# before the Windows activation will work properly
while ($browser.ReadyState -ne 4) {Start-Sleep -m 100}

$NPIsInstalled = $false
$SWArray = @()
$SWArray += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
$SWArray += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
$SWArray | foreach {if ($_.DisplayName -match "Notepad\+\+") {
        $NPIsInstalled = $true
        $NPVer = $_.DisplayVersion
    }
}

if ($NPIsInstalled -match "True") {
    log "Notepad++ version $NPVer is already installed."
} else {
    log "Notepad++ version $NPVer will be downloaded and installed."
    # Configure Domain to scrape
    $Domain = "https://notepad-plus-plus.org"
    $AppendToDomain = "/download"

    # build URL to scan
    $SiteToScan = $Domain + $AppendToDomain

    # Scan URL to download file
    $url = ((Invoke-WebRequest -uri $SiteToScan).links | Where innerHTML -like "*Notepad++ Installer*").href

    # Build URL to download file
    $DownloadNotePad = $Domain + $url

    Start-BitsTransfer -Source $DownloadNotePad -DisplayName Notepad -Destination "npp.exe"

    # Close all IE processes
    if (Get-Process 'iexplore' -ErrorAction SilentlyContinue) {Stop-Process -Name iexplore}

    # Install silently
    Start-Process -FilePath npp.exe -ArgumentList '/S'  -Wait -Verb RunAs
    log "Notepad++ has been installed." Green
}
Remove-Item "C:\Temp\npp.exe" -ErrorAction SilentlyContinue | Out-Null
Log $delimiter

# Display computer details
$details = (Get-WmiObject Win32_ComputerSystem)
$myDetStr = $details | Out-String
Log "Computer details:`n$myDetStr"
Log $delimiter

$hostname = (get-WmiObject win32_computersystem).Name.ToUpper()
$cpuinfo = "numberOfCores", "NumberOfLogicalProcessors", "maxclockspeed", "addressWidth"
$cpudata = (Get-WmiObject -class win32_processor -computername $hostname -Property $cpuinfo | Select-Object -Property $cpuinfo)
$cpudataStr = $cpudata | Format-List | Out-String
Log "CPU Info:`n$cpudataStr"
Log $delimiter

$mem = (get-wmiobject Win32_ComputerSystem -cn $hostname | select @{name = "PhysicalMemory"; Expression = {"{0:N2}" -f ($_.TotalPhysicalMemory / 1gb).tostring("N0")}}, NumberOfProcessors, Name, Model)
$memStr = $mem | Format-List | Out-String
Log "Mem Info:`n$memStr"
Log $delimiter

# Get details about fixed drives
$fixed_drives = (Get-WMIObject Win32_LogicalDisk -filter "DriveType=3" -Computer $hostname | Select SystemName, DeviceID, VolumeName, FileSystem, @{Name = "size(GB)"; Expression = {"{0:N1}" -f ($_.size / 1gb)}}, @{Name = "freespace(GB)"; Expression = {"{0:N1}" -f ($_.freespace / 1gb)}})
$fixedDrivesStr = $fixed_drives | Out-String
Log "Fixed Drives:`n$fixedDrivesStr"
Log $delimiter

# Get network configuration
$Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -EA Stop | ? {$_.IPEnabled}
foreach ($Network in $Networks) {
    $IPAddress = $Network.IpAddress[0]
    $SubnetMask = $Network.IPSubnet[0]
    $DefaultGateway = $Network.DefaultIPGateway
    $DNSServers = $Network.DNSServerSearchOrder
    $IsDHCPEnabled = $false
    If ($network.DHCPEnabled) {
        $IsDHCPEnabled = $true
    }
    $MACAddress = $Network.MACAddress
}
log "Network configuration:"
log "   IP:            $($IPAddress)"
log "   Netmask:       $($SubnetMask)"
log "   Gateway:       $($DefaultGateway)"
log "   DNS Servers:   $($DNSServers)"
log "   DHCP Enabled:  $($IsDHCPEnabled)"
log "   Mac Address:   $($MACAddress)"
Log $delimiter

# Get UAC Status
Log "The current status of User Account Control (UAC):"
[string]$RegistryValue = "EnableLUA"
[string]$RegistryPath = "Software\Microsoft\Windows\CurrentVersion\Policies\System"
[bool]$enabled
[string]$Computer = $env:ComputerName
$OpenRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $Computer)
$Subkey = $OpenRegistry.OpenSubKey($RegistryPath, $true)
$Subkey.ToString() | Out-Null
if ($enabled -eq $true) {
    #$Subkey.SetValue($RegistryValue, 1)
    Log "    UAC is enabled."
} else {
    #$Subkey.SetValue($RegistryValue, 0)
    Log "    UAC is disabled."
}
Log $delimiter

# This can potentially break security in case of a rerun on a system where the password was already set.
Log "Changing Administrator password to 'Welcome1'. Make sure you change it with the proper one!"
([adsi]"WinNT://$ComputerName/Administrator").SetPassword("Welcome1")

# Set a few services to start automatically
Log "Seting BITS and Windows Update services startup type to 'Automatic'"
Set-Service -Name BITS -StartupType "Automatic"
Set-Service -Name wuauserv -StartupType "Automatic"
Set-Service -Name Audiosrv -StartupType "Automatic"

# Start the services
Log "Starting Services..."
Start-Service BITS
Start-Service wuauserv
Start-Service Audiosrv

# Install Telnet
Log "Installing Telnet client..."
Install-WindowsFeature 'telnet-client'
Log $delimiter

# Enable .NET Framework 3.5
# d:\sources\sxs points to the location of Win2012 setup CD
#Install-WindowsFeature Net-Framework-Core -source d:\sources\sxs

Log "PowerShell version: $PSVersionTable.PSVersion"
Log $delimiter

# Disable the Shutdown Event Tracker
if ( -Not (Test-Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Reliability')) {
    New-Item -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT' -Name Reliability -Force
}
Set-ItemProperty -Path 'registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Reliability' -Name ShutdownReasonOn -Value 0

# Disable the CTRL+ALT+DEL Prompt
Set-ItemProperty -Path 'registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name DisableCAD -Value 1

# Disable IE Enhanced Security Configuration (ESC)
$AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
$UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
Log "IE Enhanced Security Configuration (ESC) has been disabled."

# Returns the install .NET Framework versions.
$ndpDirectory = 'hklm:\SOFTWARE\Microsoft\NET Framework Setup\NDP\'

if (Test-Path "$ndpDirectory\v2.0.50727") {
    $version = Get-ItemProperty "$ndpDirectory\v2.0.50727" -name Version | select Version
}

if (Test-Path "$ndpDirectory\v3.0") {
    $version = Get-ItemProperty "$ndpDirectory\v3.0" -name Version | select Version
}

if (Test-Path "$ndpDirectory\v3.5") {
    $version = Get-ItemProperty "$ndpDirectory\v3.5" -name Version | select Version
}

$v4Directory = "$ndpDirectory\v4\Full"
if (Test-Path $v4Directory) {
    $version = Get-ItemProperty $v4Directory -name Version | select -expand Version
}
Log ".NET Framework: $version"
Log $delimiter

# Get Active "Power Scheme"
# POWERCFG /LIST # to get the Available list of all Power Settings  schemes
Log "Active Power Scheme"
$power_active = (POWERCFG /GETACTIVESCHEME).Split()[3]
$power_high = (POWERCFG /LIST | Select-String "High performance").Line.Split()[3]

if ($power_active -ne $power_high) {
    POWERCFG /SETACTIVE $power_high
    $power_active = (POWERCFG /GETACTIVESCHEME).Split()[3]
}
Log $power_active
Log $delimiter

# Disable the hibernate feature
POWERCFG /HIBERNATE OFF

# Set Password Never Expires on the local Administrator account
gwmi Win32_UserAccount -Filter "name = 'Administrator'" | swmi -Arguments @{PasswordExpires = 0}

# Disable Indexing on all drives
gwmi Win32_Volume -Filter "IndexingEnabled=$true" | swmi -Arguments @{IndexingEnabled = $false}

# Set time zone to Romance Standard Time
Log "Setting Time Zone to 'Romance Standard Time'"
Invoke-Command {tzutil.exe /s "Romance Standard Time"}
Log $delimiter

Stop-Transcript