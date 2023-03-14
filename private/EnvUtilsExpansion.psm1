$script:ExpansionRegex = '\$((?<simple>[^{][\w]+)|{(?<complex>[\w]*(?::-[\w/]*)?)?})'

function Expand-Environment {
    [CmdletBinding()]
    param(
        [hashtable]
        $environment
    )

    $replacer = {
        param(
            [System.Text.RegularExpressions.Match]
            $CurrentMatch
        )

        if ($CurrentMatch.Groups['simple'].Value) {
            $keyToReplace = $CurrentMatch.Groups['simple'].Value

            Write-Debug "Expand-Environment: Simple expansion for key '$($keyToReplace)'"
        }
        elseif ($CurrentMatch.Groups['complex'].Value) {
            $parts = $CurrentMatch.Groups['complex'].Value -split ':-', 2
            $keyToReplace = $parts[0]
            $defaultIfNoValue = $parts[1]

            Write-Debug "Expand-Environment: Complex expansion for key '$($keyToReplace)'"

        }
        else {
            Write-Error "dunno how to replace $($CurrentMatch.Value)"
        }

        # check env map first
        $value = $null

        if ($environment[$keyToReplace]) {
            Write-Debug "Expand-Environment: Local expansion for key '$keyToReplace'"
            $value = $environment[$keyToReplace]
        }
        elseif ([System.Environment]::GetEnvironmentVariable($keyToReplace)) {
            # use value from current process environment
            Write-Debug "Expand-Environment: Environment expansion for key '$keyToReplace'"
            $value = [System.Environment]::GetEnvironmentVariable($keyToReplace)
        }
        elseif ($null -ne $defaultIfNoValue) {
            Write-Debug "Expand-Environment: Default expansion for key '$keyToReplace'"
            $value = $defaultIfNoValue
        }
        else {
            Write-Warning "could not expand key '$keyToReplace'"
            $value = $CurrentMatch.Value
        }

        $value
    }

    $replaced = @{}

    foreach ($entry in $environment.GetEnumerator()) {
        Write-Debug "Expand-Environment: Processing entry for key '$($entry.Key)' with value '$($entry.Value)'"
        $replaced[$entry.Key] = [System.Text.RegularExpressions.Regex]::Replace($entry.Value, $script:ExpansionRegex, $replacer)
    }

    $replaced
}

Export-ModuleMember -Function 'Expand-Environment'
