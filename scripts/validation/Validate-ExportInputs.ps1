# Check the release version, work item, and ordered solution list.

[CmdletBinding()]

param(

    [string]$ReleaseVersion = $env:RELEASE_VERSION,

    [string]$WorkItem = $env:AB_NUMBER,

    [string]$ConfigPath = 'config/solutions.json',

    [string]$NamesPath

)
 
$ErrorActionPreference = 'Stop'

$logger = Join-Path $PSScriptRoot '../logging/Write-DeploymentLog.ps1'
 
function Write-Log {

    param(

        [string]$Action,

        [string]$Stage,

        [string]$Message

    )

    $logArgs = @{ Action = $Action }

    if ($Stage) { $logArgs.Stage = $Stage }

    if ($Message) { $logArgs.Message = $Message }
& $logger @logArgs

}
 
try {

    Write-Log -Action Stage -Stage 'validation'

    if ($ReleaseVersion -notmatch '^\d{1,10}(\.\d{1,10}){3}$') {

        throw "Release version must be four numeric segments, such as 0.0.0.0."

    }

    if ($WorkItem -notmatch '^\d+$') {

        throw "Work item must be digits only."

    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {

        throw "Missing $ConfigPath."

    }
 
    $raw = Get-Content -Raw -LiteralPath $ConfigPath

    if ($raw.TrimStart().StartsWith('[') -eq $false) {

        throw "config/solutions.json must be a JSON array."

    }

    try {

        $parsed = $raw | ConvertFrom-Json -NoEnumerate

    }

    catch {

        throw "config/solutions.json is not valid JSON."

    }
 
    $names = @($parsed)

    if ($names.Count -eq 0) {

        throw "config/solutions.json must list at least one solution name."

    }
 
    $seen = @{}

    $ordered = New-Object System.Collections.Generic.List[string]

    foreach ($name in $names) {

        if ($name -isnot [string] -or $name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {

            throw "Invalid solution name in config/solutions.json."

        }

        if ($seen.ContainsKey($name)) {

            throw "Duplicate solution name: $name."

        }

        $seen[$name] = $true

        $ordered.Add($name)

    }
 
    if (-not $NamesPath) {

        $temp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }

        $NamesPath = Join-Path $temp 'solutions.txt'

    }

    [System.IO.File]::WriteAllLines($NamesPath, $ordered)

    Write-Log -Action Info -Message ("validation passed order " + ($ordered -join ', '))

}

catch {

    Write-Log -Action Error -Stage 'validation' -Message $_.Exception.Message

    exit 1

}
