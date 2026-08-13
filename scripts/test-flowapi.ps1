$EnvironmentId = "24b559b0-ad76-ebfe-8eeb-07695bb8f305"

$FlowTokenBody = @{
    client_id     = $env:CLIENT_ID
    client_secret = $env:CLIENT_SECRET
    scope         = "https://service.flow.microsoft.com/.default"
    grant_type    = "client_credentials"
}

$TokenResponse = Invoke-RestMethod `
    -Method Post `
    -Uri "https://login.microsoftonline.com/$env:TENANT_ID/oauth2/v2.0/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body $FlowTokenBody

$Headers = @{
    Authorization = "Bearer $($TokenResponse.access_token)"
    Accept        = "application/json"
}

$FlowsUrl = "https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple/environments/$EnvironmentId/flows?api-version=2016-11-01"

$Response = Invoke-RestMethod `
    -Method Get `
    -Uri $FlowsUrl `
    -Headers $Headers

$Response.value |
    Select-Object name,@{N='DisplayName';E={$_.properties.displayName}} |
    Format-Table -AutoSize
