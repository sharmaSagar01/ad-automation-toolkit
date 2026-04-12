# 📖 AD Automation Toolkit — Runbook

> This runbook is the operational guide for the `ad-automation-toolkit` scripts.
> It covers when to use each script, step-by-step procedures, error handling, and troubleshooting.
> Written to mirror a real-world IT team runbook — the kind you'd find pinned in a Confluence space or SharePoint wiki.

---

## 📑 Table of Contents

| # | Procedure | Trigger |
|---|-----------|---------|
| 1 | [Onboard a New User](#1-onboard-a-new-user) | New hire starts |
| 2 | [Offboard a Departing User](#2-offboard-a-departing-user) | Employee leaves |
| 3 | [Bulk Onboard Multiple Users](#3-bulk-onboard-multiple-users) | Department joins / batch new starters |
| 4 | [Run AD Health Check](#4-run-ad-health-check) | Scheduled check / incident investigation |
| 5 | [Generate User Audit Report](#5-generate-user-audit-report) | Security review / compliance audit |
| 6 | [Troubleshooting](#6-troubleshooting) | Something goes wrong |

---

## ⚙️ Before You Start

### Prerequisites

```powershell
# Must be run as Domain Admin on the Windows Server
# Verify AD module is available
Get-Module -ListAvailable -Name ActiveDirectory

# If missing, install it
Install-WindowsFeature RSAT-AD-PowerShell

# Confirm domain connectivity
Get-ADDomain
```

### Environment Reference

| Item | Value |
|------|-------|
| Domain | `InfoTech.com` |
| Primary DC | `VM-DEV-WINSERV-01` (`192.168.1.10`) |
| Secondary DC | `VM-DEV-WINSERV-02` (`192.168.1.12`) |
| Scripts location | `C:\Users\Administrator\Desktop\AD-Automation-Toolkit\scripts\` |
| Data / output folder | `.\data\` |
| Offboard logs | `C:\Logs\Offboarding\` |

### Execution Policy

If PowerShell blocks the scripts from running:

```powershell
# Allow local scripts to run — run once per machine
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

---

## 1. Onboard a New User

**Script:** `New-UserOnboard.ps1`
**Trigger:** A new employee is starting and needs an AD account created.
**Run on:** `VM-DEV-WINSERV-01` as Domain Admin
**Expected time:** Under 30 seconds

---

### When to Use This

- A single new hire is starting and HR has confirmed their details
- IT has received a new starter ticket with name, department, job title, and manager

---

### Information Needed Before Running

Collect the following from HR or the new starter ticket before proceeding:

| Field | Example | Notes |
|-------|---------|-------|
| First name | `Jane` | As it appears on their contract |
| Last name | `Smith` | As it appears on their contract |
| Department | `IT` | Must be: `IT`, `HR`, `Finance`, or `Operations` |
| Job title | `Support Analyst` | From the job offer |
| Manager | `paula.doe` | SamAccountName of their manager — optional |

---

### Procedure

**Step 1 — Navigate to the scripts folder**
```powershell
cd C:\Users\Administrator\Desktop\AD-Automation-Toolkit
```

**Step 2 — Run the onboarding script**
```powershell
# Without manager
.\scripts\New-UserOnboard.ps1 `
    -FirstName "Jane" `
    -LastName "Smith" `
    -Department "IT" `
    -JobTitle "Support Analyst"

# With manager
.\scripts\New-UserOnboard.ps1 `
    -FirstName "Jane" `
    -LastName "Smith" `
    -Department "IT" `
    -JobTitle "Support Analyst" `
    -Manager "paula.doe"
```

**Step 3 — Confirm the output shows success**

Look for all three green lines:
```
[SUCCESS] User created in OU: OU=All_Staff,DC=InfoTech,DC=com
[OK]   Added to group: IT_Support
[OK]   Added to group: All_Staff
[OK]   Added to group: Personal
```

**Step 4 — Verify in AD (optional but recommended)**
```powershell
# Confirm account exists with correct attributes
Get-ADUser -Identity "jsmith" -Properties Department, Title, EmailAddress, MemberOf |
    Select DisplayName, SamAccountName, Department, Title, EmailAddress
```

**Step 5 — Communicate credentials to the new starter**

The account is created with a temporary password of `apple@123`. The user **must change it on first login**. Communicate this securely — do not send via email in plain text.

---

### Username Format

Usernames are auto-generated as **first initial + last name**, all lowercase:

| Name | Username |
|------|---------|
| Jane Smith | `jsmith` |
| Mark Jones | `mjones` |
| Alice Johnson | `ajohnson` |

> If a username already exists, the script will exit with a warning and not create a duplicate. You will need to handle this manually — for example, use `jsmith2` or the middle initial.

---

### Department → Group Mapping

| Department | Security Group | OU |
|------------|---------------|-----|
| IT | `IT_Support` | `All_Staff` |
| HR | `HR` | `All_Staff` |
| Finance | `Finance` | `All_Staff` |
| Operations | `Operations` | `All_Staff` |

All users also receive: `All_Staff` (distribution) and `Personal` (home drive access).

---

### Expected Output

```
[INFO] Creating user: Jane Smith (jsmith)
[SUCCESS] User created in OU: OU=All_Staff,DC=InfoTech,DC=com
[OK]   Added to group: IT_Support
[OK]   Added to group: All_Staff
[OK]   Added to group: Personal

─────────────────────────────────────
 Onboarding Complete
─────────────────────────────────────
 Name       : Jane Smith
 Username   : jsmith
 UPN        : jsmith@InfoTech.com
 Department : IT
 Job Title  : Support Analyst
 OU         : OU=All_Staff,DC=InfoTech,DC=com
 Groups     : IT_Support, All_Staff, Personal
 Temp Pass  : apple@123 (must change at first login)
─────────────────────────────────────
```

---

---

## 2. Offboard a Departing User

**Script:** `Remove-UserOffboard.ps1`
**Trigger:** An employee has left or been terminated and their access must be revoked.
**Run on:** `VM-DEV-WINSERV-01` as Domain Admin
**Expected time:** Under 60 seconds
**⚠️ Time-sensitive:** This should be run on the employee's last working day or immediately on termination.

---

### When to Use This

- An employee has resigned and their last day has arrived
- An employee has been terminated immediately — run this as soon as notified
- An account needs to be suspended pending an HR investigation

---

### Information Needed Before Running

| Field | Example | Notes |
|-------|---------|-------|
| Username | `jsmith` | SamAccountName — confirm with HR or check ADUC |

> **Always confirm the correct username before running.** Offboarding the wrong account is a serious incident.

---

### Procedure

**Step 1 — Confirm the username before running**
```powershell
# Verify you have the right person before offboarding
Get-ADUser -Identity "jsmith" -Properties DisplayName, Department, Title |
    Select DisplayName, SamAccountName, Department, Title
```

**Step 2 — Run the offboarding script**
```powershell
.\scripts\Remove-UserOffboard.ps1 -Username "jsmith"
```

**Step 3 — Confirm the output shows all steps complete**

Look for these log lines in the output:
```
[INFO] Account disabled.
[INFO] Description updated with offboard date.
[INFO] Removed from group: IT_Support
[INFO] Removed from group: All_Staff
[INFO] Removed from group: Personal
[INFO] User moved to Disabled_Users OU.
[INFO] Offboarding complete.
```

**Step 4 — Verify in AD**
```powershell
# Confirm account is disabled and in the correct OU
Get-ADUser -Identity "jsmith" -Properties Enabled, Description, DistinguishedName |
    Select DisplayName, Enabled, Description, DistinguishedName
```

Expected result:
```
Enabled            : False
Description        : OFFBOARDED: 2026-04-12
DistinguishedName  : CN=Jane Smith,OU=Disabled_Users,DC=InfoTech,DC=com
```

**Step 5 — Save the log file**

A log file is automatically created at:
```
C:\Logs\Offboarding\offboard_YYYYMMDD_HHmmss.log
```

Attach this to the HR or IT ticket as the offboarding audit record.

---

### What the Script Does and Does NOT Do

| Action | Done by script |
|--------|:-------------:|
| Disables the account | ✅ |
| Removes from all groups | ✅ |
| Moves to `Disabled_Users` OU | ✅ |
| Logs all actions with timestamps | ✅ |
| Updates description with offboard date | ✅ |
| Deletes the account permanently | ❌ |
| Revokes VPN / cloud access | ❌ |
| Disables MFA tokens | ❌ |

> **Note:** Account deletion should only happen after the retention period (typically 30–90 days) and must be approved by a manager. Cloud access, VPN, and MFA revocation must be handled separately through those platforms.

---

---

## 3. Bulk Onboard Multiple Users

**Script:** `Import-BulkUsers.ps1`
**Trigger:** Multiple new hires starting at the same time — new department, acquisition, or batch intake.
**Run on:** `VM-DEV-WINSERV-01` as Domain Admin
**Expected time:** Approximately 10–15 seconds per user

---

### When to Use This

- Five or more new starters joining at the same time
- A new department is being added to the domain
- Running repeated onboarding for a test or audit environment

---

### Prepare the CSV File

Create a CSV file using this exact column structure. Save it to the `data/` folder:

```csv
FirstName,LastName,Department,JobTitle,Manager
Alice,Johnson,IT,Junior Sysadmin,paula.doe
Bob,Williams,HR,HR Coordinator,
Carol,Brown,Finance,Finance Analyst,
Derek,Taylor,IT,Support Technician,paula.doe
Eva,Martinez,Operations,Ops Coordinator,
```

**Rules:**
- `Department` must be exactly: `IT`, `HR`, `Finance`, or `Operations`
- `Manager` column must exist but can be left blank — do not remove the column
- No extra spaces around values
- Save as `.csv` — not `.xlsx`

---

### Procedure

**Step 1 — Place the CSV in the data folder**
```
ad-automation-toolkit\data\new-hires-april.csv
```

**Step 2 — Run the bulk import script**
```powershell
.\scripts\Import-BulkUsers.ps1 -CSVPath ".\data\new-hires-april.csv"
```

**Step 3 — Review the console summary**
```
═══════════════════════════════════════
 Bulk Import Complete
═══════════════════════════════════════
 Created : 5
 Skipped : 0
 Failed  : 0
═══════════════════════════════════════
```

**Step 4 — Review the results CSV**

A results file is exported automatically to:
```
.\data\import-results-YYYYMMDD_HHmmss.csv
```

Open it in Excel and check the `Status` and `Reason` columns for any skipped or failed rows.

**Step 5 — Investigate any failures**

If a row shows `Failed` — check the `Reason` column and address each one individually using `New-UserOnboard.ps1`.

If a row shows `Skipped` — the username already existed. Verify in AD whether it is the correct account or a duplicate that needs a different naming format.

---

### Skip vs Fail — What They Mean

| Status | Meaning | Action Required |
|--------|---------|----------------|
| `Created` | Account created successfully | None |
| `Skipped` | Username already exists in AD | Verify the existing account — may be fine |
| `Failed` | Script encountered an error | Check the Reason column and fix manually |

---

---

## 4. Run AD Health Check

**Script:** `Get-ADHealthCheck.ps1`
**Trigger:** Scheduled daily/weekly check, or at the start of any incident investigation.
**Run on:** `VM-DEV-WINSERV-01` as Domain Admin
**Expected time:** Under 60 seconds

---

### When to Use This

- First thing to run when users report login issues or Group Policy not applying
- Before and after any major change to the domain (new DC, new GPO, DNS changes)
- As part of a scheduled weekly health review
- When investigating replication errors or FSMO role issues

---

### Procedure

**Standard run — console output only**
```powershell
.\scripts\Get-ADHealthCheck.ps1
```

**Run with HTML report export**
```powershell
.\scripts\Get-ADHealthCheck.ps1 -ExportHTML
```

---

### Reading the Output

**All green — domain is healthy:**
```
RESULT: All checks passed. Domain is healthy.
```
No action required.

**Red lines present — issues found:**
```
RESULT: 3 issue(s) found:
  - VM-DEV-WINSERV-02 (192.168.1.12) : UNREACHABLE
  - SYSVOL share on VM-DEV-WINSERV-02 : NOT FOUND
  - NETLOGON share on VM-DEV-WINSERV-02 : NOT FOUND
```
See the [Troubleshooting](#6-troubleshooting) section below.

---

### What Each Section Means

| Section | What a failure means |
|---------|---------------------|
| DC reachability | That DC is offline or network path is broken |
| SYSVOL share | Group Policy cannot be delivered from that DC |
| NETLOGON share | Logon scripts and domain join operations will fail |
| FSMO roles | A critical AD role is missing — domain operations may degrade |
| Replication | Changes on one DC are not reaching the other |
| Locked accounts | Users are locked — may indicate a brute-force attempt |
| Expired passwords | Users will be prompted to change password at next login |

---

### Recommended Schedule

| Frequency | Trigger |
|-----------|---------|
| Daily | Automated task via Task Scheduler — alert on any failure |
| Before changes | Before adding a GPO, DC, or DNS change |
| After incidents | After resolving any AD-related ticket |
| Weekly | Full review including HTML export for records |

---

---

## 5. Generate User Audit Report

**Script:** `Get-UserAuditReport.ps1`
**Trigger:** Regular account hygiene review, security audit, or compliance check.
**Run on:** `VM-DEV-WINSERV-01` as Domain Admin
**Expected time:** Under 30 seconds

---

### When to Use This

- Monthly account hygiene review — check for inactive and orphaned accounts
- Before a security audit — produce evidence of access controls
- After a bulk onboard — verify all users have the correct groups and departments
- When investigating whether a specific user has the right permissions

---

### Procedure

**Standard run — 60-day inactivity threshold**
```powershell
.\scripts\Get-UserAuditReport.ps1
```

**Custom threshold — flag accounts inactive for 30+ days**
```powershell
.\scripts\Get-UserAuditReport.ps1 -InactiveDays 30
```

**Review the output file**

The report is saved to:
```
.\data\user-audit-YYYYMMDD.csv
```

Open in Excel. Sort by the following columns to find issues quickly:

| Sort by | Looking for |
|---------|-------------|
| `Inactive` | `True` — accounts not logged in beyond the threshold |
| `PasswordNeverExpires` | `True` — accounts exempt from password policy |
| `LockedOut` | `True` — currently locked accounts |
| `PasswordExpired` | `True` — accounts with expired passwords |
| `Enabled` | `False` — disabled accounts still in active OUs |

---

### Common Actions After the Report

**Disable inactive accounts:**
```powershell
# Disable a specific inactive account
Disable-ADAccount -Identity "ajohnson"
```

**Unlock a locked account:**
```powershell
Unlock-ADAccount -Identity "jsmith"
```

**Find accounts with password never expires:**
```powershell
Get-ADUser -Filter { PasswordNeverExpires -eq $true } -Properties PasswordNeverExpires |
    Select DisplayName, SamAccountName
```

**Force password reset on next login:**
```powershell
Set-ADUser -Identity "jsmith" -ChangePasswordAtLogon $true
```

---

---

## 6. Troubleshooting

### ❌ "User already exists in AD. Exiting."

The auto-generated username (`jsmith`) is already taken.

```powershell
# Check who the existing account belongs to
Get-ADUser -Identity "jsmith" -Properties DisplayName, Department |
    Select DisplayName, Department, SamAccountName
```

If it is a different person, create the account manually in ADUC with a modified username (e.g. `jsmith2` or `jasmith`).

---

### ❌ "Could not create user" — Path error

The target OU does not exist in AD.

```powershell
# List all OUs in the domain
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName

# Create the missing OU
New-ADOrganizationalUnit -Name "All_Staff" -Path "DC=InfoTech,DC=com"
```

---

### ❌ "Could not add to group" warning

The security group does not exist or the name does not match exactly.

```powershell
# List all groups in the domain
Get-ADGroup -Filter * | Select Name

# Create a missing group
New-ADGroup -Name "IT_Support" -GroupScope Global -GroupCategory Security `
    -Path "CN=Users,DC=InfoTech,DC=com"
```

---
### ❌ Bulk import CSV fails to read

```
CSV file not found: .\data\new-hires.csv
```

- Confirm the file path is correct and the file exists
- Confirm the file is saved as `.csv` not `.xlsx`
- Confirm column headers exactly match: `FirstName,LastName,Department,JobTitle,Manager`

---

### ❌ Offboard log directory not created

If `C:\Logs\Offboarding\` cannot be created automatically:

```powershell
# Create it manually
New-Item -ItemType Directory -Path "C:\Logs\Offboarding" -Force
```

---

## 📋 Quick Reference — All Commands

```powershell
# Onboard a single user
.\scripts\New-UserOnboard.ps1 -FirstName "Jane" -LastName "Smith" -Department "IT" -JobTitle "Support Analyst"

# Offboard a user
.\scripts\Remove-UserOffboard.ps1 -Username "jsmith"

# Bulk import from CSV
.\scripts\Import-BulkUsers.ps1 -CSVPath ".\data\sample-users.csv"

# AD health check
.\scripts\Get-ADHealthCheck.ps1

# User audit report — 30-day threshold
.\scripts\Get-UserAuditReport.ps1 -InactiveDays 30

# Useful AD one-liners
Get-ADUser -Identity "jsmith" -Properties *           # Full user detail
Unlock-ADAccount -Identity "jsmith"                   # Unlock account
Disable-ADAccount -Identity "jsmith"                  # Disable account
Get-ADGroupMember -Identity "IT_Support"              # List group members
repadmin /replsummary                                 # Replication health
repadmin /syncall /AdeP                               # Force full replication
```

---

<div align="center">
<sub>📖 AD Automation Toolkit — Operational Runbook | InfoTech.com Domain | Windows Server 2025</sub>
</div>