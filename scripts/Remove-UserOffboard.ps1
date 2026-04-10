<#
.SYNOPSIS
    Automates user offboarding - disable account, remove from groups, 
    moves to disabled OU.
    
.EXAMPLE
    .\Remove-UserOffboard.ps1 -Username "jsmith"
#>

param (
    [Parameter(Mandatory)] [string] $Username
)

Import-Module ActiveDirectory

$DomainDN = "DC=InfoTech,DC=com"
$DisabledOU = "OU=Disabled_Accounts, $DomainDN"
$LogPath  = "C:\Logs\Offboarding"
$LogFile = "$LogPath\offboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ── Create log directory if missing ──────────────────────────────

if(-not (Test-Path $LogPath)){
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $Entry -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } elseif ($Level -eq "WARN") { "Yellow" } else { "Cyan" })


    Add-Content -Path $LogFile -Value $Entry
}

# ── Find the user ─────────────────────────────────────────────────
Write-Log "Starting offboarding for : $Username"
$User = Get-ADUser -Filter {SamAccountName -eq $Username} -Properties MemberOf, Description -ErrorAction SilentlyContinue

if (-not $User){
    Write-Log "User '$Username' not found in AD." "ERROR"
    exit 1
}

Write-Log "Found User: $($User.DisplayName) | DN: $($User.DistinguishedName)"

# ── Disable the account ───────────────────────────────────────────

try{
    Disable-ADAccount -Identity $Username
    Write-Log "Account Disabled."
} 
catch {Write-Log "Failed to disable account: $_" "ERROR"}

# ── Update description with offboard date ─────────────────────────

try {
    Set-ADUser -Identity $Username -Description "OFFBOARDED: $(Get-Date -Format 'yyyy-MM-dd')"
    Write-Log "Description updated with offboard date."
}
catch {Write-Log "Could not update description: $_" "WARN"}

# ── Remove from all groups (except Domain Users) ──────────────────

$Groups = $User.MemberOf

foreach($GroupDN in $Groups){
    try{
        $GroupName = (Get-ADGroup -Identity $GroupDN).Name
        Remove-ADGroupMember -Identity $GroupDN -Members $Username -Confirm:$false
        Write-Log "Removed from group: $GroupName"
    }
    catch {Write-Log "Could not remove from group '$GroupDN': $_" "WARN"}
}
# ── Create Disabled_Users OU if it doesn't exist ──────────────────
try {
    Get-ADOrganizationalUnit -Identity $DisabledOU -ErrorAction Stop | Out-Null
}
catch {
    New-ADOrganizationalUnit -Name "Disabled_Accounts" -Path $DomainDN
    Write-Log "Created Disabled_Accounts OU."
}

# ── Move to Disabled_Users OU ─────────────────────────────────────
try {
    Move-ADObject -Identity $User.DistinguishedName -TargetPath $DisabledOU
    Write-Log "User moved to Disabled_Accounts OU."
}
catch {Write-Log "Could not move user : $_" "WARN"}

Write-Log "Offboarding complete. Log saved to: $LogFile"
Write-Host "`n[DONE] $Username has been offboarded. Review log: $LogFile`n" -ForegroundColor Green


