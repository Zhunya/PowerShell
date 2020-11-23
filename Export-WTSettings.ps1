<#
.SYNOPSIS
    Export Windows Terminal settings

.DESCRIPTION
    Export Windows Terminal settings

.PARAMETER Path
    Path to backup file

.NOTES
    Author: Viorel Ciucu
    Website: https://cviorel.com
    License: MIT https://opensource.org/licenses/MIT

.EXAMPLE
    Export-WTSettings -Path C:\Temp
#>
function Export-WTSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    begin {
        $settingsFile = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json"

        if (!(Test-Path -Path $settingsFile)) {
            Write-Error "Could not find the settings file!"
            return
        }
        $Path = Resolve-Path -Path $Path
        $TimeStamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
        $BackupFile = "wtSettings-$($TimeStamp).zip"
    }

    process {
        if (!(Test-Path -Path $Path)) {
            $null = New-Item -Path $Path -ItemType Directory -ErrorAction SilentlyContinue
        }
        try {
            Copy-Item -Path $settingsFile -Destination $Path
            Compress-Archive -Path $settingsFile -DestinationPath $Path\$BackupFile -Update -CompressionLevel Fastest
        } catch {
            throw $_
        }
    }

    end {
        Write-Output "The settings file was exported to $($Path.TrimEnd('\'))\$BackupFile."
    }
}
