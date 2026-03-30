# =====================================================
# MAIL NOTIFICATION
# =====================================================
# Purpose:
# Send an HTML summary email with helpdesk CSV attachment.
#
# Public GitHub version:
# - Safe for Demo mode
# - Can be disabled entirely from configuration
# - Keeps SMTP sending logic for private Live usage
#
# Notes:
# - Only actionable cases (critical / warning) should
#   normally be present in the helpdesk dataset
# - This function is designed to fail safely and return
#   a structured status object instead of breaking the run
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

    # -------------------------------------------------
    # Basic counters
    # -------------------------------------------------
    $emailTotalCasesCount = $TagCountCritical + $TagCountWarning
    $emailSubject = "BYOD DEVICE MONITOR REPORT"

    # -------------------------------------------------
    # HTML email body
    # -------------------------------------------------
    # The template below is intentionally self-contained
    # and compatible with Outlook desktop clients.
    # -------------------------------------------------
    $emailBody = @"
<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Devices Monitor Report</title>
  <!--[if gte mso 9]>
  <xml>
    <o:OfficeDocumentSettings>
      <o:AllowPNG/>
      <o:PixelsPerInch>96</o:PixelsPerInch>
    </o:OfficeDocumentSettings>
  </xml>
  <![endif]-->
  <style>
    body, table, td { margin:0; padding:0; border:0; }
    img { border:0; display:block; }
    .card-wrap { border-radius:12px; overflow:hidden; box-shadow:0 8px 24px rgba(0,0,0,0.45); }
    .stat-card { border-radius:10px; overflow:hidden; box-shadow:0 6px 18px rgba(0,0,0,0.35); }
    .total-box { border-radius:8px; }
    .legend-row { border-radius:6px; overflow:hidden; }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#0f172a;font-family:'Segoe UI',Arial,Helvetica,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#0f172a;">
  <tr>
    <td align="center" style="padding:32px 12px;">

      <!--[if gte mso 9]>
      <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word"
        href="" style="width:620px;height:auto;v-text-anchor:top;" arcsize="3%"
        strokecolor="#334155" strokeweight="1pt" fillcolor="#1e293b">
        <w:anchorlock/>
        <v:shadow on="t" color="#000000" opacity="0.5" offset="0px,8px"/>
        <center>
      <![endif]-->

      <table role="presentation" width="620" cellpadding="0" cellspacing="0" border="0" class="card-wrap" style="width:620px;max-width:620px;background-color:#1e293b;border-collapse:collapse;">

        <tr>
          <td align="center" style="padding:0;mso-padding-alt:0;">
            <!--[if gte mso 9]>
            <v:rect xmlns:v="urn:schemas-microsoft-com:vml" fill="true" stroke="false"
              style="width:620px;height:140px;">
              <v:fill type="gradient" color="#1d4ed8" color2="#4f46e5" angle="135"/>
              <v:textbox inset="0,0,0,0" style="mso-fit-shape-to-text:true;">
            <![endif]-->
            <div style="background:linear-gradient(135deg,#1d4ed8 0%,#4f46e5 100%);padding:36px 24px;border-bottom:4px solid #4f46e5;text-align:center;">
              <div style="font-size:11px;font-weight:bold;letter-spacing:3px;color:#dbeafe;margin-bottom:10px;line-height:16px;">
                AUTOMATED SECURITY REPORT
              </div>
              <div style="font-size:30px;font-weight:bold;color:#ffffff;line-height:36px;">
                DEVICES MONITOR
              </div>
              <div style="font-size:14px;color:#dbeafe;margin-top:10px;line-height:20px;">
                Trend &mdash; Entra ID &mdash; Intune
              </div>
            </div>
            <!--[if gte mso 9]>
              </v:textbox>
            </v:rect>
            <![endif]-->
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
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="stat-card" style="background-color:#dc2626;border-collapse:collapse;">
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
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="stat-card" style="background-color:#f59e0b;border-collapse:collapse;">
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
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="stat-card" style="background-color:#16a34a;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$TagCountNormal</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#dcfce7;padding-top:8px;line-height:18px;">NORMAL</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">No issue detected</div>
                      </td>
                    </tr>
                  </table>
                </td>

                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="stat-card" style="background-color:#7c3aed;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:22px 12px;">
                        <div style="font-size:34px;font-weight:bold;color:#ffffff;line-height:38px;">$ProbablePrivateByodCount</div>
                        <div style="font-size:12px;font-weight:bold;letter-spacing:2px;color:#ede9fe;padding-top:8px;line-height:18px;">BYOD SUSPECT</div>
                        <div style="font-size:12px;color:#ffffff;padding-top:6px;line-height:17px;">Private device likely</div>
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
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="total-box" style="background-color:#0f172a;border:1px solid #334155;border-collapse:collapse;">
                    <tr>
                      <td align="center" style="padding:18px 12px;">
                        <div style="font-size:28px;font-weight:bold;color:#38bdf8;line-height:32px;">$emailTotalCasesCount</div>
                        <div style="font-size:11px;letter-spacing:2px;color:#cbd5e1;padding-top:6px;line-height:16px;">TOTAL ACTIONABLE CASES</div>
                      </td>
                    </tr>
                  </table>
                </td>
                <td width="50%" valign="top" style="padding:6px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="total-box" style="background-color:#0f172a;border:1px solid #334155;border-collapse:collapse;">
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
              ALERT LEVELS EXPLAINED
            </div>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 8px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="legend-row" style="background-color:#2a0f16;border-left:4px solid #ef4444;border-collapse:collapse;">
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
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="legend-row" style="background-color:#2a1a0a;border-left:4px solid #f59e0b;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#fbbf24;letter-spacing:1px;line-height:18px;">WARNING</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; Partial match or unmanaged BYOD-style device</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 8px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="legend-row" style="background-color:#1e1b4b;border-left:4px solid #8b5cf6;border-collapse:collapse;">
              <tr>
                <td style="padding:14px 16px;">
                  <span style="font-size:12px;font-weight:bold;color:#c4b5fd;letter-spacing:1px;line-height:18px;">BYOD SUSPECT</span>
                  <span style="font-size:13px;color:#e5e7eb;line-height:18px;"> &mdash; Trend device likely to be a private BYOD not registered in Entra</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <tr>
          <td style="padding:0 24px 24px 24px;background-color:#1e293b;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="legend-row" style="background-color:#0f2417;border-left:4px solid #22c55e;border-collapse:collapse;">
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
              Review the attached report and prioritise <strong style="color:#f87171;">critical devices first</strong>.
            </div>
            <div style="font-size:11px;color:#94a3b8;padding-top:8px;line-height:16px;">
              Automated report &mdash; internal monitoring use
            </div>
          </td>
        </tr>

      </table>

      <!--[if gte mso 9]>
        </center>
      </v:roundrect>
      <![endif]-->

    </td>
  </tr>
</table>
</body>
</html>
"@

    # -------------------------------------------------
    # Allowed sending days
    # -------------------------------------------------
    # This preserves your original reporting logic.
    # ForceSend can bypass this schedule.
    # -------------------------------------------------
    $currentDay = (Get-Date).DayOfWeek
    $mailAllowedDays = @("Monday", "Wednesday", "Friday")
    $shouldSendMailToday = $mailAllowedDays -contains $currentDay

    # -------------------------------------------------
    # Safety checks
    # -------------------------------------------------
    if (-not $HelpdeskCases -or $HelpdeskCases.Count -eq 0) {
        Write-Host "[WARN] No cases to report" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "no_cases"
        }
    }

    if (-not $EmailSender) {
        Write-Host "[WARN] Mail skipped: sender mailbox not ready" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_sender"
        }
    }

    if (-not $EmailRecipient) {
        Write-Host "[WARN] Mail skipped: recipient mailbox not ready" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_recipient"
        }
    }

    if (-not $SmtpServer) {
        Write-Host "[WARN] Mail skipped: SMTP server not configured" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Sent   = $false
            Reason = "missing_smtp_server"
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

    # -------------------------------------------------
    # SMTP message definition
    # -------------------------------------------------
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

    # -------------------------------------------------
    # SMTP send
    # -------------------------------------------------
    try {
        Send-MailMessage @sendMailMessageSplat -ErrorAction Stop

        Write-Host "[OK] Mail sent via SMTP relay" -ForegroundColor Green

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