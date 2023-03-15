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

function New-Environment {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "Environment")]
    param(
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
        $NoExpand
    )
    begin {
        $ErrorActionPreference = 'Stop'

        # get current session PID
        $currentSessionPid = [System.Diagnostics.Process]::GetCurrentProcess().Id

        # get temp directory
        $tempDirectory = [System.IO.Path]::GetTempPath()

        # try to create temp folder to store config in
        $configDirectory = [System.IO.Path]::Join($tempDirectory, "EnvUtils", $currentSessionPid)
        $configPath = [System.IO.Path]::Join($configDirectory, "config.json")

        if ((Test-Path -Path $configPath) -or (Test-Path -Path $configDirectory)) {
            throw "Found Custom Environment for current session. Remove it first with 'Remove-Environment'"
        }

        $envFiles = @()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq "EnvironmentFile") {
            if (Test-Path -Path $EnvironmentFile) {
                $EnvironmentFile.ForEach({ $envFiles += $_ })
            }
            else {
                throw "Cannot find environment file `"$EnvironmentFile`""
            }
        }
    }
    end {
        switch ($PSCmdlet.ParameterSetName) {
            "EnvironmentFile" {
                $envConfig = ConvertFrom-Environment $envFiles -NoExpand:$NoExpand
            }
            "Environment" {
                $envConfig = $Environment
            }
        }

        $overriddenVars = @{}

        foreach ($envEntry in $envConfig.GetEnumerator()) {
            $confirmTitle = "Set Environment Variable Prompt"

            # lookup if entry exists in current env
            $existingVarValue = [System.Environment]::GetEnvironmentVariable($envEntry.Key)
            if ($existingVarValue) {
                $whatIfMsg = "Overriding environment variable `"$($envEntry.Key)`""
                $confirmMsg = "Would you like to override environment variable `"$($envEntry.Key)`"?"

                $overriddenVars[$envEntry.Key] = $existingVarValue
            }
            else {
                $whatIfMsg = "Setting environment variable `"$($envEntry.Key)`""
                $confirmMsg = "Would you like to set environment variable `"$($envEntry.Key)`"?"
            }

            if ($PSCmdlet.ShouldProcess($whatIfMsg, $confirmMsg, $confirmTitle)) {
                Set-Item -Path "Env:$($envEntry.Key)" -Value $envEntry.Value
            }
        }

        if (-not $WhatIfPreference) {
            $ConfirmPreference = 'None'
            New-Item -ItemType Directory -Path "$tempDirectory/EnvUtils/$currentSessionPid" > $null

            $config = @{
                Overridden  = $overriddenVars.Count -eq 0 ? $null : $overriddenVars
                Environment = $envConfig
            }

            ConvertTo-Json $config > $configPath
        }
    }
}

function Remove-Environment {
    [CmdletBinding()]
    param()

    # get current session PID
    $currentSessionPid = [System.Diagnostics.Process]::GetCurrentProcess().Id

    # get temp directory
    $tempDirectory = [System.IO.Path]::GetTempPath()

    # try to create temp folder to store config in
    $configDirectory = [System.IO.Path]::Join($tempDirectory, "EnvUtils", $currentSessionPid)
    $configPath = [System.IO.Path]::Join($configDirectory, "config.json")

    if ((Test-Path -Path $configPath) -or (Test-Path -Path $configDirectory)) {
        # read session config
        $config = (Get-Content $configPath | ConvertFrom-Json -AsHashtable)

        foreach ($envEntry in $config.Environment.GetEnumerator()) {
            Write-Verbose "Removing environment variable `"$($envEntry.Key)`""
            Remove-Item -Path "Env:$($envEntry.Key)"
        }

        if ($config.Overridden) {
            foreach ($envEntry in $config.Overridden.GetEnumerator()) {
                Write-Verbose "Restoring environment variable `"$($envEntry.Key)`""
                Set-Item -Path "Env:$($envEntry.Key)" -Value $envEntry.Value
            }
        }

        # remove directory
        Remove-Item -Recurse $configDirectory
    }
    else {
        Write-Warning 'Custom Environment not found for given session, skipping...'
    }
}
