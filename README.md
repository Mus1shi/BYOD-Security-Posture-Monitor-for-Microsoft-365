# BYOD-Security-Posture-Monitor-for-Microsoft-365 (in Process)

Prototype tool to correlate device inventories across:

- Microsoft Intune
- Entra ID (Azure AD)
- Trend Vision One

The goal is to identify security posture issues for BYOD devices
and provide actionable information for helpdesk teams.

## Current Features

- Microsoft Graph authentication (app-only)
- Intune device inventory collection
- Entra ID device inventory collection
- Data normalization and CSV export

## Planned Features

- Correlation Intune ↔ Entra
- Correlation Intune/Entra ↔ Trend Vision One
- Risk scoring
- Security posture report

## Requirements

- PowerShell 7+
- Microsoft Graph API access
- Environment variables:

GRAPH_TENANT_ID  
GRAPH_CLIENT_ID  
GRAPH_SECRET  
TREND_API_KEY
