$script:ComplexExpansionRegex = '(.*)\${([\w]*(?::-[\w/]*)?)?}(.*)'
$script:SimpleExpansionRegex = '(.*)\$([^{][\w]+)(.*)'

function Expand-Environment {
    [CmdletBinding()]
    param(
        [hashtable]
        $environment
    )

    $replaced = @{}

    foreach ($entry in $environment.GetEnumerator()) {
        $replaced[$entry.Key] = Expand-Value $entry.Key $entry.Value $environment
    }

    $replaced
}

function Expand-Value {
    [CmdletBinding()]
    param (
        [string]$originalKey,
        [string]$originalValue,
        [hashtable]$environment
    )

    $replaced = $originalValue
    $continueExpanding = $false

    if ($originalValue -match $ComplexExpansionRegex) {
        $replaced, $continueExpanding = Expand-ComplexValue $originalKey $originalValue $Matches $environment
    }
    elseif ($originalValue -match $SimpleExpansionRegex) {
        $replaced, $continueExpanding = Expand-SimpleValue $originalKey $originalValue $Matches $environment
    }

    if ($continueExpanding) {
        Expand-Value $originalKey $replaced $environment
    }
    else {
        $replaced
    }
}

function Expand-SimpleValue {
    [CmdletBinding()]
    param(
        [string]$originalKey,
        [string]$originalValue,
        [hashtable] $regexMatches,
        [hashtable]$environment
    )

    $varToReplace = $regexMatches.2

    # check if the environment table has that key
    $value = $environment[$varToReplace]
    if ($value) {
        # fail on recursive expansion
        if ($value -match $ComplexExpansionRegex -or $value -match $SimpleExpansionRegex) {
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
        Write-Warning "could not expand var '$varToReplace' for key '$originalKey'";
        return $originalValue, $false
    }

    $replaced = $originalValue -replace $SimpleExpansionRegex, "`${1}$value`${3}"

    $replaced, $true
}

function Expand-ComplexValue {
    [CmdletBinding()]
    param(
        [string]$originalKey,
        [string]$originalValue,
        [hashtable] $regexMatches,
        [hashtable]$environment
    )
    #$varToReplace, $defaultIfNoMatch = $regexMatches.2 -split ':-', 2
    $parts = $regexMatches.2 -split ':-', 2

    # check if the environment table has that key
    $value = $environment[$parts[0]]

    if ($value) {
        # fail on recursive expansion
        if ($value -match $ComplexExpansionRegex -match $SimpleExpansionRegex) {
            Write-Warning "skipping recursive expansion for key '$originalKey'"
            return $originalValue, $false
        }
        # otherwise keep value as is
        Write-Debug "Expand-ComplexValue: Local expansion for key $originalKey"
    }
    elseif ([System.Environment]::GetEnvironmentVariable($parts[0])) {
        # use value from current process environment
        Write-Debug "Expand-ComplexValue: Environment expansion for key $originalKey"
        $value = [System.Environment]::GetEnvironmentVariable($parts[0])
    }
    elseif ($parts.Length -eq 2) {
        # try to use default
        Write-Debug "Expand-ComplexValue: Default expansion for key $originalKey)"
        $value = $parts[1]
    }
    else {
        Write-Warning "could not expand var '$($parts[0])' for key '$originalKey'";
        return $originalValue, $false
    }

    $replaced = $originalValue -replace $ComplexExpansionRegex, "`${1}$value`${3}"

    $replaced, $true
}

Export-ModuleMember -Function 'Expand-Environment'