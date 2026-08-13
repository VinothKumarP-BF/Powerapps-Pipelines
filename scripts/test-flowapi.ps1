$ErrorActionPreference = "Continue"

$EnvironmentId = "24b559b0-ad76-ebfe-8eeb-07695bb8f305"

Write-Host ""
Write-Host "==============================================="
Write-Host "TEST FLOW API"
Write-Host "==============================================="
Write-Host ""

# =================================================
# Get Token
# =================================================

$TokenBody = @{
    client_id     = $env:CLIENT_ID
    client_secret = $env:CLIENT_SECRET
    scope         = "https://service.flow.microsoft.com/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/$env:TENANT_ID/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $TokenBody

$AccessToken = $TokenResponse.access_token

Write-Host "Token Retrieved : $(-not [string]::IsNullOrWhiteSpace($AccessToken))"
Write-Host "Token Length    : $($AccessToken.Length)"
Write-Host ""

# =================================================
# HEADERS
# =================================================

$Headers = @{
    Authorization       = "Bearer $AccessToken"
    Accept              = "application/json"
    "x-ms-client-scope" = "admin"
}

Write-Host "Headers Created"
Write-Host ""

# =================================================
# API URL
# =================================================

$FlowUrl = "$EnvironmentUrl/api/data/v9.2/workflows($WorkflowId)"

$Flow = Invoke-RestMethod `
    -Method Get `
    -Uri $FlowUrl `
    -Headers $Headers

$Flow | ConvertTo-Json -Depth 100

Write-Host "Calling:"
Write-Host $FlowsUrl
Write-Host ""

# =================================================
# CALL API
# =================================================

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

    Write-Host "Flow Count:"
    Write-Host $Response.value.Count

    Write-Host ""

    foreach ($Flow in ($Response.value | Select-Object -First 10)) {

        Write-Host "----------------------------------------"

        Write-Host "Flow Id      : $($Flow.name)"

        if ($Flow.properties.displayName) {
            Write-Host "Display Name : $($Flow.properties.displayName)"
        }

        Write-Host "----------------------------------------"
    }

    Write-Host ""
    Write-Host "RAW RESPONSE"
    Write-Host "==============================================="

    $Response | ConvertTo-Json -Depth 20
}
catch {

    Write-Host ""
    Write-Host "==============================================="
    Write-Host "API FAILED"
    Write-Host "==============================================="
    Write-Host ""

    Write-Host "Exception Message:"
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
