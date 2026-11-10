# Append the local deployment log. The file stays outside both git checkouts.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Init', 'Stage', 'Info', 'Warn', 'Error')]
    [string]$Action,
 
    [string]$Stage,
    [string]$Message
)
 
$ErrorActionPreference = 'Stop'
 
function Get-IstNow {
    return [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromMinutes(330))
}
 
function Get-StatePath {
    $root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
    return Join-Path $root 'pp-export-state.json'
}
 
function Read-State {
    $path = Get-StatePath
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Deployment log has not been initialized."
    }
    return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}
 
function Save-State {
    param($State)
    $json = $State | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText((Get-StatePath), $json)
}
 
function Add-LogLine {
    param(
        [string]$Level,
        [string]$Text,
        [string]$LogFile
    )
    $stamp = (Get-IstNow).ToString('yyyy-MM-ddTHH:mm:ss') + '+0530'
    [System.IO.File]::AppendAllText($LogFile, "$stamp $Level $Text`n")
}
 
switch ($Action) {
    'Init' {
        $ist = Get-IstNow
        $runId = if ($env:GITHUB_RUN_ID) { $env:GITHUB_RUN_ID } else { 'local' }
        $attempt = if ($env:GITHUB_RUN_ATTEMPT) { $env:GITHUB_RUN_ATTEMPT } else { '1' }
        $safeId = '{0}-{1}-a{2}' -f $ist.ToString('yyyyMMdd'), $runId, $attempt
        $day = $ist.ToString('yyyy-MM-dd')
        $root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
        $logFile = Join-Path $root ("pp-export-{0}.log" -f $safeId)
        $server = if ($env:GITHUB_SERVER_URL) { $env:GITHUB_SERVER_URL.TrimEnd('/') } else { 'https://github.com' }
        $repo = if ($env:GITHUB_REPOSITORY) { $env:GITHUB_REPOSITORY } else { '<org>/<repo>' }
        $runUrl = "$server/$repo/actions/runs/$runId/attempts/$attempt"
        $release = if ($env:RELEASE_VERSION) { $env:RELEASE_VERSION } else { '' }
        $workItem = if ($env:AB_NUMBER) { $env:AB_NUMBER } else { '' }
        $header = @(
            "RUN ID: $safeId"
            "RELEASE: $release"
            "WORK ITEM: AB#$workItem"
            "RUN URL: $runUrl"
            "RUN: $runId attempt $attempt"
            "SOURCE: DEV"
            "TARGET: Managed_Solutions"
            "BRANCH: Managed_Solutions"
            "LOG BRANCH: log"
            ""
        ) -join "`n"
        [System.IO.File]::WriteAllText($logFile, $header + "`n")
        $state = [pscustomobject]@{
            LogFile   = $logFile
            RunId     = $safeId
            Day       = $day
            LastStage = ''
            LastError = ''
        }
        Save-State $state
    }
    'Stage' {
        if (-not $Stage) { throw "Stage is required." }
        $state = Read-State
        $state.LastStage = $Stage
        Save-State $state
    }
    'Info' {
        if (-not $Message) { throw "Message is required." }
        $state = Read-State
        Add-LogLine -Level 'INFO' -Text $Message -LogFile $state.LogFile
    }
    'Warn' {
        if (-not $Message) { throw "Message is required." }
        $state = Read-State
        Add-LogLine -Level 'WARN' -Text $Message -LogFile $state.LogFile
    }
    'Error' {
        if (-not $Message) { throw "Message is required." }
        $state = Read-State
        if ($Stage) { $state.LastStage = $Stage }
        $state.LastError = $Message
        Save-State $state
        Add-LogLine -Level 'ERROR' -Text $Message -LogFile $state.LogFile
    }
}
