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

# Solution Unique Name
$SolutionName = "POC_CR"

# =================================================
# Validation
# =================================================

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

$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/')

# =================================================
# Authenticate
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
# Get Access Token
# =================================================

$TokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "$EnvironmentUrl/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod `
    -Uri $TokenUrl `
    -Method Post `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token

if (:IsNullOrWhiteSpace($AccessToken)) {
    throw "Failed to obtain access token."
}

# =================================================
# Headers
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

Write-Host "Getting solution..."

$SolutionUrl = "$EnvironmentUrl/api/data/v9.2/solutions?`$select=solutionid,friendlyname,uniquename&`$filter=uniquename eq '$SolutionName'"

$SolutionResponse = Invoke-RestMethod `
    -Method Get `
    -Uri $
