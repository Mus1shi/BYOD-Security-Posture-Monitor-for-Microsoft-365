# Security Device Monitor for Microsoft 365

A modular PowerShell-based security posture monitoring and device correlation project designed for modern Microsoft 365 environments.

This public repository demonstrates how to collect, normalize, correlate, score, and report device security data across multiple sources in a clean and maintainable way.

## Project Purpose

The goal of this project is to provide a unified security-oriented view of devices by correlating multiple sources instead of relying on a single tool.

The project is built around a practical idea:

- a device may exist in one source and be missing in another
- a device may be compliant in one tool but still risky overall
- a security team needs one operational view, not four disconnected consoles

This repository shows how PowerShell can be used to:

- collect device data from several platforms
- normalize and correlate records
- enrich devices with security visibility indicators
- apply a pragmatic risk scoring model
- export results for reporting, investigations, and dashboards

---

## Public Repository Scope

This is the **public demonstration version** of the project.

It is intentionally designed to be:

- safe to share
- portfolio-friendly
- understandable by recruiters and technical reviewers
- free from sensitive tenant information

### Important

This public version uses **sanitized demo/sample datasets**.

That means:

- no real tenant IDs
- no production secrets
- no customer data
- no internal infrastructure details
- no real usernames, emails, hostnames, or report recipients

The architecture, logic, naming, data flow, and reporting approach reflect the real project design, but the exposed data is intentionally safe for public publication.

---

## Core Value of the Project

This project is not just an inventory script.

Its real value is:

- **multi-source correlation**
- **security posture visibility**
- **risk prioritization**
- **operational reporting**
- **dashboard-ready exports**

Instead of showing isolated lists of devices, the project builds a unified device view from multiple sources and highlights:

- missing visibility
- compliance issues
- patching gaps
- security alerts
- probable BYOD situations
- unmanaged or inconsistent assets

---

## Public Demo Data Sources

The public version demonstrates a unified correlation model using the following sources:

- **Microsoft Entra ID**
- **Microsoft Intune**
- **Trend Vision One**
- **Microsoft Defender**

Each source contributes a different angle of visibility.

### Entra ID
Used for identity-linked device registration and trust information.

Examples:
- registered device presence
- trust type
- operating system
- sign-in visibility
- account enabled state

### Intune
Used for management, compliance, and device administration signals.

Examples:
- compliance state
- enrolled date
- last sync
- managed owner type
- Azure AD device linkage

### Trend Vision One
Used for endpoint security visibility and endpoint presence.

Examples:
- endpoint presence
- endpoint metadata
- endpoint platform visibility

### Microsoft Defender
Used in the public demo as a security enrichment source.

Examples:
- alert presence
- machine visibility
- hunting visibility
- missing KB visibility
- additional device-level security context

---

## Public Defender Scope

The public repository includes a **sanitized Defender demonstration model**.

The goal is to show how Defender can enrich a unified device posture view without exposing private tenant information.

### Public Defender fields exposed in demo reports

The public JSON outputs may include fields such as:

- `has_defender_alert`
- `has_defender_machine`
- `has_defender_hunting`
- `has_missing_kbs`
- `missing_kb_count`
- `missing_kb_ids`
- `missing_kb_names`
- `defender_visibility_status`

These fields are intentionally limited to portfolio-safe values.

### Why this matters

Defender is not presented here as an isolated source.

It is used to answer practical questions such as:

- does this device appear in Defender but not in Intune?
- does this device have security alerts?
- is there patch visibility for this device?
- does this device look risky when correlated with other sources?
- are we dealing with a management gap or a visibility gap?

---

## Key Features

### 1. Modular PowerShell architecture

The project is split into clean functional layers:

- configuration
- authentication / collection
- processing / correlation
- risk engine
- reporting
- mail output
- sample/demo tooling

This keeps the code maintainable and allows future extensions without turning the project into a monolithic script.

### 2. Multi-source device correlation

The project correlates devices across multiple platforms and builds a unified device record.

The unified output can represent:

- devices present in all sources
- devices present in only one source
- inconsistent device records
- devices with partial management
- devices with security visibility but weak administrative control

### 3. Risk engine

The project applies a pragmatic risk scoring model to highlight the devices that deserve attention first.

Examples of signals used in the model:

- compliance problems
- missing management coverage
- Defender alert presence
- missing KB visibility
- probable BYOD patterns
- duplicate hostnames
- source inconsistency
- stale or inactive records

### 4. Structured reporting

The public version exports dashboard-ready JSON and investigation-friendly outputs.

Outputs are designed to support:

- quick summaries
- detailed full reports
- UI integration
- CSV-style operational handling
- portfolio demonstrations

### 5. Public-safe demo mode

This repository is designed to run in a demo-friendly way using sample datasets.

That allows the project to remain:

- reproducible
- safe to share
- easy to demonstrate
- suitable for GitHub portfolios

---

## Current Public Architecture

```text
Security-Posture-Monitor-for-Microsoft-365/
│
├── BYOD_Device_Monitor.ps1
├── README.md
├── src/
│   ├── Main.ps1
│   ├── config/
│   │   └── Config.ps1
│   ├── core/
│   │   ├── GraphAuth.ps1
│   │   ├── EntraCollect.ps1
│   │   ├── IntuneCollect.ps1
│   │   ├── TrendCollect.ps1
│   │   └── DefenderCollect.ps1
│   ├── processing/
│   │   ├── Correlation.ps1
│   │   └── RiskEngine.ps1
│   ├── output/
│   │   ├── Reports.ps1
│   │   └── Mail.ps1
│   └── tools/
│       └── Invoke-TrendCollectEndpoint.ps1
│
├── data/
│   ├── sample/
│   ├── raw/
│   ├── processed/
│   └── reports/
│
└── frontend/
    └── (future public UI / dashboard)

## Public Data Flow

The public demo pipeline follows this logic:

- load sample data from each source
- normalize records
- correlate devices
- enrich with Defender visibility indicators
- apply risk scoring
- generate JSON reports
- prepare data for a future frontend/dashboard

This keeps the public version realistic while remaining safe.

---

## Main Public Outputs

The public version is designed around two main JSON outputs.

### Full report

**Example target file:**
data/reports/security_device_full_report_demo.json


**Purpose:**

- full unified device dataset
- detailed fields per device
- best source for UI consumption
- useful for debugging and portfolio demonstration

**Typical top-level structure:**

- `report_name`
- `generated_at`
- `total_records`
- `highlights`
- `devices`

---

### Summary report

**Example target file:**
data/reports/security_device_summary_demo.json


**Purpose:**

- quick overview
- high-level metrics
- dashboard cards / KPI usage
- fast recruiter-friendly reading

---

## Example Unified Device Fields

The correlated public device model may include fields such as:

- `device_name`
- `primary_user`
- `device_os`
- `device_os_version`
- `match_status`
- `has_trend`
- `has_entra`
- `has_intune`
- `has_defender_alert`
- `has_defender_machine`
- `has_defender_hunting`
- `has_missing_kbs`
- `missing_kb_count`
- `issues`
- `risk_score`
- `risk_level`
- `visual_tag`
- `recommended_action`

This makes the output directly usable by a frontend or reporting layer.

---

## Example Security Scenarios Demonstrated

The sample datasets are designed to represent realistic operational cases, such as:

- a device visible in all sources
- a device visible in Trend but missing in Intune
- a device registered in Entra but unmanaged
- a device with Defender alert presence
- a device with missing KBs
- a probable BYOD device
- an inactive or stale device
- a duplicate hostname scenario
- a partially matched device record

This makes the project more valuable than a basic “device list export”.

---

## Why PowerShell

The project is intentionally PowerShell-first.

**Reasons:**

- native fit for Windows and Microsoft environments
- strong automation capabilities
- excellent for operational scripting
- practical for infrastructure and M365 teams
- realistic in enterprise contexts
- suitable for log processing, reporting, and orchestration

This project is also a demonstration that PowerShell can be used for more than simple admin scripts. It can be structured into a maintainable operational monitoring tool.

---

## Public vs Private Version

### Public version

This repository:

- uses sample/sanitized datasets
- demonstrates architecture and logic
- is portfolio-safe
- is built for explanation and visibility

### Private/internal version

The private/internal project can include:

- real tenant integration
- live collection
- stronger authentication handling
- real report delivery
- environment-specific tuning
- deeper Defender collection logic
- operational reliability improvements

The public repository is meant to demonstrate the design and practical value without exposing sensitive implementation details.

---

## Frontend / Dashboard Direction

This repository is prepared for a future modern frontend dashboard consuming the exported demo JSON.

The frontend goal is not to replace the PowerShell logic.

The PowerShell pipeline remains the engine.

The frontend will act as:

- a visual operational layer
- a recruiter-friendly demonstration
- a quick decision dashboard
- a device investigation interface

### Planned dashboard capabilities

- KPI overview
- unified device table
- filters by source and risk level
- detailed device drawer
- issue highlighting
- Defender visibility indicators
- missing KB views
- source coverage badges

---

## Use Cases

This public project can be used to demonstrate:

- PowerShell automation skills
- modular scripting design
- data normalization and correlation
- risk-based reporting
- Microsoft security ecosystem understanding
- dashboard-oriented output design
- portfolio-ready engineering work

It is especially relevant for roles involving:

- PowerShell scripting
- M365 operations
- endpoint visibility
- device management
- security reporting
- modern workplace engineering
- Microsoft security engineering
- operational automation

---

## Recruiter / Reviewer Notes

This project was designed to show practical engineering capability, not theoretical architecture slides.

**What this repository demonstrates:**

- real script organization
- multi-source data thinking
- practical reporting outputs
- readable project structure
- operational mindset
- risk-oriented security reasoning
- preparation for UI integration

It is intended to show how a junior profile can build structured and useful tooling in a Microsoft security context.

---

## Planned Public Enhancements

The following improvements are planned or prepared in the public version:

- modern React frontend
- stronger demo datasets
- richer summary exports
- improved source coverage visualization
- better filtering scenarios
- cleaner public screenshots and UI assets
- enhanced documentation for demo mode

---

## How to Run the Public Demo

The public version is intended to run in demo mode using sanitized sample data.

**Typical flow:**

- clone the repository
- review `src/config/Config.ps1`
- ensure demo/sample paths are present
- run the main script
- inspect generated JSON reports
- consume the outputs in the future frontend

### Example entry point

```powershell
.\BYOD_Device_Monitor.ps1
or

.\src\Main.ps1

Depending on the final public wrapper structure.

## Important Security Note

This repository does not publish:

credentials
secrets
customer data
production identifiers
internal SMTP values
private tenant structure
sensitive reporting content

Any resemblance to real environments in the public sample data is purely illustrative.

# Status
Public repository status

Active and evolving.

Current public direction
strong PowerShell foundation
multi-source unified model
public Defender enrichment model
dashboard-ready JSON outputs
frontend-ready evolution path
Author

Built as a practical PowerShell security project focused on:

clean structure
real-world usefulness
Microsoft ecosystem relevance
portfolio credibility
progression toward security / automation / cloud-oriented roles
