# Examples

## New-Environment

```pwsh
'HELLO = WORLD' > .env

# Accepts a single file
New-Environment .env

# Or multiple files
$dotenvFiles = Get-ChildItem -Filter *.env -Path .
New-Environment -Force $dotenvFiles

# Pipelining works
Get-ChildItem -Filter *.env -Path . | New-Environment

# Read environment from a hash table instead
New-Environment -Force -Environment @{'HELLO' = 'WORLD'}

# Hash table definitions always override dotenv files
$overrides = @{'HELLO' = 'OVERRIDE'}
New-Environment -Force -EnvironmentFile .env -Environment $overrides
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

## Get-Environment and Remove-Environment

```pwsh
'HELLO = WORLD' > .env

# Setup a new enviroment
New-Environment .env
$env:HELLO -eq 'WORLD'


# Do some work with this environment set
# ...

# To check which variable are set/overridden in the current environment
Get-Environment


# To stop using the current environment
Remove-Environment
$env:HELLO -eq $null
```
