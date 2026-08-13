$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==============================================="
Write-Host "TESTING POWER AUTOMATE FLOW API"
Write-Host "==============================================="
Write-Host ""

# =================================================
# Environment Variables
# =================================================

$TenantId     = $env:TENANT_ID
$ClientId     = $env:CLIENT_ID
$ClientSecret = $env:CLIENT_SECRET

# Replace with your Environment ID
$EnvironmentId = "24b559b0-ad76-ebfe-8eeb-07695bb8f305"

# =================================================
# Validation
# =================================================

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    throw "TENANT_ID not supplied."
}

if ([string]::IsNullOrWhiteSpace($ClientId)) {
    throw "CLIENT_ID not supplied."
}

if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw "CLIENT_SECRET not supplied."
}

# =================================================
# Request Flow API Token
# =================================================

Write-Host "Getting Power Automate token..."

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

if ([string]::IsNullOrWhiteSpace($AccessToken)) {
    throw "Unable to retrieve Flow API token."
}

Write-Host "Token acquired successfully."
Write-Host ""

# =================================================
# Call Flow API
# =================================================

$Headers = @{
    Authorization = "Bearer $AccessToken"
    Accept        = "application/json"
}

$FlowsUrl = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/$EnvironmentId/flows?api-version=2016-11-01"

Write-Host "Calling Flow API..."
Write-Host $FlowsUrl
Write-Host ""

try {

    $Response = Invoke-RestMethod `
        -Method Get `
        -Uri $FlowsUrl `
        -Headers $Headers

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "FLOW API SUCCESS"
    Write-Host "==============================================="
    Write-Host ""

    Write-Host "Flow Count:"
    Write-Host $Response.value.Count
    Write-Host ""

    foreach ($Flow in ($Response.value | Select-Object -First 5)) {

        Write-Host "----------------------------------------"

        if ($Flow.properties.displayName) {
            Write-Host "Display Name : $($Flow.properties.displayName)"
        }

        Write-Host "Flow Id      : $($Flow.name)"

        Write-Host "----------------------------------------"
    }

    Write-Host ""
    Write-Host "RAW JSON"
    Write-Host "==============================================="

    $Response | ConvertTo-Json -Depth 25
}
catch {

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "FLOW API FAILED"
    Write-Host "==============================================="
    Write-Host ""

    Write-Host $_.Exception.Message

    if ($_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message
    }

    throw
}
