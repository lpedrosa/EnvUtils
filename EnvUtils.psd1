@{

# Script module or binary module file associated with this manifest.
RootModule = 'EnvUtils.psm1'

# Version number of this module.
ModuleVersion = '0.5.1'

# Supported PSEditions
CompatiblePSEditions = @('Core', 'Desktop')

# ID used to uniquely identify this module
GUID = '69516ac2-0c2f-44b6-bbc7-9a705c8f8624'

# Author of this module
Author = 'lpedrosa'

# Company or vendor of this module
CompanyName = 'lpedrosa'

# Copyright statement for this module
Copyright = '(c) lpedrosa. All rights reserved.'

# Description of the functionality provided by this module
# Description = ''

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    "ConvertFrom-Environment",
    "Invoke-Environment",
    "New-Environment",
    "Remove-Environment",
    "Get-Environment"
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = ''

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

}

