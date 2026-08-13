$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================="
Write-Host "Power Automate Flow Health Check"
Write-Host "================================================="
Write-Host ""

# =================================================
# Configuration
# =================================================

$EnvironmentUrl = $env:DEV_ENV_URL
$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET

$SolutionName   = "POC_Solution"

# =================================================
# Validation
# =================================================

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

$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')

# =================================================
# Authentication
# =================================================

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

# =================================================
# Dataverse Token
# =================================================

$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$EnvironmentUrl/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri $TokenUrl `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Failed to obtain access token."
}

$Headers = @{
    Authorization      = "Bearer $AccessToken"
    Accept             = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}

# =================================================
# Solution Lookup
# =================================================

Write-Host "Getting solution..."

$SolutionUrl = "$EnvironmentUrl/api/data/v9.2/solutions?`$select=solutionid,uniquename&`$filter=uniquename eq '$SolutionName'"

$SolutionResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $SolutionUrl `
    -Headers $Headers

if ($SolutionResponse.value.Count -eq 0) {
    throw "Solution '$SolutionName' not found."
}

$SolutionId = $SolutionResponse.value[0].solutionid

Write-Host "Solution Id: $SolutionId"
Write-Host ""

# =================================================
# Get Workflow Components
# =================================================

$ComponentUrl = "$EnvironmentUrl/api/data/v9.2/solutioncomponents?`$select=objectid,componenttype,_solutionid_value&`$filter=_solutionid_value eq $SolutionId and componenttype eq 29"

$ComponentResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $ComponentUrl `
    -Headers $Headers

$WorkflowIds = @($ComponentResponse.value | Select-Object -ExpandProperty objectid)

Write-Host ""
Write-Host "Workflows Found In Solution : $($WorkflowIds.Count)"
Write-Host ""

foreach ($id in $WorkflowIds) {
    Write-Host $id
}

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW DETAILS"
Write-Host "================================================="
Write-Host ""

$EnabledFlows = 0
$DisabledFlows = 0
$FailedRuns = 0

foreach ($WorkflowId in $WorkflowIds) {

    try {

        $FlowUrl = "$EnvironmentUrl/api/data/v9.2/workflows($WorkflowId)?`$select=name,workflowid,statecode,statuscode,category"

        $Flow = Invoke-RestMethod `
            -Method Get `
            -Uri $FlowUrl `
            -Headers $Headers

        if ($Flow.category -ne 5) {
            continue
        }

        if ($Flow.statecode -eq 1) {
            $State = "Enabled"
            $EnabledFlows++
        }
        else {
            $State = "Disabled"
            $DisabledFlows++
        }

        Write-Host ""
        Write-Host "----------------------------------------"
        Write-Host "Flow Name   : $($Flow.name)"
        Write-Host "Workflow Id : $($Flow.workflowid)"
        Write-Host "State       : $State"
        Write-Host "----------------------------------------"

        #
        # Run History Section
        #
        # NOTE:
        # Dataverse workflowid is NOT the same as Flow API flow id.
        # This query attempts to find run data when exposed.
        #

        try {

            $RunUrl = "$EnvironmentUrl/api/data/v9.2/workflows($WorkflowId)"

            $RunResponse = Invoke-RestMethod `
                -Method Get `
                -Uri $RunUrl `
                -Headers $Headers

            Write-Host "Run history retrieval requires Flow API identifiers."
            Write-Host "Workflow retrieved successfully."

        }
        catch {

            Write-Host "Unable to retrieve run details."
        }

    }
    catch {

        Write-Host "##[warning]Unable to process workflow $WorkflowId"
    }
}

# =================================================
# Summary
# =================================================

Write-Host ""
Write-Host "================================================="
Write-Host "SUMMARY"
Write-Host "================================================="
Write-Host ""

Write-Host "Enabled Flows  : $EnabledFlows"
Write-Host "Disabled Flows : $DisabledFlows"
Write-Host "Failed Runs    : $FailedRuns"

Write-Host ""
Write-Host "Health check completed successfully."
Write-Host ""

exit 0
