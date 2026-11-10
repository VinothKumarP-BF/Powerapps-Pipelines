# Check release version, work item, and ordered solution names. All three live in config/solutions.json.
[CmdletBinding()]
param(
    [string]$ConfigPath = 'config/solution.json',
    [string]$NamesPath,
    [string]$VersionPath,
    [string]$WorkItemPath
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
    $workItem = [string]$cfg.abNumber
    if ($workItem -notmatch '^\d+$') {
        throw "abNumber must be digits only."
    }
 
    $names = @($cfg.solutions)
    if (-not $cfg.PSObject.Properties.Name.Contains('solutions') -or $names.Count -eq 0 -or $null -eq $cfg.solutions) {
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
 
    $temp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    if (-not $NamesPath) { $NamesPath = Join-Path $temp 'solutions.txt' }
    if (-not $VersionPath) { $VersionPath = Join-Path $temp 'release-version.txt' }
    if (-not $WorkItemPath) { $WorkItemPath = Join-Path $temp 'ab-number.txt' }
    [System.IO.File]::WriteAllLines($NamesPath, $ordered)
    [System.IO.File]::WriteAllText($VersionPath, $release)
    [System.IO.File]::WriteAllText($WorkItemPath, $workItem)
    Write-Log -Action Info -Message ("validation passed release $release work item AB#$workItem order " + ($ordered -join ', '))
}
catch {
    $message = $_.Exception.Message
    Write-Host $message
    try {
        Write-Log -Action Error -Stage 'validation' -Message $message
    }
    catch {
        Write-Host $_.Exception.Message
    }
    exit 1
}
