param(
    [Parameter(Position = 0)]
    [string]$Asset = "sentry"
)

$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $here "..\..")
Set-Location $repo
python (Join-Path $here "generate_assets.py") $Asset
exit $LASTEXITCODE
