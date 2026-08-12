$ErrorActionPreference = "Stop"
 
Write-Host ""
Write-Host "================================================="
Write-Host "Power Automate Flow Health Check"
Write-Host "================================================="
Write-Host ""
 
# Authenticate using PAC
Write-Host "Authenticating..."
 
pac auth create `
    --url $env:DEV_ENV_URL `
    --applicationId $env:CLIENT_ID `
    --clientSecret $env:CLIENT_SECRET `
    --tenant $env:TENANT_ID
 
if ($LASTEXITCODE -ne 0) {
    throw "PAC Authentication failed."
}
 
Write-Host "Authentication successful."
Write-Host ""
 
# Get flows using Dataverse Web API
Write-Host "Getting flows..."
 
$query = @"
workflows?
`$select=name,statecode,statuscode,workflowid&
`$filter=category eq 5
"@
 
$result = pac env fetch `
    --environment $env:DEV_ENV_URL `
    --path "/api/data/v9.2/$query"
 
$json = $result | ConvertFrom-Json
 
Write-Host ""
Write-Host "Total Flows Found: $($json.value.Count)"
Write-Host ""
 
$disabled = 0
 
foreach ($flow in $json.value)
{
    $state = if ($flow.statecode -eq 1) {
        "Enabled"
    }
    else {
        "Disabled"
        $disabled++
    }
 
    Write-Host "------------------------------------"
    Write-Host "Name      : $($flow.name)"
    Write-Host "State     : $state"
    Write-Host "WorkflowId: $($flow.workflowid)"
}
 
Write-Host ""
Write-Host "===================================="
Write-Host "Disabled Flows: $disabled"
Write-Host "===================================="
 
if ($disabled -gt 0)
{
    throw "$disabled flows are disabled."
}
