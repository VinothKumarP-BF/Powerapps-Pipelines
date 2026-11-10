# Publish this run's log to branch log. This is the only writer of that branch.

$ErrorActionPreference = 'Stop'
 
function Redact-GitText {

    param([string]$Text)

    if (-not $Text) { return '' }

    $clean = $Text

    $token = $env:GITHUB_TOKEN

    if ($token) {

        $clean = $clean.Replace($token, '<redacted>')

        $pair = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$token"))

        $clean = $clean.Replace($pair, '<redacted>')

    }

    return ($clean -replace '(?i)(bearer\s+)\S+', '$1<redacted>' -replace '(?i)(basic\s+)\S+', '$1<redacted>')

}
 
function Invoke-Git {

    param(

        [Parameter(Mandatory = $true)]

        [string[]]$GitArgs,

        [string]$Repo,

        [switch]$AllowFailure

    )
 
    # One Basic header in the process environment, not on the command line and not in repo config.

    # Clearing inherited GIT_CONFIG_* avoids a second Authorization header from actions/checkout.

    $token = $env:GITHUB_TOKEN

    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$token"))

    $inherited = @(

        'GIT_CONFIG_COUNT', 'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0',

        'GIT_CONFIG_KEY_1', 'GIT_CONFIG_VALUE_1', 'GIT_CONFIG_GLOBAL', 'GIT_CONFIG_SYSTEM'

    )

    $saved = @{}

    foreach ($name in $inherited) {

        $saved[$name] = [Environment]::GetEnvironmentVariable($name)

    }

    $previous = $ErrorActionPreference

    $ErrorActionPreference = 'Continue'

    try {

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', '2')

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_0', 'http.https://github.com/.extraheader')

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_0', "AUTHORIZATION: basic $basic")

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_KEY_1', 'credential.helper')

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_VALUE_1', '')

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_GLOBAL', $null)

        [Environment]::SetEnvironmentVariable('GIT_CONFIG_SYSTEM', $null)

        if ($Repo) {

            $output = & git -C $Repo @GitArgs 2>&1

        }

        else {

            $output = & git @GitArgs 2>&1

        }

        $code = $LASTEXITCODE

    }

    finally {

        $ErrorActionPreference = $previous

        foreach ($name in $inherited) {

            [Environment]::SetEnvironmentVariable($name, $saved[$name])

        }

    }

    $script:GitText = Redact-GitText (($output | ForEach-Object { "$_" }) -join "`n")

    if ($script:GitText) { Write-Host $script:GitText }

    if (-not $AllowFailure -and $code -ne 0) {

        throw "git failed (${code}): $($GitArgs -join ' ')`n$script:GitText"

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
 
try {

    New-Item -ItemType Directory -Path $work | Out-Null

    $null = Invoke-Git -Repo $work -GitArgs @('init', '-b', 'log')

    $null = Invoke-Git -Repo $work -GitArgs @('remote', 'add', 'origin', $remote)

    $fetch = Invoke-Git -AllowFailure -Repo $work -GitArgs @('fetch', '--depth', '1', 'origin', 'refs/heads/log')

    if ($fetch -eq 0) {

        $null = Invoke-Git -Repo $work -GitArgs @('checkout', '-B', 'log', 'FETCH_HEAD')

    }

    elseif ($script:GitText -notmatch "couldn't find remote ref") {

        throw "git fetch failed (${fetch}): $($script:GitText)"

    }
 
    $destination = Join-Path $work $relative

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null

    Copy-Item -LiteralPath $state.LogFile -Destination $destination -Force

    $null = Invoke-Git -Repo $work -GitArgs @('config', 'user.name', 'github-actions')

    $null = Invoke-Git -Repo $work -GitArgs @('config', 'user.email', 'actions@github.com')

    $null = Invoke-Git -Repo $work -GitArgs @('add', '--', $relative)

    $null = Invoke-Git -Repo $work -GitArgs @('commit', '-m', "Export log $relative")

    $push = Invoke-Git -AllowFailure -Repo $work -GitArgs @('push', 'origin', 'HEAD:refs/heads/log')

    if ($push -ne 0) {

        $null = Invoke-Git -Repo $work -GitArgs @('fetch', '--depth', '1', 'origin', 'refs/heads/log')

        $null = Invoke-Git -Repo $work -GitArgs @('rebase', 'FETCH_HEAD')

        $null = Invoke-Git -Repo $work -GitArgs @('push', 'origin', 'HEAD:refs/heads/log')

    }

}

finally {

    if (Test-Path -LiteralPath $work) {

        Remove-Item -LiteralPath $work -Recurse -Force

    }

}

 
