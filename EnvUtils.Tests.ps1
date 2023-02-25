BeforeAll {
    Import-Module EnvUtils -Force
}

Describe "ConvertFrom-Environment" {
    It "Should process a simple .env file" {
        $environment = ConvertFrom-Environment "./fixtures/.simple.env"

        $environment.Count | Should -Be 2
        $environment["HELLO"] | Should -Be "WORLD"
        $environment["MESSAGE"] | Should -Be "This is a test !1"
    }

    It "Should aggregate and process multiple files" {
        $files = @("./fixtures/.simple.env", "./fixtures/.complex-values.env")
        $environment = ConvertFrom-Environment -Path $files

        $environment.Count | Should -Be 3
    }

    It "Should not split values that have '=' in them" {
        $environment = ConvertFrom-Environment "./fixtures/.complex-values.env"

        $environment.Count | Should -Be 1
        $environment["VAR2"] | Should -Be "My cool string=stuff"
    }

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

    It "Should not expand variables if asked" {
        'COOL_VALUE=nice nice
        VAR_TO_EXPAND=$COOL_VALUE' | Tee-Object '.fake.env'
        
        $environment = ConvertFrom-Environment '.fake.env' -NoExpand

        $localExpansionValue = $environment["COOL_VALUE"]
        $environment["VAR_TO_EXPAND"] | Should -Not -Be $localExpansionValue

        Remove-Item '.fake.env'
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
