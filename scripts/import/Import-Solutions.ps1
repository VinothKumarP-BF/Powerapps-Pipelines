# Pack and import each solution into DEV2 in the shared config order.

[CmdletBinding()]

param(

    [string]$ConfigPath = 'config/solution.json',

    [string]$SourcePath = 'release',

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
 
function Stop-Import {

    param([string]$Stage, [string]$Message)

    Write-Log -Action Error -Stage $Stage -Message $Message

    Write-Host $Message

    exit 1

}
 
$temp = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }

if (-not $NamesPath) { $NamesPath = Join-Path $temp 'import-solutions.txt' }

if (-not $VersionPath) { $VersionPath = Join-Path $temp 'import-release-version.txt' }

if (-not (Test-Path -LiteralPath $NamesPath) -or -not (Test-Path -LiteralPath $VersionPath)) {

    Stop-Import -Stage 'import' -Message 'Validated import inputs are missing.'

}
 
$cfg = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json

$release = (Get-Content -Raw -LiteralPath $VersionPath).Trim()

$names = @(Get-Content -LiteralPath $NamesPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$releaseRoot = Join-Path $SourcePath "Releases/v$release"

$wait = [string]$cfg.importDefaults.maxAsyncWaitMinutes
 
foreach ($name in $names) {

    $solutionFolder = Join-Path $releaseRoot $name

    if (-not (Test-Path -LiteralPath $solutionFolder -PathType Container)) {

        Stop-Import -Stage "pack $name" -Message "Missing release folder for $name."

    }
 
    $zip = Join-Path $temp "${name}_managed.zip"

    Write-Log -Action Stage -Stage "pack $name"

    Write-Log -Action Info -Message "pack started $name"
& pac solution pack --folder $solutionFolder --zipfile $zip --packagetype Managed

    if ($LASTEXITCODE -ne 0) {

        Stop-Import -Stage "pack $name" -Message "PAC pack failed for $name."

    }

    $zipItem = Get-Item -LiteralPath $zip -ErrorAction SilentlyContinue

    if (-not $zipItem -or $zipItem.Length -le 0) {

        Stop-Import -Stage "pack $name" -Message "Managed package is missing or empty for $name."

    }

    Write-Log -Action Info -Message "pack succeeded $name"
 
    $importArgs = @(

        'solution', 'import',

        '--path', $zip,

        '--async',

        '--max-async-wait-time', $wait

    )

    $options = $cfg.importOptions.$name

    if ($options.settingsFile) {

        $importArgs += @('--settings-file', [string]$options.settingsFile)

    }

    if ($options.activatePlugins -eq $true) {

        $importArgs += @('--activate-plugins', 'true')

    }

    if ($options.forceOverwrite -eq $true) {

        $importArgs += @('--force-overwrite', 'true')

    }
 
    Write-Log -Action Stage -Stage "import $name"

    Write-Log -Action Info -Message "import started $name"
& pac @importArgs

    if ($LASTEXITCODE -ne 0) {

        Stop-Import -Stage "import $name" -Message "PAC import failed for $name."

    }

    Write-Log -Action Info -Message "import succeeded $name"

}
 
Write-Log -Action Info -Message 'import finished'

 
