BeforeAll {
    Import-Module EnvUtils -Force
}

Describe "ConvertFrom-Environment" {
    It "Should process a simple .env file" {
        $environment = ConvertFrom-Environment .\fixtures\.simple.env

        $environment.Count | Should -Be 2
        $environment["HELLO"] | Should -Be "WORLD"
        $environment["MESSAGE"] | Should -Be "This is a test !1"
    }

    It "Should not split values that have '=' in them" {
        $environment = ConvertFrom-Environment .\fixtures\.complex-values.env

        $environment.Count | Should -Be 1
        $environment["VAR2"] | Should -Be "My cool string=stuff"
    }
}