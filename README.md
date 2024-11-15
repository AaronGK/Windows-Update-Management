# Windows-Update-Management

This repository contains two PowerShell scripts for managing Windows Updates across multiple servers:

PS Module Deploy Script.ps1: Deploys the PSWindowsUpdate module to multiple servers
PS Update Checker Script.ps1: Checks for pending Windows updates across servers
PS Module Deploy Script
Overview
Automates the deployment of the PSWindowsUpdate module across multiple servers in controlled batches.

Requirements
PowerShell 5.0+
Administrative privileges
WinRM enabled on target servers
Configuration
powershellCopy
# Edit these variables in the script
$ServerList = @(
    'Server-name',
    'Server-name2'
)
$BatchSize = 3
$ReportPath = "C:\ModuleDeployLogs\ModuleDeployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Features
Batch processing to prevent network overload
Detailed logging and error handling
Real-time progress tracking
Summary reports with success/failure statistics
CSV export of deployment results
Output
Console: Real-time colored status updates
CSV Log: Detailed deployment results including:
Server name
Installation status
Error messages
Timestamp
Batch number
PS Update Checker Script
Overview
Scans multiple servers for pending Windows updates and generates a comprehensive report.

Requirements
PowerShell 5.0+
PSWindowsUpdate module installed
Administrative privileges
WinRM enabled on target servers
Configuration
powershellCopy
# Edit these variables in the script
$ServerList = @(
    'Server-name',
    'Server-name2'
)
$BatchSize = 3
$ReportPath = "C:\WindowsUpdateChecks\WindowsUpdates_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
Features
Identifies pending updates
Checks reboot requirements
Batch processing
Size and importance level tracking
Detailed logging
Output
Console: Real-time update status
CSV Report including:
Server name
Update count
Reboot status
Detailed update list
Error messages
Usage
Module Deployment
powershellCopy
.\PS Module Deploy Script.ps1
Deploys PSWindowsUpdate module to listed servers
Creates log in specified directory
Displays progress and summary
Update Checking
powershellCopy
.\PS Update Checker Script.ps1
Scans all listed servers for updates
Generates detailed report
Shows servers requiring updates/reboots
Best Practices
Run module deployment script first
Verify successful module installation
Run update checker script
Review logs for any issues
Adjust batch size based on network capacity
Troubleshooting
Verify WinRM is enabled: winrm quickconfig
Check server connectivity: Test-NetConnection
Verify administrative privileges
Review error logs in output directory
