Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

Install-Module -Name dbatools
Install-Module -Name Pester -Force -SkipPublisherCheck
Install-Module -Name Plaster
Install-Module -Name HtmlReport
Install-Module -Name PSScriptAnalyzer