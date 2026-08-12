$ErrorActionPreference = "Stop"
 
Write-Host ""
Write-Host "============================================================"
Write-Host "       Power Automate Flow Health Check"
Write-Host "============================================================"
Write-Host ""
 
# ============================================================
# Step 1 - Read GitHub environment variables
# ============================================================
 
$TenantId = $env:TENANT_ID
$ClientId = $env:CLIENT_ID
$ClientSecret = $env:CLIENT_SECRET
$EnvironmentId = $env:DEV_ENV_ID
 
# ============================================================
# Step 2 - Validate required variables
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
# Step 3 - Get Microsoft Entra access token
# ============================================================
 
Write-Host "Getting Power Platform access token..."
 
$TokenUri = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
 
Write-Host "Token endpoint:"
Write-Host $TokenUri
Write-Host ""
 
$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://api.powerplatform.com/.default"
    grant_type    = "client_credentials"
}
 
try {
 
    $TokenResponse = Invoke-RestMethod -Uri $TokenUri -Method Post -ContentType "application/x-www-form-urlencoded" -Body $TokenBody
 
}
catch {
 
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "             TOKEN REQUEST FAILED"
    Write-Host "============================================================"
 
    Write-Host ""
    Write-Host "Exception:"
    Write-Host $_.Exception.Message
 
    if ($null -ne $_.Exception.Response) {
        Write-Host ""
        Write-Host "HTTP Status Code:"
 
        try {
            Write-Host ([int]$_.Exception.Response.StatusCode)
        }
        catch {
            Write-Host "Unable to determine HTTP status code."
        }
 
        Write-Host ""
        Write-Host "HTTP Status Description:"
 
        try {
            Write-Host $_.Exception.Response.StatusDescription
        }
        catch {
            Write-Host "Unable to determine HTTP status description."
        }
    }
 
    Write-Host ""
    Write-Host "============================================================"
 
    exit 1
}
 
$AccessToken = $TokenResponse.access_token
 
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Access token was not returned."
}
 
Write-Host "Access token obtained successfully."
Write-Host ""
 
# ============================================================
# Step 4 - Build Power Platform API URL
# ============================================================
 
$ApiUri = "https://api.powerplatform.com/powerautomate/environments/$EnvironmentId/cloudFlows?api-version=2024-10-01%22
 
Write-Host "Calling Power Platform Cloud Flows API..."
Write-Host "API URL:"
Write-Host $ApiUri
Write-Host ""
 
# ============================================================
# Step 5 - Create authorization headers
# ============================================================
 
$Headers = @{
    Authorization = "Bearer $AccessToken"
    Accept        = "application/json"
}
 
# ============================================================
# Step 6 - Call Power Platform Cloud Flows API
# ============================================================
 
try {
 
    $Response = Invoke-RestMethod -Uri $ApiUri -Method Get -Headers $Headers
 
}
catch {
 
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "             POWER PLATFORM API ERROR"
    Write-Host "============================================================"
 
    Write-Host ""
    Write-Host "Exception:"
    Write-Host $_.Exception.Message
 
    if ($null -ne $_.Exception.Response) {
 
        Write-Host ""
        Write-Host "HTTP Status Code:"
 
        try {
            Write-Host ([int]$_.Exception.Response.StatusCode)
        }
        catch {
            Write-Host "Unable to determine HTTP status code."
        }
 
        Write-Host ""
        Write-Host "HTTP Status Description:"
 
        try {
            Write-Host $_.Exception.Response.StatusDescription
        }
        catch {
            Write-Host "Unable to determine HTTP status description."
        }
    }
 
    Write-Host ""
    Write-Host "API Error Response:"
 
    try {
 
        if ($null -ne $_.ErrorDetails.Message) {
            Write-Host $_.ErrorDetails.Message
        }
        else {
            Write-Host "No detailed API error response was returned."
        }
 
    }
    catch {
 
        Write-Host "Unable to read API error response."
    }
 
    Write-Host ""
    Write-Host "============================================================"
 
    exit 1
}
 
# ============================================================
# Step 7 - Validate response
# ============================================================
 
if ($null -eq $Response) {
 
    Write-Host "No response received from Power Platform API."
 
    exit 1
}
 
# ============================================================
# Step 8 - Extract flows
# ============================================================
 
$Flows = @($Response.value)
 
Write-Host ""
Write-Host "============================================================"
Write-Host "                 FLOW INFORMATION"
Write-Host "============================================================"
Write-Host ""
 
Write-Host "Total flows returned: $($Flows.Count)"
Write-Host ""
 
# ============================================================
# Step 9 - Display flow information
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
 
        Write-Host "Display Name : $($Flow.displayName)"
        Write-Host "Workflow ID  : $($Flow.workflowId)"
        Write-Host "Resource ID  : $($Flow.resourceId)"
        Write-Host "State        : $($Flow.state)"
        Write-Host "State Code   : $($Flow.stateCode)"
        Write-Host "Status       : $($Flow.status)"
        Write-Host "Created On   : $($Flow.createdOn)"
        Write-Host "Modified On  : $($Flow.modifiedOn)"
        Write-Host "Owner ID     : $($Flow.ownerId)"
 
        Write-Host ""
    }
}
 
# ============================================================
# Step 10 - Display raw API response
# ============================================================
 
Write-Host ""
Write-Host "============================================================"
Write-Host "             RAW API RESPONSE"
Write-Host "============================================================"
Write-Host ""
 
Write-Host ($Response | ConvertTo-Json -Depth 20)
 
# ============================================================
# Step 11 - Completed
# ============================================================
 
Write-Host ""
Write-Host "============================================================"
Write-Host "               FLOW CHECK COMPLETED"
Write-Host "============================================================"
Write-Host ""
