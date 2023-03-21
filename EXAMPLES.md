# Examples

## New-Environment

```pwsh
'HELLO = WORLD' > .env

# Accepts a single file
New-Environment .env

# Or multiple files
$dotenvFiles = Get-ChildItem -Filter *.env -Path .
New-Environment $dotenvFiles

# Pipelining works
Get-ChildItem -Filter *.env -Path . | New-Environment

# Read environment from a hash table instead
New-Environment -Environment @{'HELLO' = 'WORLD'}

# Hash table definitions always override dotenv files
$overrides = @{'HELLO' = 'OVERRIDE'}
New-Environment -EnvironmentFile .env -Environment $overrides
$env:HELLO -eq 'OVERRIDE'
```

## Invoke-Environment

```pwsh
# Environment is only available in the script block
'HELLO = WORLD' > .env
Invoke-Environment .env { $env:HELLO -eq 'WORLD' }
$env:HELLO -eq $null

# Again, hash table definitions always override dotenv files
$overrides = @{'HELLO' = 'OVERRIDE'}
Invoke-Environment -EnvironmentFile .env -Environment $overrides {
    $env:HELLO -eq 'OVERRIDE'
}
```
