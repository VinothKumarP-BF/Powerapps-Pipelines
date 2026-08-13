$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================="
Write-Host "TEST FLOW API"
Write-Host "==============================================="
Write-Host ""

# =================================================
# CONFIGURATION
# =================================================

$TenantId       = $env:TENANT_ID
$ClientId       = $env:CLIENT_ID
$ClientSecret   = $env:CLIENT_SECRET

$EnvironmentId = "24b559b0-ad76-ebfe-8eeb-07695bb8f305"

# =================================================
# VALIDATION
# =================================================

if (:IsNullOrWhiteSpace($TenantId)) {
    throw "TENANT_ID is missing"
}

if (:IsNullOrWhiteSpace($ClientId)) {
    throw "CLIENT_ID is missing"
}

if (:IsNullOrWhiteSpace($ClientSecret)) {
    throw "CLIENT_SECRET is missing"
}

# =================================================
# GET FLOW TOKEN
# =================================================

Write-Host "Getting Flow access token..."

$TokenBody = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://service.flow.microsoft.com/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token

Write-Host "Token Retrieved : $(-not [string]::IsNullOrWhiteSpace($AccessToken))"
Write-Host "Token Length    : $($AccessToken.Length)"
Write-Host ""

# =================================================
# BUILD HEADERS
# =================================================

$Headers = @{
    Authorization       = "Bearer $AccessToken"
    Accept              = "application/json"
    "x-ms-client-scope" = "admin"
}

# =================================================
# CALL FLOW API
# =================================================

$FlowsUrl = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/$EnvironmentId/flows?api-version=2016-11-01"

Write-Host "Calling API:"
Write-Host $FlowsUrl
Write-Host ""

try {

    $Response = Invoke-RestMethod `
        -Method Get `
        -Uri $FlowsUrl `
        -Headers $Headers

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "SUCCESS"
    Write-Host "==============================================="
    Write-Host ""

    foreach ($Flow in ($Response.value | Select-Object -First 20)) {

        Write-Host "----------------------------------------"
        Write-Host "Flow Id      : $($Flow.name)"

        if ($Flow.properties.displayName) {
            Write-Host "Display Name : $($Flow.properties.displayName)"
        }

        Write-Host "----------------------------------------"
    }
}
catch {

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "API FAILED"
    Write-Host "==============================================="
    Write-Host ""

    Write-Host "Exception:"
    Write-Host $_.Exception.Message
    Write-Host ""

    if ($_.ErrorDetails.Message) {
        Write-Host "Error Details:"
        Write-Host $_.ErrorDetails.Message
    }

    Write-Host ""

    if ($_.Exception.Response) {
        Write-Host "Status Code:"
        Write-Host $_.Exception.Response.StatusCode
    }
}
