# This script is meant to manage my personal dashboard on my home Windows PC

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
    using System;
    using System.Diagnostics;
    using System.Runtime.InteropServices;
    namespace PInvoke.Win32 {
        public static class UserInput {
            [DllImport("user32.dll", SetLastError=false)]
            private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
            [StructLayout(LayoutKind.Sequential)]
            private struct LASTINPUTINFO {
                public uint cbSize;
                public int dwTime;
            }
            public static DateTime LastInput {
                get {
                    DateTime bootTime = DateTime.UtcNow.AddMilliseconds(-Environment.TickCount);
                    DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
                    return lastInput;
                }
            }
            public static TimeSpan IdleTime {
                get {
                    return DateTime.UtcNow.Subtract(LastInput);
                }
            }
            public static int LastInputTicks {
                get {
                    LASTINPUTINFO lii = new LASTINPUTINFO();
                    lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                    GetLastInputInfo(ref lii);
                    return lii.dwTime;
                }
            }
        }
    }
'@

$IntervalFrequencyInSeconds = 60 # How often to check idle timer and act
$UserIdleThresholdSeconds = 1800 # 1800 seconds = 30 minutes
$UserIdleThresholdMinutes = $UserIdleThresholdSeconds / 60
$DashboardURL = "https://home.taylorsturtz.com"
$WarningTimeInMilliseconds = 5000 # There are min/max bounds on this - 5000 is default
$WarningThresholdMinutes1 = $UserIdleThresholdMinutes - 10
$WarningThresholdMinutes2 = $UserIdleThresholdMinutes - 5
$WarningThresholdMinutes3 = $UserIdleThresholdMinutes - 1
$WShell = New-Object -com "Wscript.Shell"

function ResetIdleTime {
  # Hack to trigger a key-press to reset idle timer - simulated mouse movement doesn't do it
  # SCROLLLOCK is a fairly useless key
  $WShell.sendkeys("{SCROLLLOCK}")
}

function ShowWarningBalloon($Threshold) {
  $UntilMinutes = ($UserIdleThresholdMinutes - $Threshold)
  $MinutesText = If ($UntilMinutes -eq 1) { "minute" } Else { "minutes" }
  $global:balloon = New-Object System.Windows.Forms.NotifyIcon
  $path = (Get-Process -id $pid).Path
  $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
  $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
  $balloon.BalloonTipText = "Chrome will restart in " + $UntilMinutes + " " + $MinutesText
  $balloon.BalloonTipTitle = "Warning!"
  $balloon.Visible = $true
  $balloon.ShowBalloonTip($WarningTimeInMilliseconds)
}

function ListenForUserActivity {
  # Get user last input
  $Last = [PInvoke.Win32.UserInput]::LastInput
  # Format last input
  $LastStr = $Last.ToLocalTime().ToString("MM/dd/yyyy hh:mm:ss tt")
  # Get user idle time
  $Idle = [PInvoke.Win32.UserInput]::IdleTime
  # Output idle info
  "Last user keyboard/mouse input: " + $LastStr + " (" + $Idle.Minutes + " minutes and " + $Idle.Seconds + " seconds ago)"
  "The idle threshold is set to: " + $UserIdleThresholdMinutes + " minutes"
  # If user is idle for longer than the threshold...
  if ($Idle.Minutes -ge $UserIdleThresholdMinutes) {
    # Boot chrome and reset idle timer
    Write-Host "User interaction was NOT detected." -ForegroundColor yellow
    Write-Host "Resetting idle time and booting dashboard in chrome." -ForegroundColor green
    ResetIdleTime
    BootDashboard
  } else {
    # Do not reboot chrome
    Write-Host "User interaction was detected or chrome was recently rebooted." -ForegroundColor yellow
    # Display warning notifications that a reboot of chrome is coming soon
    if ($Idle.Minutes -eq $WarningThresholdMinutes3) {
      ShowWarningBalloon $WarningThresholdMinutes3
    } elseif ($Idle.Minutes -eq $WarningThresholdMinutes2) {
      ShowWarningBalloon $WarningThresholdMinutes2
    } elseif ($Idle.Minutes -eq $WarningThresholdMinutes1) {
      ShowWarningBalloon $WarningThresholdMinutes1
    }
    
  }
}

function BootDashboard {
  # Kill chrome
  Stop-Process -Name chrome
  # Remove crash warning in chrome by rewriting exit_type to "Normal"
  $c = Get-Content "$($env:localAppData)\Google\Chrome\User Data\Default\Preferences"
  if ($c.IndexOf('"exit_type":"Crashed"') -gt 0) {
    Write-Information -MessageData "Chrome Crashed -- fooling startup to think it didn't"
    $c.Replace('"exit_type":"Crashed"', '"exit_type":"Normal"') | Set-Content "$($env:localAppData)\Google\Chrome\User Data\Default\Preferences" -NoNewLine
  }
  # Boot dashboard in chrome fullscreen mode
  Start-Process "chrome.exe" -ArgumentList "--start-fullscreen", $DashboardURL
}

BootDashboard

do {
  "---"
  ListenForUserActivity
  Start-Sleep -Seconds $IntervalFrequencyInSeconds
} until($infinity)
