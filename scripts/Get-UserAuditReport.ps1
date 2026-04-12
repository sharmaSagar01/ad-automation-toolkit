<#
.SYNOPSIS
    Generates a full AD user audit report exported to CSV.
.Example
    .\Get-UserAuditReport.ps1
    .\Get-UserAuditReport.ps1 -InactiveDays 30
#>

param(
    [int] $InactiveDays = 60
)

Import-Module ActiveDirectory

$ReportPath = ".\data\user-audit-$(Get-Date -Format 'yyyyMMdd').csv"
$CutoffDate = (Get-Date).AddDays(-$InactiveDays)

Write-Host "[INFO] Generating AD User Audit Report..." -ForegroundColor Cyan

$Users = Get-ADUser -Filter * -Properties DisplayName,EmailAddress,Department,Title,Enabled,LastLogonDate,PasswordLastSet,PasswordExpired,PasswordNeverExpires,LockedOut,MemberOf,Created | Sort-Object Department,Surname

$Report = foreach ($User in $Users) {
    $Groups    = ($User.MemberOf | ForEach-Object { (Get-ADGroup $_).Name }) -join ", "
    $Inactive  = $User.LastLogonDate -and $User.LastLogonDate -lt $CutoffDate
    $DaysSince = if ($User.LastLogonDate) { ((Get-Date) - $User.LastLogonDate).Days } else { "Never" }

    [PSCustomObject]@{
        Username            = $User.SamAccountName
        DisplayName         = $User.DisplayName
        Email               = $User.EmailAddress
        Department          = $User.Department
        JobTitle            = $User.Title
        Enabled             = $User.Enabled
        LockedOut           = $User.LockedOut
        PasswordExpired     = $User.PasswordExpired
        PasswordNeverExpires= $User.PasswordNeverExpires
        LastLogon           = if ($User.LastLogonDate) { $User.LastLogonDate.ToString("yyyy-MM-dd") } else { "Never" }
        DaysSinceLogin      = $DaysSince
        Inactive            = $Inactive
        PasswordLastSet     = if ($User.PasswordLastSet) { $User.PasswordLastSet.ToString("yyyy-MM-dd") } else { "Never" }
        AccountCreated      = $User.Created.ToString("yyyy-MM-dd")
        Groups              = $Groups
    }
}

$Report | Export-Csv -Path $ReportPath -NoTypeInformation

# Console summary
$Total    = $Report.Count
$Inactive = ($Report | Where-Object { $_.Inactive -eq $true }).Count
$Locked   = ($Report | Where-Object { $_.LockedOut -eq $true }).Count
$PwdExp   = ($Report | Where-Object { $_.PasswordExpired -eq $true }).Count

Write-Host "-------------------------------------------------" -ForegroundColor DarkGray
Write-Host " User Audit Report -- $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor White
Write-Host "-------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Total users        : $Total"
Write-Host "  Inactive (${InactiveDays}d+)   : $Inactive" -ForegroundColor $(if ($Inactive -gt 0) { "Yellow" } else { "White" })
Write-Host "  Locked out         : $Locked"  -ForegroundColor $(if ($Locked -gt 0) { "Red" } else { "White" })
Write-Host "  Expired passwords  : $PwdExp"  -ForegroundColor $(if ($PwdExp -gt 0) { "Yellow" } else { "White" })
Write-Host "---------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Report saved to: $ReportPath" -ForegroundColor Cyan