Import-Module $PSScriptRoot/private/EnvUtilsExpansion.psm1 -Force

function ConvertFrom-Environment {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,
        # Do not expand variables on values
        [Parameter(HelpMessage = "Do not expand variables on values.")]
        [switch]
        $NoExpand
    )

    begin {
        $result = [hashtable]@{}
    }

    process {
        $envFileContent = Get-Content $Path -ErrorAction Stop

        foreach ($line in $envFileContent) {
            Write-Debug "Processing line: $line"
            switch -Wildcard ($line) {
                "#*" { Write-Debug "Comment: $line"; continue }
                "*=*" {
                    Write-Debug "Assignment: $line"
                    # tell split to split the string in the first occurrence of '='
                    # i.e. return max 2 two substrings when splitting
                    $key, $value = $line -split "=", 2

                    if (![string]::IsNullOrWhiteSpace($value)) {
                        if ($result.ContainsKey($key.Trim())) {
                            Write-Debug "Overriding key: $($key.Trim())"
                        }
                        $result[$key.Trim()] = $value.Trim()
                    }
                    else {
                        Write-Warning "skipping unset key '$key'"
                    }
                }
                Default { Write-Debug "Unhandled: $line"; continue }
            }
        }
    }

    end {
        if ($NoExpand) {
            $result
        }
        else {
            # Preferences aren't passed on across module boundaries. In this particular case we want
            # that to happen, so we have to do so explicitly.
            #
            # See more: https://github.com/PowerShell/PowerShell/issues/4568
            Expand-Environment $result -WarningAction:$WarningPreference -Debug:$DebugPreference -ErrorAction:$ErrorActionPreference
        }
    }
}

function Invoke-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $EnvironmentFile,

        [Parameter()]
        [switch]
        $NoExpand,

        [Parameter()]
        [hashtable]
        $Environment
    )

    $envConfig = [hashtable]@{}
    if ($EnvironmentFile) {
        $envConfig = ConvertFrom-Environment $EnvironmentFile -NoExpand:$NoExpand
    }

    if ($Environment) {
        foreach ($key in $Environment.Keys) {
            if ($envConfig.ContainsKey($key)) {
                $envConfig.Remove($key)
            }
        }
        $envConfig += $Environment
    }

    foreach ($entry in $envConfig.GetEnumerator()) {
        Set-Item -Path "Env:$($entry.Key)" -Value $entry.Value
    }
    try {
        & $ScriptBlock
    }
    finally {
        foreach ($entry in $envConfig.GetEnumerator()) {
            Remove-Item -Path "Env:$($entry.Key)"
        }
    }

}
