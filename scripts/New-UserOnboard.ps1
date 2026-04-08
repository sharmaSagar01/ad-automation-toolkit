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

# Map departments to OU and Security Groups
$DeptMap = @{
    "IT"            = @{OU = "OU=All_Staff,$DomainDN"; Groups = @("IT_Support","All_Staff","Personal") }
    "HR"            = @{OU = "OU=All_Staff,$DomainDN"; Groups = @("HR","All_Staff","Personal") }
    "Finance"       = @{ OU = "OU=All_Staff,$DomainDN"; Groups = @("Finance","All_Staff","Personal") }
    "Operations"    = @{ OU = "OU=All_Staff,$DomainDN"; Groups = @("Operations","All_Staff","Personal") }

}

# ----------- Build user attributes ------------------------

$Username       = ($FirstName.Substring(0,1) + $LastName).ToLower()  #jsmith
$DisplayName    = "$FirstName $LastName"
$UPN            = "$Username@$Domain"  #jsmith@Infotech.com
$TargetOU       = $DeptMap[$Department].OU
$TargetGroups   = $DeptMap[$Department].Groups

Write-Host "`n[INFO] Creating user: $DisplayName ($Username)" -ForegroundColor Cyan

# --- Check for duplicate username -----------------------

if (Get-ADUser -Filter {SamAccountName -eq $Username} -ErrorAction SilentlyContinue) {
    Write-Host "[WARN] User '$Username' already exists in AD. Exiting." -ForegroundColor Red
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
    Write-Host "[SUCCESS] User Created in OU: $TargetOU" -ForegroundColor Green
}

catch {
    Write-Error "[ERROR] Couldn not create user: $_"
    exit 1
}

# ── Add to security group ─────────────────────────────────────────


   foreach ($group in $TargetGroups) {
        try {
                Add-ADGroupMember -Identity $group -Members $Username
                Write-Host "[OK]   Added to group: $group" -ForegroundColor Green
            }
        catch {
                Write-Warning "[WARN] Could not add to group '$group': $_"
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

Write-Host "`n────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " Onboarding Complete" -ForegroundColor White
Write-Host "─────────────────────────────────────" -ForegroundColor DarkGray
Write-Host " Name       : $DisplayName"
Write-Host " Username   : $Username"
Write-Host " UPN        : $UPN"
Write-Host " Department : $Department"
Write-Host " Job Title  : $JobTitle"
Write-Host " OU         : $TargetOU"
Write-Host " Groups     : $TargetGroups, All_Staff"
Write-Host ' Temp Pass  : apple@123 (must change at first login)'
Write-Host "─────────────────────────────────────`n" -ForegroundColor DarkGray

