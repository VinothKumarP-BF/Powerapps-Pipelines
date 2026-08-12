$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "================================================="
Write-Host "Power Platform Solution Flow Health Check"
Write-Host "================================================="
Write-Host ""

# -------------------------------------------------
# Configuration
# -------------------------------------------------

$EnvironmentUrl = $env:DEV_ENV_URL
$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET

# Solution Unique Name
$SolutionUniqueName = "POC_CR"

# -------------------------------------------------
# Validate Inputs
# -------------------------------------------------

if (:IsNullOrWhiteSpace($EnvironmentUrl)) {
    throw "DEV_ENV_URL is not configured."
}

if (:IsNullOrWhiteSpace($TenantId)) {
    throw "TENANT_ID is not configured."
}

if (:IsNullOrWhiteSpace($ClientId)) {
    throw "CLIENT_ID is not configured."
}

if (:IsNullOrWhiteSpace($ClientSecret)) {
    throw "CLIENT_SECRET is not configured."
}

if (:IsNullOrWhiteSpace($SolutionUniqueName)) {
    throw "Solution unique name is not configured."
}

$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')

Write-Host "Environment : $EnvironmentUrl"
Write-Host "Solution    : $SolutionUniqueName"
Write-Host ""

# -------------------------------------------------
# Authenticate using PAC CLI
# -------------------------------------------------

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

# -------------------------------------------------
# Request Dataverse Token
# -------------------------------------------------

Write-Host "Requesting Dataverse access token..."

$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$EnvironmentUrl/.default"
    grant_type    = "client_credentials"
}

try {

    $TokenResponse = Invoke-RestMethod `
        -Method Post `
        -Uri $TokenUrl `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $TokenBody

}
catch {

    throw "Failed to acquire Dataverse access token. $($_.Exception.Message)"
}

$AccessToken = $TokenResponse.access_token

if (:IsNullOrWhiteSpace($AccessToken)) {
    throw "Access token was not returned."
}

Write-Host "Access token acquired."
Write-Host ""

# -------------------------------------------------
# Headers
# -------------------------------------------------

$Headers = @{
    Authorization      = "Bearer $AccessToken"
    Accept             = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}

# -------------------------------------------------
# Retrieve Solution
# -------------------------------------------------

Write-Host "Retrieving solution..."

$SolutionUrl = "$EnvironmentUrl/api/data/v9.2/solutions?`$select=solutionid,friendlyname,uniquename&`$filter=uniquename eq '$SolutionUniqueName'"

$SolutionResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $SolutionUrl `
    -Headers $Headers

if ($SolutionResponse.value.Count -eq 0) {
    throw "Solution '$SolutionUniqueName' was not found."
}

$Solution = $SolutionResponse.value[0]
$SolutionId = $Solution.solutionid

Write-Host "Solution Found:"
Write-Host "Name       : $($Solution.friendlyname)"
Write-Host "Unique Name: $($Solution.uniquename)"
Write-Host "SolutionId : $SolutionId"
Write-Host ""

# -------------------------------------------------
# Retrieve Workflow Components
# ComponentType 29 = Workflow
# -------------------------------------------------

Write-Host "Retrieving solution components..."

$ComponentUrl = "$EnvironmentUrl/api/data/v9.2/solutioncomponents?`$select=objectid,componenttype&`$filter=componenttype eq 29"

$ComponentResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $ComponentUrl `
    -Headers $Headers

$FlowCount = 0
$EnabledCount = 0
$DisabledCount = 0

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW DETAILS"
Write-Host "================================================="
Write-Host ""

foreach ($component in $ComponentResponse.value) {

    $WorkflowId = $component.objectid

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

        $FlowCount++

        if ($Flow.statecode -eq 1) {

            $State = "Enabled"
            $EnabledCount++

        }
        else {

            $State = "Disabled"
            $DisabledCount++

            Write-Host "##[warning]Flow '$($Flow.name)' is disabled."
        }

        Write-Host "-----------------------------------------"
        Write-Host "Flow Name   : $($Flow.name)"
        Write-Host "Workflow Id : $($Flow.workflowid)"
        Write-Host "State       : $State"
        Write-Host "State Code  : $($Flow.statecode)"
        Write-Host "Status Code : $($Flow.statuscode)"
    }
    catch {

        Write-Host "##[warning]Unable to retrieve workflow details for $WorkflowId"
    }
}

# -------------------------------------------------
# Summary
# -------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host "FLOW HEALTH SUMMARY"
Write-Host "================================================="
Write-Host ""

Write-Host "Total Cloud Flows : $FlowCount"
Write-Host "Enabled Flows     : $EnabledCount"
Write-Host "Disabled Flows    : $DisabledCount"

Write-Host ""

if ($DisabledCount -gt 0) {

    Write-Host "##[warning]Disabled flows were detected."
    Write-Host "Health check completed successfully."

}
else {

    Write-Host "All flows are enabled."
}

Write-Host ""
Write-Host "================================================="
Write-Host "Flow health check completed successfully."
Write-Host "================================================="
Write-Host ""

exit 0
