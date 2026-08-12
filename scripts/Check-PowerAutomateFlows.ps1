$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================="
Write-Host "Power Platform Solution Flow Health Check"
Write-Host "================================================="
Write-Host ""

# =================================================
# Environment Variables
# =================================================

$EnvironmentUrl = $env:DEV_ENV_URL
$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET

# Set your solution unique name here
$SolutionUniqueName = "POC_CR"

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

if ([string]::IsNullOrWhiteSpace($SolutionUniqueName)) {
    throw "Solution unique name is not configured."
}

$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')

Write-Host "Environment : $EnvironmentUrl"
Write-Host "Solution    : $SolutionUniqueName"
Write-Host ""

# =================================================
# PAC Authentication
# =================================================

Write-Host "Authenticating with PAC CLI..."

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
# Acquire Dataverse Token
# =================================================

Write-Host "Requesting Dataverse token..."

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

if (:IsNullOrWhiteSpace($AccessToken)) {
    throw "Failed to obtain access token."
}

Write-Host "Access token acquired."
Write-Host ""

# =================================================
# HTTP Headers
# =================================================

$Headers = @{
    Authorization      = "Bearer $AccessToken"
    Accept             = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}

# =================================================
# Get Solution
# =================================================

Write-Host "Retrieving solution..."

$SolutionUrl = "$EnvironmentUrl/api/data/v9.2/solutions?`$select=solutionid,uniquename,friendlyname&`$filter=uniquename eq '$SolutionUniqueName'"

$SolutionResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $SolutionUrl `
    -Headers $Headers

if ($SolutionResponse.value.Count -eq 0) {
    throw "Solution '$SolutionUniqueName' not found."
}

$Solution = $SolutionResponse.value[0]
$SolutionId = $Solution.solutionid

Write-Host ""
Write-Host "Solution Found:"
Write-Host "Friendly Name : $($Solution.friendlyname)"
Write-Host "Unique Name   : $($Solution.uniquename)"
Write-Host "Solution Id   : $SolutionId"
Write-Host ""

# =================================================
# Get Workflow Components Belonging To Solution
# =================================================

Write-Host "Retrieving solution workflow components..."

$ComponentUrl = "$EnvironmentUrl/api/data/v9.2/solutioncomponents?`$select=objectid,componenttype,_solutionid_value&`$filter=componenttype eq 29 and _solutionid_value eq $SolutionId"

$ComponentResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $ComponentUrl `
    -Headers $Headers

$WorkflowIds = @($ComponentResponse.value | Select-Object -ExpandProperty objectid)

if ($WorkflowIds.Count -eq 0) {

    Write-Host ""
    Write-Host "No workflow components found in solution."
    Write-Host ""
    exit 0
}

Write-Host "Workflow Components Found : $($WorkflowIds.Count)"
Write-Host ""

# =================================================
# Process Flows
# =================================================

$TotalFlows    = 0
$EnabledFlows  = 0
$DisabledFlows = 0

Write-Host "================================================="
Write-Host "FLOW DETAILS"
Write-Host "================================================="
Write-Host ""

foreach ($WorkflowId in $WorkflowIds) {

    try {

        $FlowUrl = "$EnvironmentUrl/api/data/v9.2/workflows($WorkflowId)?`$select=name,workflowid,statecode,statuscode,category"

        $Flow = Invoke-RestMethod `
            -Method Get `
            -Uri $FlowUrl `
            -Headers $Headers

        # Category 5 = Cloud Flow
        if ($Flow.category -ne 5) {
            continue
        }

        $TotalFlows++

        if ($Flow.statecode -eq 1) {
            $State = "Enabled"
            $EnabledFlows++
        }
        else {
            $State = "Disabled"
            $DisabledFlows++

            Write-Host "##[warning]Disabled Flow: $($Flow.name)"
        }

        Write-Host "----------------------------------------"
        Write-Host "Flow Name   : $($Flow.name)"
        Write-Host "Workflow Id : $($Flow.workflowid)"
        Write-Host "State       : $State"
        Write-Host "State Code  : $($Flow.statecode)"
        Write-Host "Status Code : $($Flow.statuscode)"
    }
    catch {

        Write-Host "##[warning]Unable to retrieve workflow $WorkflowId"
    }
}

# =================================================
# Summary
# =================================================

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW HEALTH SUMMARY"
Write-Host "================================================="
Write-Host ""

Write-Host "Total Cloud Flows : $TotalFlows"
Write-Host "Enabled Flows     : $EnabledFlows"
Write-Host "Disabled Flows    : $DisabledFlows"

Write-Host ""

if ($DisabledFlows -gt 0) {
    Write-Host "##[warning]Disabled flows detected."
}

Write-Host "Flow details retrieved successfully."
Write-Host ""

Write-Host "================================================="
Write-Host "Health check completed successfully."
Write-Host "================================================="
Write-Host ""

# IMPORTANT:
# Do not fail GitHub Action because of disabled flows

exit 0
