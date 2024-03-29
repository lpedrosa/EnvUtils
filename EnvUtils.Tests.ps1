BeforeAll {
    Import-Module $PSScriptRoot/EnvUtils.psm1 -Force
}

Describe "ConvertFrom-Environment" {
    It "Should process a simple .env file" {
        $environment = ConvertFrom-Environment "./fixtures/.simple.env"

        $environment.Count | Should -Be 2
        $environment["HELLO"] | Should -Be "WORLD"
        $environment["MESSAGE"] | Should -Be "This is a test !1"
    }

    It "Should not split values that have '=' in them" {
        $environment = ConvertFrom-Environment "./fixtures/.complex-values.env"

        $environment.Count | Should -Be 1
        $environment["VAR2"] | Should -Be "My cool string=stuff"
    }

    Context "Aggregation" {
        It "Should aggregate and process multiple files" {
            $files = @("./fixtures/.simple.env", "./fixtures/.complex-values.env")
            $environment = ConvertFrom-Environment -Path $files

            $environment.Count | Should -Be 3
        }

        It "Should aggregate input from a pipeline" {
            $files = @("./fixtures/.simple.env", "./fixtures/.complex-values.env")
            $environment = $files | ConvertFrom-Environment

            $environment.Count | Should -Be 3
        }

        It "Should override keys when aggregating" {
            $files = @("./fixtures/.simple.env", "./fixtures/.simple-override.env")
            $environment = $files | ConvertFrom-Environment

            $environment.Count | Should -Be 2
            $environment["HELLO"] | Should -Be "WORLD2"
        }
    }

    Context "Variable Expansion" {
        It "Should expand variables by default" {
            # set env before reading the file
            $envExpansionValue = "from environment"
            Set-Item -Path "Env:ENVUTILS_FROM_ENV" -Value $envExpansionValue

            # silence warnings since there will be some vars that cannot be expanded
            $environment = ConvertFrom-Environment "./fixtures/.expand-values.env" -WarningAction SilentlyContinue

            $localExpansionValue = $environment["COOL_VALUE"]

            $environment["VAR_TO_EXPAND_1"] | Should -Be $localExpansionValue
            $environment["VAR_TO_EXPAND_2"] | Should -Be $localExpansionValue
            $environment["VAR_TO_EXPAND_3"] | Should -Be $localExpansionValue
            $environment["VAR_TO_EXPAND_4"] | Should -Be "$localExpansionValue||$localExpansionValue"

            $environment["VAR_TO_EXPAND_DEFAULT"] | Should -Be "default"

            $environment["VAR_TO_EXPAND_ENV_1"] | Should -Be $envExpansionValue
            $environment["VAR_TO_EXPAND_ENV_2"] | Should -Be $envExpansionValue
            $environment["VAR_TO_EXPAND_ENV_3"] | Should -Be $envExpansionValue

            $environment["MULTIPLE_EXPANSIONS"] | Should -Be "$($localExpansionValue)::$($localExpansionValue)::default"

            $environment["EDGE_CASE_1"] | Should -Be "$($localExpansionValue):-default"
            $environment["EDGE_CASE_2"] | Should -Be "`$I_DO_NOT_EXIST:-default"

            # set env back to normal
            Remove-Item -Path "Env:ENVUTILS_FROM_ENV"
        }

        It "Should expand numbers correctly" {
            # Numbers were not being expanded correctly because in the '-replace' expression I
            # should have been using the unambiguous backreference syntax i.e., ${1} as opposed to $1
            #
            # More info here: https://learn.microsoft.com/en-us/dotnet/standard/base-types/substitutions-in-regular-expressions#substituting-a-numbered-group

            $environment = ConvertFrom-Environment "./fixtures/.number-values.env"

            $expansionValue = $environment["VAR_1"]

            $environment["VAR_2"] | Should -Be $expansionValue
            $environment["VAR_3"] | Should -Be $expansionValue

            $environment["COMPLEX"] | Should -Be "$($expansionValue)$($expansionValue)$($expansionValue)"
        }

        It "Should not expand variables if asked" {
            $environment = ConvertFrom-Environment './fixtures/.no-expand.env' -NoExpand

            $localExpansionValue = $environment["COOL_VALUE"]
            $environment["VAR_TO_EXPAND"] | Should -Not -Be $localExpansionValue
        }
    }
}

Describe "Invoke-Environment" {
    Context "From EnvironmentFile" {
        It "Should make variables available only in the script block" {
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
            Invoke-Environment -EnvironmentFile .\fixtures\.simple.env {
                [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be "WORLD"
            }
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        }

        It "Should aggregate and override variables accordingly" {
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
            [System.Environment]::GetEnvironmentVariable("MESSAGE") | Should -Be $null

            $files = @("./fixtures/.simple.env", "./fixtures/.simple-override.env")

            Invoke-Environment -EnvironmentFile $files {
                [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be "WORLD2"
                [System.Environment]::GetEnvironmentVariable("MESSAGE") | Should -Be "This is a test !1"
            }
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
            [System.Environment]::GetEnvironmentVariable("MESSAGE") | Should -Be $null
        }
        It "Should override EnvironmentFile with Environment Object values" {
            $environmentOverrides = @{"HELLO" = "WORLD Overridden" }

            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
            Invoke-Environment -EnvironmentFile .\fixtures\.simple.env -Environment $environmentOverrides {
                [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $environmentOverrides.HELLO
            }
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        }

        It "Should restore old environment values" {
            $oldEnvValue = "WORLD"
            $testEnvValue = "WORLD Overridden"

            [System.Environment]::SetEnvironmentVariable("HELLO", $oldEnvValue)
            Invoke-Environment -Environment @{"HELLO" = $testEnvValue } {
                [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $testEnvValue
            }
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $oldEnvValue

            # don't forget to clean up HELLO
            [System.Environment]::SetEnvironmentVariable("HELLO", $null)
        }
    }

    Context "From Environment Object" {
        It "Should make variables available only in the script block" {
            $environment = @{
                HELLO = "WORLD"
            }

            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
            Invoke-Environment -Environment $environment {
                [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $environment.HELLO
            }
            [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null

        }
    }
}

Describe "New-Environment and Remove-Environment" {
    It "Should set the environment based on a hashtable" {
        $environment = @{
            HELLO = "WORLD"
        }

        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        New-Environment -Environment $environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $environment.HELLO
        Remove-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
    }

    It "Should set the environment based on a .env file" {
        $file = "./fixtures/.simple-override.env"

        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        New-Environment -EnvironmentFile $file
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be "WORLD2"
        Remove-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
    }

    It "Should set the environment based on files coming from the pipeline" {
        $files = @("./fixtures/.simple.env", "./fixtures/.simple-override.env")

        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        $files | New-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be "WORLD2"
        Remove-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
    }

    It "Should set the environment based on a hashtable coming from the pipeline" {
        $environment = @{
            HELLO = "WORLD"
        }
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        $environment | New-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $environment.HELLO
        Remove-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
    }

    It "Should fail if one of the env files doesn't exist" {
        $files = @("./fixtures/.simple.env", "i-do-not-exist")

        { $files | New-Environment } | Should -Throw
        { New-Environment -EnvironmentFile $files } | Should -Throw
    }

    It "Should override environment file with hashtable values" {
        $environmentOverrides = @{"HELLO" = "WORLD Overridden" }

        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
        New-Environment -EnvironmentFile .\fixtures\.simple.env -Environment $environmentOverrides
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $environmentOverrides.HELLO
        Remove-Environment
        [System.Environment]::GetEnvironmentVariable("HELLO") | Should -Be $null
    }
}
