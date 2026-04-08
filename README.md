# Device Security Posture Monitor for Microsoft 365

PowerShell prototype designed to correlate device visibility across multiple security and management sources in a Microsoft 365 environment.

This public version is a **sanitized demo edition** built for portfolio and technical presentation purposes.  
It runs with **fake / sample data only** and does **not** include any production credentials, internal infrastructure details, or sensitive organizational information.

---

## Project Purpose

The goal of this project is to build a **consolidated device view** by combining signals from:

- Trend Vision One
- Microsoft Entra ID
- Microsoft Intune

The objective is to help identify:

- devices visible in one source but missing in another
- unmanaged or partially managed devices
- noncompliant devices
- probable personal devices (BYOD-like behavior)
- inactive devices
- visibility gaps across security sources

This project is designed with an operational mindset:  
not just collecting data, but turning it into **actionable outputs** for security or helpdesk teams.

---

## Public Demo Scope

This repository is a **public demonstration version** of the project.

It is intended to show:

- project architecture
- PowerShell scripting structure
- multi-source collection logic
- correlation logic
- risk classification
- reporting design

This version uses:

- **sample / fake datasets**
- **sanitized configuration**
- **non-production paths and placeholders**

It does **not** expose:

- real tenant information
- real credentials
- internal SMTP configuration
- private infrastructure details
- organizational data

---

## Current Features

- Modular PowerShell architecture
- Microsoft Graph authentication structure
- Entra ID device inventory collection
- Intune managed device inventory collection
- Trend Vision One endpoint loading / collection flow
- Cross-source device correlation
- Consolidated device object generation
- Risk engine with issue tagging
- Helpdesk-oriented CSV / JSON reporting
- Full JSON export for dashboard / UI usage
- Detection of:
  - unmatched devices
  - partial matches
  - noncompliant devices
  - probable personal devices
  - inactive devices
  - source visibility gaps
  - duplicate hostnames

---

## Detection Logic Overview

The monitoring logic currently focuses on practical cases such as:

- **Trend only** device  
  Device seen in endpoint security but not found in Entra ID

- **Trend + Entra, but not Intune**  
  Device exists in identity but is not managed

- **Noncompliant Intune device**  
  Device is managed but not compliant

- **Workplace / personal device registration**  
  Device appears as Entra `Workplace`

- **Probable personal device not registered in Entra**  
  Device looks like a personal endpoint based on multiple signals

- **Inactive device**  
  No recent activity observed across available sources

- **Source visibility gap**  
  Device is not consistently visible across security and management layers

---

## Project Structure

Device-Security-Posture-Monitor/
│
├── src/
│   ├── config/
│   ├── core/
│   ├── processing/
│   ├── output/
│   ├── tools/
│   └── Main.ps1
│
├── data/
│   ├── raw/
│   ├── processed/
│   ├── reports/
│   └── sample/
│
└── README.md

## Main Pipeline
Load configuration
Authenticate to Microsoft Graph
Collect Entra ID devices
Collect Intune devices
Load or collect Trend endpoints
Correlate devices across sources
Apply risk classification
Export reports
Optionally prepare notification output
Main Outputs
Full consolidated JSON report

## Complete dataset for:

dashboards
automation
analysis
Helpdesk report
CSV + JSON
actionable cases only
Entra-only report

Devices present in Entra but not seen in Trend

Probable personal device report

Suspected unmanaged or personal endpoints

Enriched Intune export

Normalized dataset for review

Risk Model

### Each device is evaluated based on:

source presence mismatch
compliance status
partial visibility
personal device signals
duplicate hostname
inactivity
visibility gaps

### Outputs include:

issues
visual_tag
recommended_action
risk_score
risk_level
priority
Sample Data

### This repository is intended to run with:

fake data
anonymized datasets
realistic but non-sensitive structures
Running the Demo Version
.\src\Main.ps1

### Requirements:

use local test data only, 
no production credentials, 
mail disabled or mocked, 
Security Note

This is a sanitized public version.

### Never include:

real credentials,
real tenant data,
internal infrastructure,
production exports,
Defender Status

Microsoft Defender integration is currently in progress and partially present in the architecture.

Roadmap

Defender enrichment

KB / Windows Update visibility

historical tracking

dashboard / UI

automation / remediation

Why This Project Matters

Device visibility is fragmented.

### A device may exist in:

endpoint security, 
identity systems, 
management platforms

…without being consistently tracked everywhere.

This project addresses that gap.

Technical Positioning

This is a security engineering prototype focused on:

real-world visibility problems, 
automation, 
actionable reporting

Author

Tommy Vlassiou
Junior Cybersecurity Analyst / Microsoft Security / PowerShell Automation