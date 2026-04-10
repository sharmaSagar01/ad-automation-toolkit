# 🛠️ AD Automation Toolkit

> A PowerShell automation suite for Active Directory — built to replace repetitive manual admin tasks with reliable, reusable scripts.
> Developed on a Windows Server 2025 home lab environment running the `InfoTech.com` domain.

<div align="center">
 
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?style=flat-square&logo=powershell)
![Windows Server](https://img.shields.io/badge/Windows%20Server-2025-blue?style=flat-square&logo=windows)
![Active Directory](https://img.shields.io/badge/Active%20Directory-AD%20DS-darkblue?style=flat-square)
![Status](https://img.shields.io/badge/Status-In%20Progress-yellow?style=flat-square)
 
</div>

---

## 📌 Overview

Manual Active Directory tasks don't scale. Every new hire, every departure, every audit done by hand is time that could be spent on higher-value work — and a step where something can go wrong.

This toolkit automates the most common AD operations that a sysadmin or IT support team performs on a daily basis. Each script is self-contained, parameterised, and includes error handling and output logging so nothing happens silently.

This project builds directly on top of the [Active Directory & Windows Server Labs](https://github.com/sharmaSagar01/Active-Directory-Lab.git) project — the same domain, the same users, the same environment.

---

## 🖥️ Lab Environment

| Component          | Details                                |
| ------------------ | -------------------------------------- |
| **Domain**         | `InfoTech.com`                         |
| **Primary DC**     | `VM-WINSERV-01` — `192.168.1.10`       |
| **Secondary DC**   | `VM-WINSERV-02` — `192.168.1.12`       |
| **Client Machine** | Windows 11 (domain-joined)             |
| **Virtualisation** | VMware Workstation Pro on Ubuntu host  |
| **PowerShell**     | 5.1+ with RSAT Active Directory module |

---

## 📁 Repository Structure

```
ad-automation-toolkit/
│
├── scripts/
│   ├── New-UserOnboard.ps1         # Onboard a new user         ✅
│   ├── Remove-UserOffboard.ps1     # Offboard a departing user  ✅
│   ├── Import-BulkUsers.ps1        # Bulk create users from CSV ✅
│   ├── Get-ADHealthCheck.ps1       # Domain health report       ⏳
│   └── Get-UserAuditReport.ps1     # User audit & expiry report ⏳
│
├── data/
│   └── sample-users.csv            # Sample input file for bulk import ✅
│
├── docs/
│   └── runbook.md                  # Usage guide for each script ⏳
│
├── images/                         # Screenshots
│   ├──Script_New-UserOnboard/
│   │  ├── script1-image1.png
│   │  ├── ...
│   │
│   ├──Remove-UserOffboard/
│   │  ├── script2-image1.png
│   │  ├── ...
│   │
│   ├──Import-BulkUsers/
│   │  ├── script3-image1.png
│   │  ├── ...
│   │
│   ├── ....
│
└── README.md
```

---

## 🧩 Scripts

| Script                    | Purpose                                                            | Status      |
| ------------------------- | ------------------------------------------------------------------ | ----------- |
| `New-UserOnboard.ps1`     | Create user, assign OU, add to groups, set temp password           | ✅ Complete |
| `Remove-UserOffboard.ps1` | Disable account, strip groups, move to Disabled OU, log everything | ✅ Complete |
| `Import-BulkUsers.ps1`    | Bulk create users from CSV with skip logic and results export      | ✅ Complete |

---

## ⚙️ Prerequisites

Before running any script, confirm the following on your Windows Server:

```powershell
# Verify the AD module is available
Get-Module -ListAvailable -Name ActiveDirectory

# If not available, install it
Install-WindowsFeature RSAT-AD-PowerShell

# Confirm you can query your domain
Get-ADDomain
```

You should see your domain name returned (`InfoTech.com`). If yes — you're ready to run the scripts.

---

---

# ✅ Script 1 — `New-UserOnboard.ps1`

## 📋 What It Does

Automates the full new hire onboarding process in Active Directory. Instead of manually stepping through ADUC, this script takes a new employee's details and handles everything in a single command:

- Creates the AD user account with all standard attributes
- Places the user in the correct **Organisational Unit (OU)** based on their department
- Adds them to the appropriate **Security Group** for resource access
- Adds them to the **`All_Staff` Distribution Group** automatically
- Sets a **temporary password** and enforces a password change on first login
- Checks for duplicate usernames before creating anything
- Prints a clean summary of everything that was done

---

## 🗺️ Department → OU & Group Mapping

| Department | Target OU      | Security Group                    |
| ---------- | -------------- | --------------------------------- |
| IT         | `OU=All_Staff` | `IT_Support, All_Staff, Personal` |
| HR         | `OU=All_Staff` | `HR, All_Staff, Personal`         |
| Finance    | `OU=All_Staff` | `Finance, All_Staff, Personal`    |
| Operations | `OU=All_Staff` | `Operations,All_Staff,Personal`   |

All users are also added to the `All_Staff` **Distribution Group** regardless of department.

---

## 🚀 Usage

```powershell
# Basic usage
.\scripts\New-UserOnboard.ps1 `
    -FirstName  "Jane" `
    -LastName   "Smith" `
    -Department "IT" `
    -JobTitle   "Sys Admin"

# With a manager assigned
.\scripts\New-UserOnboard.ps1 `
    -FirstName  "Jane" `
    -LastName   "Smith" `
    -Department "IT" `
    -JobTitle   "Support Analyst" `
    -Manager    "paula.doe"
```

### Parameters

| Parameter     | Required | Description                                             |
| ------------- | :------: | ------------------------------------------------------- |
| `-FirstName`  |    ✅    | User's first name                                       |
| `-LastName`   |    ✅    | User's last name                                        |
| `-Department` |    ✅    | Must be: `IT`, `HR`, `Finance`, or `Operations`         |
| `-JobTitle`   |    ✅    | User's job title                                        |
| `-Manager`    |    ❌    | SamAccountName of the user's manager (e.g. `paula.doe`) |

> **Username format:** Automatically generated as first initial + last name in lowercase.
> Example: Jane Smith → `jsmith`

---

## 🧪 Test Run —

Onboarded two test users to validate the script against the `InfoTech.com` domain.

### Users Created

| Full Name   | Username | Department | Job Title       | Manager     |
| ----------- | -------- | ---------- | --------------- | ----------- |
| Jane Smith  | `jsmith` | IT         | Support Analyst | `paula.doe` |
| Jessy Merch | `jmerch` | Finance    | Account Manager | `paula.doe` |

### Commands Run

```powershell
# User 1 — IT department with manager assigned
.\scripts\New-UserOnboard.ps1 `
    -FirstName "Jane" -LastName "Smith" `
    -Department "IT" -JobTitle "Sys Admin" -Manager "paula.doe"

# User 2 — Finance department
.\scripts\New-UserOnboard.ps1 `
    -FirstName "Jessy" -LastName "Merch" `
    -Department "Finance" -JobTitle "Account Manager" -Manager "paula.doe"
```

### Verification Commands

```powershell
# Confirm users exist in AD
Get-ADUser -Filter * -SearchBase "DC=InfoTech,DC=com" `
    -Properties Department, Title, EmailAddress, DisplayName |
    Where-Object { $_.SamAccountName -in "jsmith","jmerch" } |
    Select-Object DisplayName, SamAccountName, Department, Title, EmailAddress

# Confirm group memberships
Get-ADGroupMember -Identity "IT_Staff"  | Select Name, SamAccountName
Get-ADGroupMember -Identity "HR"        | Select Name, SamAccountName
Get-ADGroupMember -Identity "All_Staff" | Select Name, SamAccountName

# Confirm OU placement
Get-ADUser -Identity "jsmith"  | Select DistinguishedName
Get-ADUser -Identity "jmerch"  | Select DistinguishedName
```

### Results

| Check                    |     jsmith      |     jmerch     |
| ------------------------ | :-------------: | :------------: |
| Account created          |       ✅        |       ✅       |
| Correct OU               | ✅ `All_Staff`  | ✅ `All_Staff` |
| Security group assigned  | ✅ `IT_Support` |  ✅ `Finance`  |
| Added to `All_Staff`     |       ✅        |       ✅       |
| Password change enforced |       ✅        |       ✅       |
| Manager linked           | ✅ `paula.doe`  | ✅ `paula.doe` |

---

## 📸 Screenshots

<p align="center">
  <img src="images/Script_NewUser_Onboard//script1-image1.png" width="45%" />
  <img src="images/Script_NewUser_Onboard//script1-image2.png" width="45%"  />
</p>
 <p align="center">
  <img src="images/Script_NewUser_Onboard//script1-image3.png" width="45%"  />
  <img src="images/Script_NewUser_Onboard//script1-image4.png" width="45%"  />
</p>
<p align="center">
  <img src="images/Script_NewUser_Onboard//script1-image5.png" width="45%"  />
  <img src="images/Script_NewUser_Onboard//script1-image6.png" width="45%"  />
</p>
---

# ✅ Script 2 — `Remove-UserOffboard.ps1`

## 📋 What It Does

Automates the full user offboarding process in Active Directory. When an employee leaves, this script handles everything securely in a single command — no manual steps, no risk of forgetting to revoke access:

- Locates the user account and confirms it exists before doing anything
- **Disables the account** immediately — the user can no longer log in
- **Updates the account description** with the offboard date for audit trail purposes
- **Removes the user from every security and distribution group** they belong to
- **Creates a `Disabled_Users` OU** automatically if it doesn't already exist
- **Moves the account** to the `Disabled_Users` OU — keeping it for audit purposes without leaving it active
- **Logs every action** with timestamps to a file under `C:\Logs\Offboarding\`

> **Why not delete?** Deleting an account immediately is not best practice. Accounts are retained in a disabled state so that mailbox data, file ownership, and audit history are preserved — typically for 30–90 days before permanent deletion.

---

## 🔐 What Happens to the Account

| Action               | Details                                              |
| -------------------- | ---------------------------------------------------- |
| Account disabled     | User cannot log in from the moment the script runs   |
| Description updated  | Set to `OFFBOARDED: YYYY-MM-DD` for audit visibility |
| All groups removed   | Stripped from every Security and Distribution group  |
| Moved to disabled OU | `OU=Disabled_Users,DC=InfoTech,DC=com`               |
| Log file created     | `C:\Logs\Offboarding\offboard_YYYYMMDD_HHmmss.log`   |
| Account deleted      | ❌ Not deleted — retained for audit purposes         |

---

## 🚀 Usage

```powershell
# Offboard a user by their SamAccountName
.\scripts\Remove-UserOffboard.ps1 -Username "jsmith"
```

### Parameters

| Parameter   | Required | Description                                                |
| ----------- | :------: | ---------------------------------------------------------- |
| `-Username` |    ✅    | The SamAccountName of the user to offboard (e.g. `jsmith`) |

---

## 🧪 Test Run

Offboarded a test user to validate the script against the `InfoTech.com` domain. Created a throwaway account first specifically for this test so no real lab users were affected.

### Test Account Used

| Full Name | Username | Department | Reason                                                      |
| --------- | -------- | ---------- | ----------------------------------------------------------- |
| Test User | `tuser`  | HR         | Throwaway account created specifically for offboarding test |

### Commands Run

```powershell
# Step 1 — Create a throwaway account using Script 1
.\scripts\New-UserOnboard.ps1 `
    -FirstName "Test" -LastName "User" `
    -Department "HR" -JobTitle "Tester"

# Step 2 — Confirm the account exists before offboarding
Get-ADUser -Identity "tuser" -Properties Enabled, MemberOf |
    Select DisplayName, Enabled, @{N="Groups";E={$_.MemberOf.Count}}

# Step 3 — Run the offboard script
.\scripts\Remove-UserOffboard.ps1 -Username "tuser"

# Step 4 — Verify account is disabled and moved
Get-ADUser -Identity "tuser" -Properties Enabled, Description, DistinguishedName |
    Select DisplayName, Enabled, Description, DistinguishedName
```

### Results

| Check                                             | Result |
| -----------------------------------------------   | :----: |
| Account located in AD                             |   ✅   |
| Account disabled immediately                      |   ✅   |
| Description updated with offboard date            |   ✅   |
| Removed from all security groups                  |   ✅   |
| Removed from all distribution groups              |   ✅   |
| Moved to `Disabled_Account` OU                    |   ✅   |
| `Disabled_Account` OU auto-created (didn't exist) |   ✅   |
| Log file created at `C:\Logs\Offboarding\`        |   ✅   |
| Account NOT deleted — retained for audit          |   ✅   |

### Log File Sample

```
[2026-04-10 09:14:22] [INFO] Starting offboarding for: tuser
[2026-04-10 09:14:22] [INFO] Found user: Test User | DN: CN=Test User,OU=All_Staff,DC=InfoTech,DC=com
[2026-04-10 09:14:23] [INFO] Account disabled.
[2026-04-10 09:14:23] [INFO] Description updated with offboard date.
[2026-04-10 09:14:23] [INFO] Removed from group: HR
[2026-04-10 09:14:23] [INFO] Removed from group: All_Staff
[2026-04-10 09:14:23] [INFO] Removed from group: Personal
[2026-04-10 09:14:24] [INFO] Created Disabled_Users OU.
[2026-04-10 09:14:24] [INFO] User moved to Disabled_Users OU.
[2026-04-10 09:14:24] [INFO] Offboarding complete. Log saved to: C:\Logs\Offboarding\offboard_20260410_091422.log
```

---

## 📸 Screenshots

<p align="center">
  <img src="images/Script_Remove_User_Offboard//script2-image1.png" width="45%" />
  <img src="images/Script_Remove_User_Offboard//script2-image2.png" width="45%" />
</p>
 
---  
