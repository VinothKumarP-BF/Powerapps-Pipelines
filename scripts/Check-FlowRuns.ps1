$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================="
Write-Host "Power Automate Flow Health Check"
Write-Host "================================================="
Write-Host ""

# -------------------------------------------------
# Environment Variables
# -------------------------------------------------

$EnvironmentUrl = $env:DEV_ENV_URL
$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET
$SolutionName   = $env:SOLUTION_NAME

# -------------------------------------------------
# Validation
# -------------------------------------------------

if ([string]::IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "DEV_ENV_URL is not configured."
}

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    throw "TENANT_ID is not configured."
}

if ([string]::IsNullOrWhiteSpace($ClientId)) {
    throw "CLIENT_ID is not configured."
}

if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw "CLIENT_SECRET is not configured."
}

if ([string]::IsNullOrWhiteSpace($SolutionName)) {
    throw "SOLUTION_NAME is not configured."
}

$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')

Write-Host "Environment : $EnvironmentUrl"
Write-Host "Solution    : $SolutionName"
Write-Host ""

# -------------------------------------------------
# PAC Authentication
# -------------------------------------------------

Write-Host "Authenticating..."

pac auth create `
    --url $EnvironmentUrl `
    --applicationId $ClientId `
    --clientSecret $ClientSecret `
    --tenant $TenantId

if ($LASTEXITCODE -ne 0) {
    throw "PAC authentication failed."
}

Write-Host "Authentication successful."
Write-Host ""

# -------------------------------------------------
# Show PAC Version
# -------------------------------------------------

Write-Host "PAC Version:"
pac --version

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW DETAILS"
Write-Host "================================================="

# -------------------------------------------------
# Get Flows From Solution
# -------------------------------------------------

try {

    $flowsJson = pac flow list `
        --solution $SolutionName `
        --json

    $Flows = $flowsJson | ConvertFrom-Json
}
catch {

    throw "Unable to retrieve flows from solution '$SolutionName'."
}

if (-not $Flows) {

    Write-Host "No flows found."
    exit 0
}

$EnabledFlows = 0
$DisabledFlows = 0
$FailedRuns = 0
$SucceededRuns = 0

foreach ($flow in $Flows) {

    Write-Host ""
    Write-Host "----------------------------------------"

    Write-Host "Flow Name : $($flow.displayName)"
    Write-Host "Flow Id   : $($flow.name)"

    if ($flow.state -eq "Started") {

        $EnabledFlows++
        Write-Host "State     : Enabled"

    }
    else {

        $DisabledFlows++
        Write-Host "State     : Disabled"
        Write-Host "##[warning]Disabled Flow: $($flow.displayName)"
    }

    Write-Host ""

    Write-Host "Recent Runs"
    Write-Host "----------------------------------------"

    try {

        $runsJson = pac flow run list `
            --flow $flow.name `
            --top 20 `
            --json

        $Runs = $runsJson | ConvertFrom-Json

        if (-not $Runs) {

            Write-Host "No runs found."
            continue
        }

        foreach ($run in $Runs) {

            $status = $run.properties.status

            Write-Host ""
            Write-Host "Run Id     : $($run.name)"
            Write-Host "Status     : $status"
            Write-Host "Start Time : $($run.properties.startTime)"
            Write-Host "End Time   : $($run.properties.endTime)"

            switch ($status) {

                "Failed" {

                    $FailedRuns++
                    Write-Host "##[warning]FAILED RUN DETECTED"
                }

                "Succeeded" {

                    $SucceededRuns++
                }
            }

            Write-Host "----------------------------------------"
        }
    }
    catch {

        Write-Host "##[warning]Unable to retrieve runs for flow $($flow.displayName)"
    }
}

# -------------------------------------------------
# Summary
# -------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW SUMMARY"
Write-Host "================================================="
Write-Host ""

Write-Host "Enabled Flows   : $EnabledFlows"
Write-Host "Disabled Flows  : $DisabledFlows"
Write-Host "Succeeded Runs  : $SucceededRuns"
Write-Host "Failed Runs     : $FailedRuns"

if ($FailedRuns -gt 0) {

    Write-Host ""
    Write-Host "##[warning]Failed runs were detected."
}

Write-Host ""
Write-Host "Flow health check completed."
Write-Host ""

# Always keep GitHub Action green
exit 0
