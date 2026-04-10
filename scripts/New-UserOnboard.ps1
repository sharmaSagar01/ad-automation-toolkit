<#
.SYNOPSIS
    Automate new user onboarding  in Active Directory.
.DESCRIPTION
    Creates a new AD user, assigns them to the correct OU, and Security Groups, sets a temporary password, and enforces password change on first login.
.EXAMPLE
    .\New-UserOnboard.ps1 -FirstName "Jane" -LastName "Smith" -Department "IT_Staff" -JobTitle "Sys Admin" -Manager "paula.doe`
#>

param (
    [Parameter(Mandatory)] [string] $FirstName,
    [Parameter(Mandatory)] [string] $LastName,
    [Parameter(Mandatory)] [ValidateSet("IT","HR","Finance","Operations")][string] $Department,
    [Parameter(Mandatory)] [string] $JobTitle, [string] $Manager = ""
)

Import-Module ActiveDirectory

# --- Config ------------------------------------

$Domain = "InfoTech.com"
$DomainDN = "DC=InfoTech,DC=com"
$TempPassword =  ConvertTo-SecureString "apple@123" -AsPlainText -Force
$LogPath  = "C:\Logs\Onboarding"
$LogFile = "$LogPath\onboard_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Map departments to OU and Security Groups
$DeptMap = @{
    "IT"            = @{OU = "OU=All_Staff,$DomainDN"; Groups = @("IT_Support","All_Staff","Personal") }
    "HR"            = @{OU = "OU=All_Staff,$DomainDN"; Groups = @("HR","All_Staff","Personal") }
    "Finance"       = @{ OU = "OU=All_Staff,$DomainDN"; Groups = @("Finance","All_Staff","Personal") }
    "Operations"    = @{ OU = "OU=All_Staff,$DomainDN"; Groups = @("Operations","All_Staff","Personal") }

}



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

# ----------- Build user attributes ------------------------

$Username       = ($FirstName.Substring(0,1) + $LastName).ToLower()  #jsmith
$DisplayName    = "$FirstName $LastName"
$UPN            = "$Username@$Domain"  #jsmith@Infotech.com
$TargetOU       = $DeptMap[$Department].OU
$TargetGroups   = $DeptMap[$Department].Groups

Write-Log "Starting onboarding for : $Username" "DONE"
# Write-Host "`n[INFO] Creating user: $DisplayName ($Username)" -ForegroundColor Cyan

# --- Check for duplicate username -----------------------

if (Get-ADUser -Filter {SamAccountName -eq $Username} -ErrorAction SilentlyContinue) {
    Write-Log " User '$Username' already exists in AD. Exiting." "ERROR"
    exit 1
}

# ── Create the AD user ────────────────────────────────────────────

try{
    $UserParams = @{
        SamAccountName                  = $Username
        UserPrincipalName               = $UPN
        GivenName                       = $FirstName
        Surname                         = $LastName
        DisplayName                     = $DisplayName
        Name                            = $DisplayName
        Title                           = $JobTitle
        Department                      = $Department
        EmailAddress                    = $UPN
        AccountPassword                 = $TempPassword
        Enabled                         = $true
        ChangePasswordAtLogon           = $true
        Path                            = $TargetOU
    }

    if($Manager -ne "") {
        $ManagerObj = Get-ADUser -Filter { SamAccountName -eq $Manager} -ErrorAction SilentlyContinue
        if ($ManagerObj) { $UserParams["Manager"] = $ManagerObj.DistinguishedName }
    }

    New-ADUser @UserParams
    Write-Log "User Created in OU: $TargetOU" 
    # Write-Host "[SUCCESS] User Created in OU: $TargetOU" -ForegroundColor Green
}

catch {
    Write-Log "Could not create user: $_" "ERROR"
    # Write-Error "[ERROR] Couldn not create user: $_"
    exit 1
}

# ── Add to security group ─────────────────────────────────────────


   foreach ($group in $TargetGroups) {
        try {
                Add-ADGroupMember -Identity $group -Members $Username
                Write-Log "Added to group: $group" 
                # Write-Host "[OK]   Added to group: $group" -ForegroundColor Green
            }
        catch {
                Write-Log "Could not add to group '$group': $_" "WARN"
                # Write-Warning "[WARN] Could not add to group '$group': $_"
            }
    }
    




# # ── Also add to All_Staff distribution group ──────────────────────
# try {
#     Add-ADGroupMember -Identity "All_Staff" -Members $Username
#     Write-Host "[OK]   Added to group: All_Staff" -ForegroundColor Green
# }
# catch {
#     Write-Warning "[WARN] Could not add to All_Staff: $_"
# }

# ── Summary ───────────────────────────────────────────────────────


Write-Log "Onboarding complete. Log saved to: $LogFile" "DONE"
Write-Log " Name       : $DisplayName"
Write-Log " Username   : $Username"
Write-Log " UPN        : $UPN"
Write-Log " Department : $Department"
Write-Log " Job Title  : $JobTitle"
Write-Log " OU         : $TargetOU"
Write-Log " Groups     : $TargetGroups, All_Staff"
Write-Log " Temp Pass  : apple@123 - must change at first login"

Write-Host "`n[DONE] $Username has been Onboarded. Review log: $LogFile`n" -ForegroundColor Green