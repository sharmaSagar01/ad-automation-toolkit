<#
.SYNOPSIS
    Bulk creates AD users from CSV file.
.EXAMPLE
    .\Import-BulkUsers.ps1 -CSVPath ".\data\sample-users.csv"
#>

param (
    [Parameter(Mandatory)] [string] $CSVPath
)

Import-Module ActiveDirectory

$LogPath  = "C:\Logs\Onboarding"
$LogFile = "$LogPath\onboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"


# ── Create log directory if missing ──────────────────────────────

if(-not (Test-Path $LogPath)){
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $Entry -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } elseif($Level -eq "DONE") {"Green"} else { "Cyan" })

    Add-Content -Path $LogFile -Value $Entry
}

# ── Validate CSV ──────────────────────────────────────────────────
if (-not (Test-Path $CSVPath)) {
    Write-Log "CSV file not found: $CSVPath" "ERROR"
    exit 1
}

$Users   = Import-Csv -Path $CSVPath
$Success = 0
$Failed  = 0
$Skipped = 0
$Results = @()

Write-Log "Starting bulk user import -- $($Users.Count) users found in CSV" 

foreach ($Row in $Users) 
{
    $FirstName  = $Row.FirstName.Trim()
    $LastName   = $Row.LastName.Trim()
    $Username   =  ($FirstName.Substring(0,1) +$LastName).ToLower()

    # Skip if user already exists
    if (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue) {
        Write-Log " $Username already exists - skipping." "WARN"
        $Skipped++
        $Results += [PSCustomObject]@{ Username=$Username; Name="$FirstName $LastName"; Status = "Skipped"; Reason = "Already exists" }
        continue
    }

    try{
        $params = @{
            FirstName  = $FirstName
            LastName   = $LastName
            Department = $Row.Department
            JobTitle   = $Row.JobTitle
            Manager    = $Row.Manager
        }

        & .\New-UserOnboard.ps1 @params
        # #Call the onboard script login inline
        # & .\New-UserOnboard.ps1 `
        #     -FirstName $FirstName `
        #     -LastName $LastName `
        #     -Department $Row.Department `
        #     -JobTitle $Row.JobTitle `
        #     -Manager $Row.Manager

        $Success++
        $Results += [PSCustomObject]@{ Username=$Username; Name="$FirstName $LastName"; Status="Created"; Reason="" }
        Write-Log "Successfully created $Username"
    }
    catch{
        $Failed++
        $Results += [PSCustomObject]@{ Username=$Username; Name="$FirstName $LastName"; Status="Failed"; Reason=$_.Exception.Message }
        Write-Log "[FAIL] $Username - $($_.Exception.Message)" "ERROR"
    }
}

# ── Summary ───────────────────────────────────────────────────────
Write-Log "--------------------------------------------------------" 
Write-Log " Bulk Import Complete" 
Write-Log "--------------------------------------------------------" 
Write-Log " Created : $Success" 
Write-Log " Skipped : $Skipped" 
Write-Log " Failed  : $Failed"  
Write-Log "--------------------------------------------------------" 

$ReportPath = ".\data\import-results-$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$Results | Export-Csv -Path $ReportPath -NoTypeInformation
Write-Log "Results saved to: $ReportPath"
Write-Log ""

Write-Host "[DONE] Full Logs has been Saved. Review log: $LogFile`n" -ForegroundColor Green
