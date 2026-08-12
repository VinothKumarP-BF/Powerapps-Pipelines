$ErrorActionPreference = "Stop"
 
Write-Host ""
Write-Host "================================================="
Write-Host "Power Automate Flow Health Check"
Write-Host "================================================="
Write-Host ""
 
# =================================================
# Environment details
# =================================================
 
$EnvironmentUrl = $env:DEV_ENV_URL
$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET
 
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
 
# Remove trailing slash from environment URL
$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')
 
Write-Host "Environment: $EnvironmentUrl"
Write-Host ""
 
# =================================================
# Step 1 - Authenticate using PAC
# =================================================
 
Write-Host "Authenticating..."
 
pac auth create `
    --url $EnvironmentUrl `
    --applicationId $ClientId `
    --clientSecret $ClientSecret `
    --tenant $TenantId
 
if ($LASTEXITCODE -ne 0) {
    throw "PAC Authentication failed."
}
 
Write-Host "Authentication successful."
Write-Host ""
 
# =================================================
# Step 2 - Get PAC authentication token
# =================================================
 
Write-Host "Getting authentication token..."
 
$authInfo = pac auth list
 
if ($LASTEXITCODE -ne 0) {
    throw "Unable to retrieve PAC authentication information."
}
 
Write-Host "PAC authentication profile is available."
Write-Host ""
 
# =================================================
# Step 3 - Query Dataverse
# =================================================
 
Write-Host "Getting Power Automate flows..."
 
$select = "name,statecode,statuscode,workflowid,category"
$filter = "category eq 5"
 
$ApiUrl = "$EnvironmentUrl/api/data/v9.2/workflows?`$select=$select&`$filter=$filter"
 
Write-Host "Dataverse API:"
Write-Host $ApiUrl
Write-Host ""
 
# =================================================
# Step 4 - Get access token for Dataverse
# =================================================
 
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
        -Uri $TokenUrl `
        -Method Post `
        -ContentType "application/x-www-form-urlencoded" `
        -Body $TokenBody
 
}
catch {
 
    Write-Host ""
    Write-Host "================================================="
    Write-Host "TOKEN REQUEST FAILED"
    Write-Host "================================================="
    Write-Host $_.Exception.Message
 
    exit 1
}
 
$AccessToken = $TokenResponse.access_token
 
if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Dataverse access token was not returned."
}
 
Write-Host "Dataverse access token obtained successfully."
Write-Host ""
 
# =================================================
# Step 5 - Call Dataverse Web API
# =================================================
 
$Headers = @{
    Authorization = "Bearer $AccessToken"
    Accept        = "application/json"
    "OData-MaxVersion" = "4.0"
    "OData-Version"    = "4.0"
}
 
try {
 
    $Response = Invoke-RestMethod `
        -Uri $ApiUrl `
        -Method Get `
        -Headers $Headers
 
}
catch {
 
    Write-Host ""
    Write-Host "================================================="
    Write-Host "DATAVERSE API ERROR"
    Write-Host "================================================="
 
    Write-Host ""
    Write-Host "Error:"
    Write-Host $_.Exception.Message
 
    if ($_.ErrorDetails.Message) {
        Write-Host ""
        Write-Host "API Response:"
        Write-Host $_.ErrorDetails.Message
    }
 
    Write-Host ""
    Write-Host "================================================="
 
    exit 1
}
 
# =================================================
# Step 6 - Process flows
# =================================================
 
$Flows = @($Response.value)
 
Write-Host ""
Write-Host "================================================="
Write-Host "FLOW STATUS"
Write-Host "================================================="
Write-Host ""
 
Write-Host "Total Flows Found: $($Flows.Count)"
Write-Host ""
 
$disabled = 0
$enabled  = 0
 
foreach ($flow in $Flows) {
 
    if ($flow.statecode -eq 1) {
        $state = "Enabled"
        $enabled++
    }
    else {
        $state = "Disabled"
        $disabled++
    }
 
    Write-Host "------------------------------------"
    Write-Host "Name      : $($flow.name)"
    Write-Host "State     : $state"
    Write-Host "StateCode : $($flow.statecode)"
    Write-Host "StatusCode: $($flow.statuscode)"
    Write-Host "WorkflowId: $($flow.workflowid)"
}
 
# =================================================
# Step 7 - Summary
# =================================================
 
Write-Host ""
Write-Host "================================================="
Write-Host "FLOW HEALTH SUMMARY"
Write-Host "================================================="
Write-Host ""
 
Write-Host "Total Flows   : $($Flows.Count)"
Write-Host "Enabled Flows : $enabled"
Write-Host "Disabled Flows: $disabled"
 
Write-Host ""
 
if ($disabled -gt 0) {
 
    Write-Host "WARNING: Disabled flows were detected."
 
    throw "$disabled flow(s) are disabled."
 
}
else {
 
    Write-Host "SUCCESS: All flows are enabled."
}
 
Write-Host ""
Write-Host "================================================="
Write-Host "Flow health check completed."
Write-Host "================================================="
