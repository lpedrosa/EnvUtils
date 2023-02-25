$script:ComplexExpansionRegex = '(.*)\${([\w]*(?::-[\w/]*)?)?}(.*)'
$script:SimpleExpansionRegex = '(.*)\$([^{][\w]+)(.*)'

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
            Expand-Environment $result
        }
    }
}

function Expand-Environment {
    param(
        [hashtable]
        $environment
    )

    function Expand-Value {
        param (
            [string]$originalKey,
            [string]$originalValue
        )

        $replaced = $originalValue
        $continueExpanding = $false

        if ($originalValue -match $ComplexExpansionRegex) {
            $replaced, $continueExpanding = Expand-ComplexValue $originalKey $originalValue $Matches
        }
        elseif ($originalValue -match $SimpleExpansionRegex) {
            $replaced, $continueExpanding = Expand-SimpleValue $originalKey $originalValue $Matches
        }

        if ($continueExpanding) {
            Expand-Value $originalKey $replaced
        }
        else {
            $replaced
        }
    }

    function Expand-SimpleValue {
        param(
            [string]$originalKey,
            [string]$originalValue,
            [hashtable] $regexMatches
        )

        $varToReplace = $regexMatches.2

        # check if the environment table has that key
        $value = $environment[$varToReplace]
        if ($value) {
            # fail on recursive expansion
            if ($value -match $ComplexExpansionRegex -match $SimpleExpansionRegex) {
                Write-Warning "skipping recursive expansion for key '$originalKey'"
                return $originalValue, $false
            }
            # otherwise keep value as is
            Write-Debug "Expand-SimpleValue: Local expansion for key $originalKey"
        }
        elseif ([System.Environment]::GetEnvironmentVariable($varToReplace)) {
            # use value from current process environment
            Write-Debug "Expand-ComplexValue: Environment expansion for key $originalKey"
            $value = [System.Environment]::GetEnvironmentVariable($varToReplace)
        }
        else {
            Write-Warning "could not expand value for key '$originalKey'";
            return $originalValue, $false
        }

        $replaced = $originalValue -replace $SimpleExpansionRegex, "`$1$value`$3"

        $replaced, $true
    }

    function Expand-ComplexValue {
        param(
            [string]$originalKey,
            [string]$originalValue,
            [hashtable] $regexMatches
        )
        $varToReplace, $defaultIfNoMatch = $regexMatches.2 -split ':-', 2

        # check if the environment table has that key
        $value = $environment[$varToReplace]

        if ($value) {
            # fail on recursive expansion
            if ($value -match $ComplexExpansionRegex -match $SimpleExpansionRegex) {
                Write-Warning "skipping recursive expansion for key '$originalKey'"
                return $originalValue, $false
            }
            # otherwise keep value as is
            Write-Debug "Expand-ComplexValue: Local expansion for key $originalKey"
        }
        elseif ([System.Environment]::GetEnvironmentVariable($varToReplace)) {
            # use value from current process environment
            Write-Debug "Expand-ComplexValue: Environment expansion for key $originalKey"
            $value = [System.Environment]::GetEnvironmentVariable($varToReplace)
        }
        elseif ($defaultIfNoMatch) {
            # try to use default
            Write-Debug "Expand-ComplexValue: Default expansion for key $originalKey)"
            $value = $defaultIfNoMatch
        }
        else {
            Write-Warning "could not expand value for key '$originalKey'";
            return $originalValue, $false
        }

        $replaced = $originalValue -replace $ComplexExpansionRegex, "`$1$value`$3"

        $replaced, $true
    }

    $replaced = @{}

    foreach ($entry in $environment.GetEnumerator()) {
        $replaced[$entry.Key] = Expand-Value $entry.Key $entry.Value
    }

    $replaced
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
