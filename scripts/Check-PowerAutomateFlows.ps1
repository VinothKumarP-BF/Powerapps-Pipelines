$ErrorActionPreference = "Stop"
 
Write-Host ""
Write-Host "============================================================"
Write-Host "       Power Automate Flow Health Check"
Write-Host "============================================================"
Write-Host ""
 
# ============================================================
# Read environment variables
# ============================================================
 
$TenantId = $env:TENANT_ID
$ClientId = $env:CLIENT_ID
$ClientSecret = $env:CLIENT_SECRET
$EnvironmentId = $env:DEV_ENV_ID
 
# ============================================================
# Validate inputs
# ============================================================
 
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    throw "TENANT_ID is not configured."
}
 
if ([string]::IsNullOrWhiteSpace($ClientId)) {
    throw "CLIENT_ID is not configured."
}
 
if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw "CLIENT_SECRET is not configured."
}
 
if ([string]::IsNullOrWhiteSpace($EnvironmentId)) {
    throw "DEV_ENV_ID is not configured."
}
 
Write-Host "Tenant ID       : $TenantId"
Write-Host "Client ID       : $ClientId"
Write-Host "Environment ID  : $EnvironmentId"
Write-Host ""
 
# ============================================================
# Step 1 - Get Microsoft Entra access token
# ============================================================
 
Write-Host "Getting Power Platform access token..."
 
$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
 
$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://api.powerplatform.com/.default"
    grant_type    = "client_credentials"
}

try {
 
    $TokenResponse = Invoke-RestMethod `
        -Uri $TokenUri `
        -Method Post `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $TokenBody
}
catch {
 
    Write-Error "Failed to obtain access token."
    Write-Error $_.Exception.Message
 
    exit 1
}

$AccessToken = $TokenResponse.access_token
 
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Access token was not returned."
}
 
Write-Host "Access token obtained successfully."
Write-Host ""

# ============================================================
# Step 2 - Call Power Platform Cloud Flows API
# ============================================================

$ApiUri = "https://api.powerplatform.com/powerautomate/environments/$EnvironmentId/cloudFlows?api-version=2024-10-01"

Write-Host "Calling Power Platform Cloud Flows API..."
Write-Host "API URL:"
Write-Host $ApiUri
Write-Host ""

$Headers = @{
    Authorization = "Bearer $AccessToken"
    Accept        = "application/json"
}

try {
 
    $Response = Invoke-RestMethod `
        -Uri $ApiUri `
        -Method Get `
        -Headers $Headers
}
catch {
 
    Write-Error "Failed to retrieve Power Automate flows."
 
    if ($_.Exception.Response) {
        Write-Error "HTTP request failed."
    }
 
    Write-Error $_.Exception.Message
 
    exit 1

}

# ============================================================
# Step 3 - Validate response
# ============================================================

if ($null -eq $Response) {
 
    Write-Host "No response received."
 
    exit 1
}

# The API returns a collection under 'value'.
$Flows = @($Response.value)

Write-Host "============================================================"
Write-Host "                 FLOW INFORMATION"
Write-Host "============================================================"
Write-Host ""

Write-Host "Total flows returned: $($Flows.Count)"
Write-Host ""
 
# ============================================================
# Step 4 - Display flow information
# ============================================================

if ($Flows.Count -eq 0) {
 
    Write-Host "No cloud flows were returned."
    Write-Host ""
    
}
else {
 
    $Counter = 0
 
    foreach ($Flow in $Flows) {
 
        $Counter++
        
        Write-Host "------------------------------------------------------------"
        Write-Host "Flow #$Counter"
        Write-Host "------------------------------------------------------------"

        # Display common properties returned by the API.
        Write-Host "Display Name : $($Flow.displayName)"
        Write-Host "Workflow ID  : $($Flow.workflowId)"
        Write-Host "Resource ID   : $($Flow.resourceId)"
 
        # Try several possible status/state properties.
        Write-Host "State        : $($Flow.state)"
        Write-Host "State Code   : $($Flow.stateCode)"
        Write-Host "Status       : $($Flow.status)"
 
        # Display other useful information when available.
        Write-Host "Created On   : $($Flow.createdOn)"
        Write-Host "Modified On  : $($Flow.modifiedOn)"
        Write-Host "Owner ID     : $($Flow.ownerId)"
 
        Write-Host ""
    }
}

# ============================================================
# Step 5 - Display raw JSON for investigation
# ============================================================

Write-Host ""
Write-Host "============================================================"
Write-Host "             RAW API RESPONSE SUMMARY"
Write-Host "============================================================"
Write-Host ""

Write-Host ($Response | ConvertTo-Json -Depth 20)

Write-Host ""
Write-Host "============================================================"
Write-Host "               FLOW CHECK COMPLETED"
Write-Host "============================================================"
