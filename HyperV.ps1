# Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
# https://thinkpowershell.com/powershell-set-up-hyper-v-lab/

$vmPath = "$env:SystemDrive\Hyper-V\VMs"
$vdPath = "$env:SystemDrive\Hyper-V\VHDs"

$vmPath, $vdPath | ForEach-Object {
    $null = New-Item -Path $_ -ItemType "directory"
}

Set-VMHost -VirtualHardDiskPath $vdPath
Set-VMHost -VirtualMachinePath $vmPath


$NetAdapter = Get-NetAdapter -Name "Wi-Fi"
New-VMSwitch -Name "External" -AllowManagementOS $True -NetAdapterName $NetAdapter.Name
New-VMSwitch -Name "Internal" -SwitchType Internal
New-VMSwitch -Name "Private" -SwitchType Private

$SwitchName = "NAT"

# Create the Internal switch to use for NAT
New-VMSwitch -Name $SwitchName -SwitchType Internal

# Create the host interface for the Internal switch. This will be the default gateway used by your NAT'd VMs.
New-NetIPAddress -IPAddress 192.168.2.1 -PrefixLength 24 -InterfaceAlias "vEthernet ($SwitchName)"

# Create NAT object
New-NetNat -Name $SwitchName -InternalIPInterfaceAddressPrefix 192.168.2.0/24