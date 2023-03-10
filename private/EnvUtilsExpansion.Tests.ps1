BeforeAll {
    Import-Module $PSScriptRoot/EnvUtilsExpansion.psm1 -Force
}

Describe "EnvUtilsExpansion" {

    Context "Single variable expansion" {
        It "Should do a simple expansion when value is <valueType>" -ForEach @(
            @{ TestValue = 2; ValueType = 'a number' }, 
            @{ TestValue = 'a string'; ValueType = 'a simple string' }
            @{ TestValue = '123 (another \b\t\c)'; ValueType = 'a complex string' }
        ) {
            $testEnvironment = @{
                VAR_1      = $testValue
                EXPANDED   = '$VAR_1'
                EXPANDED_2 = '${VAR_1}'
            }

            $res = Expand-Environment $testEnvironment

            $res['EXPANDED'] | Should -Be $testEnvironment['VAR_1']
            $res['EXPANDED_2'] | Should -Be $testEnvironment['VAR_1']
        }

        It "Should not expand if cannot find var" {
            $testEnvironment = @{
                EXPANDED   = '$VAR_1'
                EXPANDED_2 = '${VAR_1}'
            }

            $res = Expand-Environment $testEnvironment -WarningAction SilentlyContinue

            $res['EXPANDED'] | Should -Be '$VAR_1'
            $res['EXPANDED_2'] | Should -Be '${VAR_1}'
        }
    }

    Context "Single variable default expansion" {
        It "Should expand var if present and has default" {
            $testEnvironment = @{
                VAR_1    = 2
                EXPANDED = '${VAR_1:-default}'
            }

            $res = Expand-Environment $testEnvironment

            $res['EXPANDED'] | Should -Be $testEnvironment['VAR_1']
        }

        It "Should expand to default if var not present" {
            $testEnvironment = @{
                EXPANDED = '${VAR_1:-default}'
            }

            $res = Expand-Environment $testEnvironment

            $res['EXPANDED'] | Should -Be 'default'
        }

        It "Should expand to default if var not present and default empty" {
            $testEnvironment = @{
                EXPANDED = '${VAR_1:-}'
            }

            $res = Expand-Environment $testEnvironment

            $res['EXPANDED'] | Should -Be ''
        }
    }

    Context "Recursive Expansion" {
        It "Should not do recursive expansion" {
            $testEnvironment = @{
                'EXPANDED' = '$EXPANDED'
            }

            $result = @{}
            try {
                $result.Result = Expand-Environment $testEnvironment -WarningAction SilentlyContinue
            } catch {
                $result.Error = $_
            }

            $result.ContainsKey('Error') | Should -Be $false
        }
    }
}