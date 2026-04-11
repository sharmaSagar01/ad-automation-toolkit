<#
.SYNOPSIS
    Runs a full Active Directory health check and outputs a report.
.EXAMPLE
    .\Get-ADHealthCheck.ps1
    .\Get-ADHealthCheck.ps1 -ExportHTML

#>

param (
    [switch] $ExportHTML
)

Import-Module ActiveDirectory

$Domain     = Get-ADDomain
$Forest     = Get-ADForest
$DomainName = $Domain.DNSRoot
$Timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$Issues     = @()

function Write-Section { param([string]$Title)
        Write-Host " -- $Title " + ("-" * (50 - $Title.Length)) -ForegroundColor DarkCyan
}

function Write-Check { param([string]$Label, [string]$Value, [bool]$OK = $true )
    $Icon   = if ($OK) { "[OK]  " } else { "[FAIL]" }
    $Color  = if ($OK) { "Green" } else { "Red" }
    Write-Host "  $Icon $Label : $Value" -ForegroundColor $Color
    if (-not $OK) { $script:Issues += "$Label : $Value" }
}

Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host "   Active Directory Health Check Report   " -ForegroundColor Cyan
Write-Host "------------------------------------------" -ForegroundColor Cyan
Write-Host "  Domain    : $DomainName"
Write-Host "  Forest    : $($Forest.Name)"
Write-Host "  Run at    : $Timestamp"

# ── Domain Controllers ────────────────────────────────────────────
Write-Section "Domain Controllers"
$DCs = Get-ADDomainController -Filter *
foreach ($DC in $DCs){
    $Ping = Test-Connection -ComputerName $DC.HostName -Count 1 -Quiet
    Write-Check "$($DC.Name) ($($DC.IPv4Address))" $(if ($Ping) { "Reachable" } else { "UNREACHABLE" }) $Ping

    # Check SYSVOL and NETLOGON shares
    foreach ($Share in @("SYSVOL","NETLOGON")) {
        $Path = "\\$($DC.HostName)\$Share"
        $OK   = Test-Path $Path -ErrorAction SilentlyContinue
        Write-Check "  $Share share on $($DC.Name)" $(if ($OK) { "Available" } else { "NOT FOUND" }) $OK
    }

}

# ── FSMO Roles ────────────────────────────────────────────────────
Write-Section "FSMO Role Holders"
$FSMORoles = @{
    "Schema Master"          = $Forest.SchemaMaster
    "Domain Naming Master"   = $Forest.DomainNamingMaster
    "PDC Emulator"           = $Domain.PDCEmulator
    "RID Master"             = $Domain.RIDMaster
    "Infrastructure Master"  = $Domain.InfrastructureMaster
}
foreach ($Role in $FSMORoles.GetEnumerator()) {
    Write-Check $Role.Key $Role.Value $true
}

# ── AD Replication ────────────────────────────────────────────────
Write-Section "AD Replication Status"
try {
    $ReplResult = repadmin /replsummary 2>&1
    $HasErrors  = $ReplResult -match "error|fail" -and $ReplResult -notmatch "0 errors"
    Write-Check "Replication summary" $(if (-not $HasErrors) { "No errors detected" } else { "Errors found - run: repadmin /showrepl" }) (-not $HasErrors)
}
catch {
    Write-Check "Replication check" "Could not run repadmin" $false
}

# ── Account Summary ───────────────────────────────────────────────
Write-Section "Account Summary"
$TotalUsers    = (Get-ADUser -Filter *).Count
$EnabledUsers  = (Get-ADUser -Filter { Enabled -eq $true }).Count
$DisabledUsers = (Get-ADUser -Filter { Enabled -eq $false }).Count
$LockedUsers   = (Search-ADAccount -LockedOut -UsersOnly).Count
$ExpiredPwd    = (Search-ADAccount -PasswordExpired -UsersOnly).Count

Write-Host " Total users    : $TotalUsers"
Write-Host " Enabled        : $EnabledUsers"
Write-Host " Disabled       : $DisabledUsers"
Write-Check "Locked accounts"    "$LockedUsers locked"  ($LockedUsers -eq 0)
Write-Check "Expired passwords"  "$ExpiredPwd expired"  ($ExpiredPwd -eq 0)


# ── Final verdict ─────────────────────────────────────────────────
Write-Host "----------------------------------------------" -ForegroundColor DarkGray
if ($Issues.Count -eq 0) {
    Write-Host "  RESULT: All checks passed. Domain is healthy." -ForegroundColor Green
} else {
    Write-Host "  RESULT: $($Issues.Count) issue(s) found:" -ForegroundColor Red
    $Issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
Write-Host "------------------------------------------------" -ForegroundColor DarkGray