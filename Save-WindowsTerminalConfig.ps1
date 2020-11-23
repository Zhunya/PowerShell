<#
.SYNOPSIS
    Makes a backup of the configuration file for Windows Terminal profiles.json

.DESCRIPTION
    Makes a backup of the configuration file for Windows Terminal profiles.json

.EXAMPLE
    Save-WindowsTerminalConfig -repoPath "$env:USERPROFILE\Documents\GitHub\dotfiles"

    Saves the configuration file to "$env:USERPROFILE\Documents\GitHub\dotfiles".
    If the target folder does not exist it will be created.
    Existing file will be overwritten.

.PARAMETER repoPath
    Inputs to this cmdlet (if any)

.NOTES
    Author: Viorel Ciucu
    Website: https://cviorel.com
    License: MIT https://opensource.org/licenses/MIT

.FUNCTIONALITY
    Makes a backup of the configuration file for Windows Terminal profiles.json
#>

function Save-WindowsTerminalConfig {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string]$repoPath = "$env:USERPROFILE\Documents\dotfiles"
    )

    begin {
        if (!(Test-Path $repoPath)) {
            try {
                New-Item -ItemType Directory -Path "$env:USERPROFILE\Documents\dotfiles" -ErrorAction Stop
            } catch {
                Write-Error "The repoPath could not be created!"
                exit
            }
        }
        Write-Output "Saving Windows Terminal config file to $repoPath"

        $jsonConfigFile = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json"
    }

    process {
        $now = Get-Date -Format "yyyMMddHHmm"

        Copy-Item -Path $jsonConfigFile -Destination $repoPath -Force
        Set-Location $repoPath
        git add .
        git commit -a -m "profiles.json - $now"
        git push
    }

    end {
        Write-Output "The file was backedup to $repoPath\profiles.json"
    }
}
