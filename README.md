# EnvUtils

PowerShell module offering utilities to read environment variables from `dotenv` files, or ad-hoc
hashmaps.

## Example

```pwsh
# Create an dotenv example file
'HELLO=WORLD' > .env

# Import it into the current session
New-Environment .env

# Check if current environment contains the var
$env:HELLO -eq 'WORLD'

# Remove previously created environment
Remove-Environment -Verbose
VERBOSE: Removing environment variable "HELLO"

$env:HELLO -eq $null
```

[Check here](./EXAMPLES.md) for more examples

## Installing

### From Source

1. Clone this repo into a folder in your `$env:PSModulePath`
2. Run `Import-Module EnvUtils`

## License

[MIT](./LICENSE)
