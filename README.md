# EnvUtils

PowerShell module offering utilities to read environment variables from `dotenv` files, or `hashmap`
instances.

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

# Run dotenv file for a single script block
# the environment will clean itself when the script block completes
Invoke-Environment .env { $env:HELLO -eq 'WORLD' }

$env:HELLO -eq $null
```

[Check here](./EXAMPLES.md) for more examples

## Installing

### From Source

1. Clone this repo into a folder in your `$env:PSModulePath`
2. Run `Import-Module EnvUtils`

## FAQ

> Why not just use \<insert-programming-language\> implementation of dotenv?

[dotenv](https://www.npmjs.com/package/dotenv) and similar libraries, work well if you're only
testing an application written in that language.

`EnvUtils` gives you a bit more freedom over the `dotenv` file loading, merging, overrides, etc.

> Why not use PS-Dotenv?

[PS-Dotenv](https://github.com/insomnimus/ps-dotenv) is a PowerShell implementation of
[direnv](https://direnv.net/), which you should check out if that is what you're after.

Use `EnvUtils` when you do not want to automatically load `dotenv` files and you want full
control over _when_ the environment is overridden.

## License

[MIT](./LICENSE)
