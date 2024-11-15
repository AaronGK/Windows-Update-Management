# Requires -Version 5.0
# Requires -Module PSWindowsUpdate

# Script Configuration - Edit these variables as needed
#----------------------------------------
$ServerList = @(
    'Server-name'
    'Server-name1'
    # Add all server names here
)
$BatchSize = 3
$ReportPath = "C:\WindowsUpdateChecks\WindowsUpdates_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
#----------------------------------------

# Create output folder if it doesn't exist
$ReportFolder = Split-Path -Parent $ReportPath
if (-not (Test-Path -Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
}

function Check-ServerUpdates {
    param(
        [string]$ServerName
    )
    
    Write-Host "`nServer: $ServerName" -ForegroundColor Cyan
    
    $result = [PSCustomObject]@{
        ServerName = $ServerName
        Status = "Unknown"
        UpdateCount = 0
        NeedsReboot = "Unknown"
        Updates = @()
        ErrorMessage = ""
    }
    
    if (-not (Test-Connection -ComputerName $ServerName -Count 1 -Quiet)) {
        Write-Host "Status: Offline" -ForegroundColor Red
        $result.Status = "Offline"
        $result.ErrorMessage = "Server is not reachable"
        return $result
    }
    
    try {
        $updates = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            Import-Module PSWindowsUpdate

            # Get pending updates
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $pendingUpdates = $updateSearcher.Search("IsInstalled=0")
            
            # Check Windows Update reboot flag
            $updateRebootRequired = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

            # Get update details
            $updateDetails = @()
            if ($pendingUpdates.Updates.Count -gt 0) {
                foreach ($update in $pendingUpdates.Updates) {
                    $updateDetails += [PSCustomObject]@{
                        Title = $update.Title
                        KB = $(if ($update.KBArticleIDs.Count -gt 0) { $update.KBArticleIDs[0] } else { "N/A" })
                        Size = if ($update.MaxDownloadSize -gt 0) { 
                            [math]::Round($update.MaxDownloadSize / 1MB, 2).ToString() + " MB"
                        } else { "Size unknown" }
                        IsImportant = $update.AutoSelectOnWebSites
                    }
                }
            }

            return @{
                Updates = $updateDetails
                NeedsReboot = $updateRebootRequired
                UpdateCount = $pendingUpdates.Updates.Count
            }
        } -ErrorAction Stop

        $result.Status = "Online"
        $result.UpdateCount = $updates.UpdateCount
        $result.NeedsReboot = $updates.NeedsReboot
        $result.Updates = $updates.Updates

        # Display results
        if ($result.UpdateCount -gt 0) {
            Write-Host "Updates Found: $($result.UpdateCount)" -ForegroundColor Yellow
            foreach ($update in $result.Updates) {
                $importance = if ($update.IsImportant) { "Important" } else { "Optional" }
                Write-Host "- KB$($update.KB) [$importance] [$($update.Size)]"
                Write-Host "  $($update.Title)" -ForegroundColor Gray
            }
        } else {
            Write-Host "No updates pending" -ForegroundColor Green
        }

        if ($result.NeedsReboot) {
            Write-Host "Reboot Required" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Error"
        $result.ErrorMessage = $_.Exception.Message
    }
    
    return $result
}

# Main script execution
Clear-Host
Write-Host "Windows Update Check Script" -ForegroundColor Cyan
Write-Host "Servers to process: $($ServerList.Count) | Batch size: $BatchSize"

$allResults = @()
$totalBatches = [math]::Ceiling($ServerList.Count / $BatchSize)

for ($i = 0; $i -lt $ServerList.Count; $i += $BatchSize) {
    $batchServers = $ServerList[$i..([Math]::Min($i + $BatchSize - 1, $ServerList.Count - 1))]
    $currentBatch = [math]::Floor($i/$BatchSize) + 1
    
    Write-Host "`nBatch $currentBatch of $totalBatches" -ForegroundColor Yellow
    Write-Host ($batchServers -join ", ")
    
    foreach ($server in $batchServers) {
        $result = Check-ServerUpdates -ServerName $server
        
        # Prepare CSV data
        $updateString = ($result.Updates | ForEach-Object { 
            "KB$($_.KB): $($_.Title) [$($_.Size)]" 
        }) -join "|"
        
        $allResults += [PSCustomObject]@{
            ServerName = $result.ServerName
            Status = $result.Status
            UpdateCount = $result.UpdateCount
            NeedsReboot = $result.NeedsReboot
            Updates = $updateString
            ErrorMessage = $result.ErrorMessage
        }
    }
}

# Save results
$allResults | Export-Csv -Path $ReportPath -NoTypeInformation

# Final summary
$needUpdates = $allResults | Where-Object {$_.UpdateCount -gt 0}
$needReboot = $allResults | Where-Object {$_.NeedsReboot -eq $true}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total: $($allResults.Count) | Online: $(($allResults | Where-Object {$_.Status -eq "Online"}).Count) | Offline: $(($allResults | Where-Object {$_.Status -eq "Offline"}).Count) | Errors: $(($allResults | Where-Object {$_.Status -eq "Error"}).Count)"

if ($needUpdates) {
    Write-Host "`nServers Needing Updates:" -ForegroundColor Yellow
    foreach ($server in $needUpdates) {
        Write-Host "- $($server.ServerName): $($server.UpdateCount) updates"
    }
}

if ($needReboot) {
    Write-Host "`nServers Needing Reboot:" -ForegroundColor Red
    $needReboot.ServerName | ForEach-Object { Write-Host "- $_" }
}

Write-Host "`nReport saved to: $ReportPath"
