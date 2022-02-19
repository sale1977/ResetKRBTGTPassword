# Reset Krbtgt-Useraccount-Password (scheduled)
# https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/manage/ad-forest-recovery-resetting-the-krbtgt-password
# https://github.com/hpmillaard/Reset-KrbtgtPassword/blob/main/Reset-KrbtgtPassword.ps1
# Modified by Alexander Scharmer | 15.02.2022

# Logfile Start
$VerbosePreference = "Continue"
$LogPath = Join-Path -Path (Split-Path $MyInvocation.MyCommand.Path) -ChildPath "Logs"
If (-not (Test-Path $LogPath))
{
    New-Item $LogPath -ItemType Directory | Out-Null
}
Get-ChildItem "$LogPath\*.log" | Where LastWriteTime -LT (Get-Date).AddDays(-15) | Remove-Item -Confirm:$false
$LogPathName = Join-Path -Path $LogPath -ChildPath "$($MyInvocation.MyCommand.Name)-$(Get-Date -Format 'MM-dd-yyyy').log"
Start-Transcript -Path $LogPathName -NoClobber -Append -Force

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit}

$DR = (Get-WmiObject Win32_ComputerSystem).DomainRole
If ($DR -eq 4 -or $DR -eq 5) {Write-Host "Check: This is a Domain Controller, continuing Script Reset krbtgt-Password" -ForegroundColor Green} Else {Write-Host "This script can only run on a Domain Controller" -ForegroundColor Red;BREAK}

Get-AdUser krbtgt -property created, passwordlastset, enabled
$diff = New-TimeSpan -Start ((Get-AdUser krbtgt -property passwordlastset).passwordlastset) -End (get-Date)
If ($diff.Days -ge 1){
	Write-Host "Password will be reset" -foregroundcolor Green
	Add-Type -AssemblyName System.Web
	Set-ADAccountPassword krbtgt -Reset -NewPassword (ConvertTo-SecureString -AsPlainText ([System.Web.Security.Membership]::GeneratePassword(128,64)) -Force -Verbose) –PassThru
	Get-AdUser krbtgt -property created, passwordlastset, enabled
} Else {
	Write-Host "Password already reset in the last one Day" -foregroundcolor Red
}

# $a = new-object -comobject wscript.shell 
# $Answer = $a.popup("Do you want to schedule this script to run on the first of every next month?",60,"Schedule",4)
# If ($Answer -eq 6){schtasks /create /RU '""' /SC MONTHLY /D 1 /M * /TN 'reset krbtgt password' /TR ('powershell -executionpolicy bypass -file """' + $PSCommandPath + '"""') /ST 00:00 /SD 01/01/2000 /RL HIGHEST /F;pause}
# Run (twice) on first of every next Month and on second of every Month
if(!(Get-ScheduledTask 'Reset krbtgt Password 1run' -ErrorAction Ignore)) { schtasks /create /RU '""' /SC MONTHLY /D 1 /M * /TN 'Reset krbtgt Password 1run' /TR ('powershell -executionpolicy bypass -noninteractive -nologo -file """' + $PSCommandPath + '"""') /ST 00:00 /SD 01/01/2000 /RL HIGHEST /F }
if(!(Get-ScheduledTask 'Reset krbtgt Password 2run' -ErrorAction Ignore)) { schtasks /create /RU '""' /SC MONTHLY /D 2 /M * /TN 'Reset krbtgt Password 2run' /TR ('powershell -executionpolicy bypass -noninteractive -nologo -file """' + $PSCommandPath + '"""') /ST 01:00 /SD 01/01/2000 /RL HIGHEST /F }

# Logfile End
Stop-Transcript