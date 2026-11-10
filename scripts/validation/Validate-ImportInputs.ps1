# Validate the shared solution order and typed DEV2 import options.
[CmdletBinding()]
param(
    [string]$ConfigPath = 'config/solution.json',
    [string]$NamesPath,
    [string]$VersionPath
)
 
$ErrorActionPreference = 'Stop'
$logger = Join-Path $PSScriptRoot '../logging/Write-DeploymentLog.ps1'
 
function Write-Log {
    param([string]$Action, [string]$Stage, [string]$Message)
    $logArgs = @{ Action = $Action }
    if ($Stage) { $logArgs.Stage = $Stage }
    if ($Message) { $logArgs.Message = $Message }
& $logger @logArgs
}
 
try {
    Write-Log -Action Stage -Stage 'validation'
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Missing $ConfigPath."
    }
    try {
        $cfg = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
    }
    catch {
        throw "config/solutions.json is not valid JSON."
    }
 
    $release = [string]$cfg.releaseVersion
    if ($release -notmatch '^\d{1,10}(\.\d{1,10}){3}$') {
        throw "releaseVersion must be four numeric segments, such as 0.0.0.0."
    }
 
    $names = @($cfg.solutions)
    if ($names.Count -eq 0 -or $null -eq $cfg.solutions) {
        throw "config/solutions.json must list at least one solution name."
    }
    $seen = @{}
    foreach ($name in $names) {
        if ($name -isnot [string] -or $name -notmatch '^[A-Za-z][A-Za-z0-9_]*$') {
            throw "Invalid solution name in config/solutions.json."
        }
        if ($seen.ContainsKey($name)) { throw "Duplicate solution name: $name." }
        $seen[$name] = $true
    }
 
    if ($cfg.importDefaults.async -isnot [bool] -or -not $cfg.importDefaults.async) {
        throw "importDefaults.async must be true."
    }
    $wait = $cfg.importDefaults.maxAsyncWaitMinutes
    if ($wait -isnot [long] -and $wait -isnot [int]) {
        throw "importDefaults.maxAsyncWaitMinutes must be an integer."
    }
    if ([int]$wait -ne 60) {
        throw "importDefaults.maxAsyncWaitMinutes must be 60."
    }
 
    $allowed = @('settingsFile', 'activatePlugins', 'forceOverwrite')
    foreach ($entry in $cfg.importOptions.PSObject.Properties) {
        if (-not $seen.ContainsKey($entry.Name)) {
            throw "Import options reference unknown solution: $($entry.Name)."
        }
        foreach ($property in $entry.Value.PSObject.Properties) {
            if ($property.Name -notin $allowed) {
                throw "Unsupported import option $($property.Name) for $($entry.Name)."
            }
            if ($property.Name -in @('activatePlugins', 'forceOverwrite') -and $property.Value -isnot [bool]) {
                throw "$($property.Name) for $($entry.Name) must be true or false."
            }
        }
        if ($entry.Value.settingsFile) {
            $settings = [string]$entry.Value.settingsFile
            if ($settings -ne 'yaml-config/deployment-settings/dev2.deploymentSettings.json') {
                throw "Unexpected settings file for $($entry.Name): $settings."
            }
            if (-not (Test-Path -LiteralPath $settings)) {
                throw "Missing settings file for $($entry.Name): $settings."
            }
        }
    }
 
    $temp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    if (-not $NamesPath) { $NamesPath = Join-Path $temp 'import-solutions.txt' }
    if (-not $VersionPath) { $VersionPath = Join-Path $temp 'import-release-version.txt' }
    [System.IO.File]::WriteAllLines($NamesPath, $names)
    [System.IO.File]::WriteAllText($VersionPath, $release)
    Write-Log -Action Info -Message ("validation passed release $release order " + ($names -join ', '))
}
catch {
    $message = $_.Exception.Message
    Write-Host $message
    try { Write-Log -Action Error -Stage 'validation' -Message $message }
    catch { Write-Host $_.Exception.Message }
    exit 1
}
