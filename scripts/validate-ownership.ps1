param(
    [Parameter(Mandatory=$true)]
    [string]$ReleaseFolder,

    [Parameter(Mandatory=$true)]
    [string]$ConfigFile
)

Write-Host "Loading configuration..."
$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

$violations = @()

foreach($solutionRule in $config.ownershipRules.PSObject.Properties)
{
    $solutionName = $solutionRule.Name
    $allowMetadata = $solutionRule.Value.allowEntityMetadata

    if($allowMetadata)
    {
        Write-Host "Skipping $solutionName (metadata owner)"
        continue
    }

    $solutionPath = Join-Path $ReleaseFolder $solutionName

    if(!(Test-Path $solutionPath))
    {
        Write-Host "Solution folder not found: $solutionName"
        continue
    }

    $entityFolder = Join-Path $solutionPath "Entities"

    if(Test-Path $entityFolder)
    {
        Get-ChildItem $entityFolder -Directory | ForEach-Object {

            $violations += @{
                Solution = $solutionName
                Entity = $_.Name
            }
        }
    }

    # Optional informational logging only
    Get-ChildItem $solutionPath -Recurse -Filter "solution.xml" -ErrorAction SilentlyContinue |
    ForEach-Object {

        $content = Get-Content $_.FullName -Raw

        if($content -match "MissingDependency")
        {
            Write-Host ""
            Write-Host "INFO: Missing dependencies detected in $solutionName"
            Write-Host "These are allowed because cross-solution references are supported."
            Write-Host ""
        }
    }
}

if($violations.Count -gt 0)
{
    Write-Host ""
    Write-Host "========================================="
    Write-Host "OWNERSHIP VIOLATIONS DETECTED"
    Write-Host "========================================="
    Write-Host ""

    foreach($violation in $violations)
    {
        Write-Host "Solution : $($violation.Solution)"
        Write-Host "Entity   : $($violation.Entity)"
        Write-Host ""
    }

    throw "Validation failed. Non-DataModel solution contains entity metadata."
}

Write-Host ""
Write-Host "✅ Ownership validation passed."
Write-Host "Reference dependencies are allowed."
