function ConvertFrom-Environment {
    [CmdletBinding()]
    param (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "ParameterSetName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path
    )

    $envFileContent = Get-Content $Path -ErrorAction Stop
    $result = @{}

    foreach ($line in $envFileContent) {
        switch -Wildcard ($line) {
            "#*" { Write-Debug "Comment: $line"; continue }
            "*=*" { 
                Write-Debug "Assignment: $line"
                # tell split to split the string in the first occurrence of '='
                # i.e. return max 2 two substrings when splitting
                $key, $value = $line -split "=", 2

                if (![string]::IsNullOrWhiteSpace($value)) {
                    $result[$key.Trim()] = $value.Trim()
                }
                else {
                    Write-Warning "skipping unset key '$key'"
                }
            }
            Default { Write-Debug "Unhandled: $line"; continue }
        }
    }

    $result
}

function Invoke-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "ParameterSetName",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [string[]]
        $EnvironmentFile,

        [Parameter()]
        [hashtable]
        $Environment
    )

    $envConfig = [hashtable]@{}
    if ($EnvironmentFile) { 
        $envConfig = ConvertFrom-Environment $EnvironmentFile
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
