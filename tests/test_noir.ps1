# Structural tests for noir.ps1. The step table is inspected through the
# parser's AST so nothing in the script executes; the only execution is a
# read-only -Doctor run at the end. Windows PowerShell 5.1 compatible.

$script:pass = 0
$script:fail = 0
function Assert {
    param([bool]$Condition, [string]$Name)
    if ($Condition) { $script:pass++; Write-Host "[PASS] $Name" }
    else { $script:fail++; Write-Host "[FAIL] $Name" }
}

Write-Host "============================================================"
Write-Host " noir.ps1 Test Suite"
Write-Host "============================================================"
Write-Host ""

$noir = Join-Path $PSScriptRoot "..\noir.ps1"
Assert (Test-Path $noir) "noir.ps1 exists"

$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($noir, [ref]$null, [ref]$parseErrors)
Assert (-not $parseErrors) "noir.ps1 parses without errors"

# -- Step table shape ------------------------------------------
# Find the $steps assignment and take only its top-level hashtables;
# Actions may contain nested hashtable literals of their own.

$stepsAssign = $ast.Find({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
    $n.Left.Extent.Text -eq '$steps'
}, $true)
Assert ($null -ne $stepsAssign) "step table (`$steps) found"

$stepAsts = @()
if ($stepsAssign) {
    $allHashtables = $stepsAssign.Right.FindAll({
        param($n) $n -is [System.Management.Automation.Language.HashtableAst]
    }, $true)
    $stepAsts = @($allHashtables | Where-Object {
        $parent = $_.Parent
        $nested = $false
        while ($null -ne $parent -and $parent -ne $stepsAssign) {
            if ($parent -is [System.Management.Automation.Language.HashtableAst]) { $nested = $true; break }
            $parent = $parent.Parent
        }
        -not $nested
    })
}
Assert ($stepAsts.Count -ge 20) "step table has a plausible number of steps ($($stepAsts.Count))"

$names = @()
$missingFields = @()
$missingCategory = @()
$badCategory = @()
$validCategories = @("Visual", "Application", "Configuration")

foreach ($stepAst in $stepAsts) {
    $keys = @{}
    foreach ($pair in $stepAst.KeyValuePairs) {
        $keys[$pair.Item1.Extent.Text.Trim('"', "'")] = $pair.Item2.Extent.Text.Trim('"', "'")
    }
    $name = if ($keys.ContainsKey("Name")) { $keys["Name"] } else { "<unnamed step>" }
    $names += $name

    foreach ($required in @("Name", "Prompt", "Detail", "Action")) {
        if (-not $keys.ContainsKey($required)) { $missingFields += "$name is missing $required" }
    }
    if ($keys.ContainsKey("IsGatekeeper")) { continue }
    if (-not $keys.ContainsKey("Category")) {
        $missingCategory += $name
    } elseif ($validCategories -notcontains $keys["Category"]) {
        $badCategory += "$name has category '$($keys["Category"])'"
    }
}

Assert ($missingFields.Count -eq 0) "every step has Name/Prompt/Detail/Action$(if ($missingFields) { " - " + ($missingFields -join '; ') })"
Assert ($missingCategory.Count -eq 0) "every non-gatekeeper step has a Category$(if ($missingCategory) { " - missing: " + ($missingCategory -join ', ') })"
Assert ($badCategory.Count -eq 0) "every Category is Visual/Application/Configuration$(if ($badCategory) { " - " + ($badCategory -join '; ') })"
Assert (@($names | Group-Object | Where-Object { $_.Count -gt 1 }).Count -eq 0) "step names are unique"

# -- Doctor smoke test (read-only end-to-end run) --------------
# Executes every Check block against the current machine and must exit 0
# without changing anything.

$doctorOut = & powershell -NoProfile -ExecutionPolicy Bypass -File $noir -Doctor 2>&1
Assert ($LASTEXITCODE -eq 0) "-Doctor exits 0"
$doctorText = ($doctorOut | Out-String)
Assert ($doctorText -match "Nothing was changed") "-Doctor reports a read-only run"
Assert ($doctorText -match "dark-mode") "-Doctor lists the steps"

# -- Results ---------------------------------------------------

Write-Host ""
Write-Host "============================================================"
if ($script:fail -eq 0) {
    Write-Host " All $($script:pass) tests passed."
} else {
    Write-Host " $($script:pass) passed, $($script:fail) failed."
}
Write-Host "============================================================"
if ($script:fail -gt 0) { exit 1 }
exit 0
