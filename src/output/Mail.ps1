# =====================================================
# MAIL NOTIFICATION - PUBLIC DEMO VERSION
# =====================================================
# Purpose:
# Prepare and optionally send an HTML summary email with
# the helpdesk CSV attachment.
#
# Public repository note:
# - mail is disabled by default in the demo version
# - this function remains available for local lab testing
# - no internal infrastructure detail should appear here
# =====================================================

function Send-ByodReportMail {
    param (
        [array]$HelpdeskCases,
        [int]$TagCountCritical,
        [int]$TagCountWarning,
        [int]$TagCountNormal,
        [int]$ProbablePrivateByodCount,
        [array]$ConsolidatedDevices,
        [string]$HelpDeskReportPathCsv,
        [string]$EmailRecipient,
        [string]$EmailSender,
        [string]$SmtpServer,
        [int]$SmtpPort = 25,
        [bool]$ForceSend = $false
    )

    Write-Host "[STEP] Preparing email notification" -ForegroundColor Cyan

    $emailTotalCasesCount = $TagCountCritical + $TagCountWarning
    $emailSubject = "DEVICE SECURITY POSTURE REPORT"

    $emailBody = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Device Security Posture Report</title>
</head>
<body style="margin:0;padding:0;background-color:#0f172a;font-family:Segoe UI,Arial,sans-serif;">

<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f172a;">
  <tr>
    <td align="center" style="padding:32px 12px;">

      <table role="presentation" width="620" cellpadding="0" cellspacing="0" border="0" style="width:620px;max-width:620px;background-color:#1e293b;border-collapse:collapse;">
        
        <tr>
          <td align="center" style="background-color:#2563eb;padding:36px 24px;text-align:center;">
            <div style="font-size:11px;font-weight:bold;letter-spacing:3px;color:#dbeafe;margin-bottom:10px;line-height:16px;">
              AUTOMATED SECURITY REPORT
            </div>
            <div style="font-size:30px;font-weight:bold;color:#ffffff;line-height:36px;">
              DEVICE MONITOR
            </div>
            <div style="font-size:14px;color:#dbeafe;margin-top:10px;line-height:20px;">
              Trend &mdash; Entra ID &mdash; Intune
            </div>
          </td>
        </tr>

        <tr>
          <td align="center" style="padding:24px 24px 12px 24px;background-color:#1e293b;">
            <div style="font-size:11px;font-weight:bold;letter-spacing:3px;color:#cbd5e1;line-height:16px;">
              SUMMARY
            </div>
          </td>
        </tr>

        <tr>
          <td style="padding:0 18px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;">
              <tr>
                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#dc2626;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$TagCountCritical</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#fee2e2;padding-top:8px;line-height:18px;">CRITICAL</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">Immediate action</div>
                      </td>
                    </tr>
                  </table>
                </td>

                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f59e0b;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$TagCountWarning</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#fff7ed;padding-top:8px;line-height:18px;">WARNING</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">Needs investigation</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 18px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;">
              <tr>
                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#16a34a;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$TagCountNormal</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#dcfce7;padding-top:8px;line-height:18px;">NORMAL</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">No major issue detected</div>
                      </td>
                    </tr>
                  </table>
                </td>

                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#7c3aed;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$ProbablePrivateByodCount</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#ede9fe;padding-top:8px;line-height:18px;">PERSONAL DEVICE</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">Likely unmanaged endpoint</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:6px 18px 22px 18px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:collapse;">
              <tr>
                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f172a;border:1px solid #334155;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:18px 12px;">
                        <div style="font-size:28px;font-weight:bold;color:#38bdf8;line-height:32px;">$emailTotalCasesCount</div>
                        <div style="font-size:11px;letter-spacing:2px;color:#cbd5e1;padding-top:6px;line-height:16px;">TOTAL ACTIONABLE CASES</div>
                      </td>
                    </tr>
                  </table>
                </td>

                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f172a;border:1px solid #334155;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:18px 12px;">
                        <div style="font-size:28px;font-weight:bold;color:#a78bfa;line-height:32px;">$($ConsolidatedDevices.Count)</div>
                        <div style="font-size:11px;letter-spacing:2px;color:#cbd5e1;padding-top:6px;line-height:16px;">TOTAL DEVICES</div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td align="center" style="padding:0 24px 16px 24px;background-color:#1e293b;">
            <div style="font-size:11px;font-weight:bold;letter-spacing:3px;color:#cbd5e1;line-height:16px;">
              ALERT LEVELS
            </div>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 8px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#2a0f16;border-left:4px solid #ef4444;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#f87171;letter-spacing:1px;line-height:18px;">CRITICAL</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; Unmatched or noncompliant device</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 8px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#2a1a0a;border-left:4px solid #f59e0b;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#fbbf24;letter-spacing:1px;line-height:18px;">WARNING</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; Partial visibility, inactivity, or device management issue</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 8px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#1e1b4b;border-left:4px solid #8b5cf6;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#c4b5fd;letter-spacing:1px;line-height:18px;">PERSONAL DEVICE</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; Device likely to behave like an unmanaged personal endpoint</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 24px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f2417;border-left:4px solid #22c55e;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#4ade80;letter-spacing:1px;line-height:18px;">NORMAL</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; No major issue detected</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td align="center" style="background-color:#0f172a;border-top:1px solid #334155;padding:20px 24px;">
            <div style="font-size:13px;color:#cbd5e1;line-height:20px;">
              Review the attached report and prioritize <strong style="color:#f87171;">critical devices first</strong>.
            </div>
            <div style="font-size:11px;color:#94a3b8;padding-top:8px;line-height:16px;">
              Automated report &mdash; demo / lab use
            </div>
          </td>
        </tr>

      </table>

    </td>
  </tr>
</table>

</body>
</html>
"@

    $currentDay = (Get-Date).DayOfWeek
    $mailAllowedDays = @("Monday", "Wednesday", "Friday")
    $shouldSendMailToday = $mailAllowedDays -contains $currentDay

    if (-not $HelpdeskCases -or $HelpdeskCases.Count -eq 0) {
        Write-Host "[WARN] No cases to report" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "no_cases"
        }
    }

    if (-not $EmailSender) {
        Write-Host "[WARN] Mail skipped: sender address missing" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_sender"
        }
    }

    if (-not $EmailRecipient) {
        Write-Host "[WARN] Mail skipped: recipient address missing" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_recipient"
        }
    }

    if (-not $shouldSendMailToday -and -not $ForceSend) {
        Write-Host "[INFO] Mail skipped: today is not a scheduled reporting day" -ForegroundColor White
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "day_not_allowed"
        }
    }

    if (-not (Test-Path $HelpDeskReportPathCsv)) {
        Write-Host "[ERROR] Mail skipped: attachment file not found" -ForegroundColor Red
        Write-Host $HelpDeskReportPathCsv -ForegroundColor Red
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_attachment"
        }
    }

    $sendMailMessageSplat = @{
        From                       = $EmailSender
        To                         = $EmailRecipient
        Subject                    = $emailSubject
        Body                       = $emailBody
        BodyAsHtml                 = $true
        Attachments                = $HelpDeskReportPathCsv
        Priority                   = "High"
        DeliveryNotificationOption = "OnSuccess", "OnFailure"
        SmtpServer                 = $SmtpServer
        Port                       = $SmtpPort
    }

    try {
        Send-MailMessage @sendMailMessageSplat -ErrorAction Stop
        Write-Host "[OK] Mail sent via SMTP" -ForegroundColor Green

        return [PSCustomObject]@{
            Sent   = $true
            Reason = "sent"
        }
    }
    catch {
        Write-Host "[ERROR] SMTP send failed" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red

        return [PSCustomObject]@{
            Sent         = $false
            Reason       = "smtp_error"
            ErrorMessage = $_.Exception.Message
        }
    }
}