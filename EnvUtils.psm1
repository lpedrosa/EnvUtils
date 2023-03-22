Import-Module $PSScriptRoot/private/EnvUtilsExpansion.psm1 -Force

$script:SessionConfig = [PSCustomObject]@{
    Overridden  = @()
    Environment = @()
}

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
        $ErrorActionPreference = 'Stop'
        $result = [hashtable]@{}
    }

    process {
        $envFileContent = Get-Content $Path

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
    [CmdletBinding(DefaultParameterSetName = "Environment")]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true,
            ParameterSetName = "EnvironmentFile",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more `".env`" locations.")]
        [string[]]
        $EnvironmentFile,

        [Parameter(
            ParameterSetName = "EnvironmentFile",
            HelpMessage = "Do not expand variables on values.")]
        [switch]
        $NoExpand,

        [Parameter(ParameterSetName = "EnvironmentFile",
            ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true,
            ParameterSetName = "Environment",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Environment
    )
    begin {
        $ErrorActionPreference = 'Stop'
        $envFiles = @()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq "EnvironmentFile") {
            foreach ($envFile in $EnvironmentFile) {
                if (Test-Path -Path $envFile) {
                    $envFiles += $envFile
                }
                else {
                    throw "Cannot find environment file `"$envFile`""
                }
            }
        }
    }
    end {
        $envConfig = [hashtable]@{}

        switch ($PSCmdlet.ParameterSetName) {
            "EnvironmentFile" {
                $envConfig = ConvertFrom-Environment $envFiles -NoExpand:$NoExpand
                if ($Environment) {
                    foreach ($key in $Environment.Keys) {
                        if ($envConfig.ContainsKey($key)) {
                            $envConfig.Remove($key)
                        }
                    }
                    $envConfig += $Environment
                }
            }
            "Environment" {
                $envConfig = $Environment
            }
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

}

function New-Environment {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Environment")]
    param(
        [Parameter(ParameterSetName = "EnvironmentFile",
            ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "Environment",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $Environment,
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = "EnvironmentFile",
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = "Path to one or more `".env`" locations.")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $EnvironmentFile,
        [Parameter(
            ParameterSetName = "EnvironmentFile",
            HelpMessage = "Do not expand variables on values.")]
        [switch]
        $NoExpand,
        [switch]
        $Force
    )
    begin {
        $ErrorActionPreference = 'Stop'

        if ($Force -and -not $Confirm) {
            $ConfirmPreference = 'None'
        }

        if ($script:SessionConfig.Environment.Length -ne 0) {
            $operationMsg = "Removing current Custom Environment"
            $targetMsg = "Would you like to remove the current Custom Environment?"
            if ($Force -or $PSCmdlet.ShouldContinue($targetMsg, $operationMsg)) {
                Remove-Environment -Verbose:$VerbosePreference
            }
            else {
                throw "Found Custom Environment for current session. Remove it first with 'Remove-Environment'"
            }
        }

        $envFiles = @()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq "EnvironmentFile") {
            foreach ($envFile in $EnvironmentFile) {
                if (Test-Path -Path $envFile) {
                    $envFiles += $envFile
                }
                else {
                    throw "Cannot find environment file `"$envFile`""
                }
            }
        }
    }
    end {
        switch ($PSCmdlet.ParameterSetName) {
            "EnvironmentFile" {
                $envConfig = ConvertFrom-Environment $envFiles -NoExpand:$NoExpand
                if ($Environment) {
                    foreach ($key in $Environment.Keys) {
                        if ($envConfig.ContainsKey($key)) {
                            $envConfig.Remove($key)
                        }
                    }
                    $envConfig += $Environment
                }
            }
            "Environment" {
                $envConfig = $Environment
            }
        }

        foreach ($envEntry in $envConfig.GetEnumerator()) {
            $confirmTitle = "Set Environment Variable Prompt"

            # lookup if entry exists in current env
            $existingVarValue = [System.Environment]::GetEnvironmentVariable($envEntry.Key)
            if ($existingVarValue) {
                $whatIfMsg = "Overriding environment variable `"$($envEntry.Key)`""
                $confirmMsg = "Would you like to override environment variable `"$($envEntry.Key)`"?"

                if ($PSCmdlet.ShouldProcess($whatIfMsg, $confirmMsg, $confirmTitle)) {
                    Set-Item -Path "Env:$($envEntry.Key)" -Value $envEntry.Value -Confirm:$false
                    $script:SessionConfig.Overridden += @{ Name = $envEntry.Key; Value = $existingVarValue }
                    $script:SessionConfig.Environment += @{ Name = $envEntry.Key; Value = $envEntry.Value }
                }
            }
            else {
                $whatIfMsg = "Setting environment variable `"$($envEntry.Key)`""
                $confirmMsg = "Would you like to set environment variable `"$($envEntry.Key)`"?"

                if ($PSCmdlet.ShouldProcess($whatIfMsg, $confirmMsg, $confirmTitle)) {
                    Set-Item -Path "Env:$($envEntry.Key)" -Value $envEntry.Value -Confirm:$false
                    $script:SessionConfig.Environment += @{ Name = $envEntry.Key; Value = $envEntry.Value }
                }
            }
        }
    }
}

function Get-Environment {
    [CmdletBinding()]
    param()
    $script:SessionConfig
}

function Remove-Environment {
    [CmdletBinding()]
    param()

    if ($script:SessionConfig.Environment.Length -eq 0) {
        Write-Warning 'Custom Environment not found for given session, skipping...'
        return
    }

    foreach ($envEntry in $script:SessionConfig.Environment) {
        Write-Verbose "Removing environment variable `"$($envEntry.Name)`""
        Remove-Item -Path "Env:$($envEntry.Name)"
    }

    foreach ($envEntry in $script:SessionConfig.Overridden) {
        Write-Verbose "Restoring environment variable `"$($envEntry.Name)`""
        Set-Item -Path "Env:$($envEntry.Name)" -Value $envEntry.Value
    }

    # clear config
    $script:SessionConfig = [PSCustomObject]@{
        Overridden  = @()
        Environment = @()
    }
}
