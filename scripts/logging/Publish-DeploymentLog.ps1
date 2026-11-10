# Publish this run's log to branch log. This is the only writer of that branch.
$ErrorActionPreference = 'Stop'
 
function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$GitArgs,
        [string]$Repo,
        [switch]$AllowFailure
    )
 
    $token = $env:GITHUB_TOKEN
    $prefix = @('-c', "http.extraheader=AUTHORIZATION: bearer $token")
    if ($Repo) {
        $output = & git -C $Repo @prefix @GitArgs
    }
    else {
        $output = & git @prefix @GitArgs
    }
    $code = $LASTEXITCODE
    if ($output) {
        $output | ForEach-Object { Write-Host $_ }
    }
    if (-not $AllowFailure -and $code -ne 0) {
        throw "git failed (${code}): $($GitArgs -join ' ')"
    }
    return $code
}
 
$root = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [System.IO.Path]::GetTempPath() }
$statePath = Join-Path $root 'pp-export-state.json'
if (-not (Test-Path -LiteralPath $statePath)) {
    exit 0
}
 
$state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
$stage = if ($state.LastStage) { $state.LastStage } else { 'unknown' }
$errorText = if ($state.LastError) { $state.LastError } else { 'the run failed' }
 
if ($env:JOB_STATUS -eq 'success') {
    $footer = "`nSUCCESS`n"
}
else {
    $footer = "`nFAILED`nSTAGE: $stage`nERROR: $errorText`n"
}
[System.IO.File]::AppendAllText($state.LogFile, $footer)
 
if (-not $env:GITHUB_TOKEN) {
    throw "GITHUB_TOKEN is unavailable."
}
if (-not $env:GITHUB_REPOSITORY) {
    throw "GITHUB_REPOSITORY is unavailable."
}
 
$remote = "https://github.com/$($env:GITHUB_REPOSITORY).git"
$work = Join-Path $root 'log-repo'
$relative = "logs/$($state.Day)/$($state.RunId).log"
if (Test-Path -LiteralPath $work) {
    Remove-Item -LiteralPath $work -Recurse -Force
}
 
$probe = Invoke-Git -AllowFailure -GitArgs @('ls-remote', '--exit-code', '--heads', $remote, 'log')
if ($probe -eq 0) {
    $null = Invoke-Git -GitArgs @('clone', '--branch', 'log', '--single-branch', '--depth', '1', $remote, $work)
}
elseif ($probe -eq 2) {
    $null = Invoke-Git -GitArgs @('init', '-b', 'log', $work)
    $null = Invoke-Git -Repo $work -GitArgs @('remote', 'add', 'origin', $remote)
}
else {
    throw "git ls-remote failed ($probe)"
}
 
$destination = Join-Path $work $relative
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
Copy-Item -LiteralPath $state.LogFile -Destination $destination -Force
$null = Invoke-Git -Repo $work -GitArgs @('config', 'user.name', 'github-actions')
$null = Invoke-Git -Repo $work -GitArgs @('config', 'user.email', 'actions@github.com')
$null = Invoke-Git -Repo $work -GitArgs @('add', '--', $relative)
$null = Invoke-Git -Repo $work -GitArgs @('commit', '-m', "Export log $relative")
$null = Invoke-Git -Repo $work -GitArgs @('push', 'origin', 'log')
