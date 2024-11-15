# Requires -Version 5.0
# Requires -RunAsAdministrator

# Script Configuration - Edit these variables as needed
#----------------------------------------
$ServerList = @(
    'Server-name'
    'Server-name1'
    # Add all server names here
)
$BatchSize = 3
$ReportPath = "C:\ModuleDeployLogs\ModuleDeployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
#----------------------------------------

# Create output folder if it doesn't exist
$ReportFolder = Split-Path -Parent $ReportPath
if (-not (Test-Path -Path $ReportFolder)) {
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
}

function Install-PSWindowsUpdateModule {
    param(
        [string]$ServerName
    )
    
    Write-Host "`nServer: $ServerName" -ForegroundColor Cyan
    
    $result = [PSCustomObject]@{
        ServerName = $ServerName
        Status = "Unknown"
        Error = $null
        Timestamp = Get-Date
        Batch = $currentBatch
    }
    
    if (-not (Test-Connection -ComputerName $ServerName -Count 1 -Quiet)) {
        Write-Host "Status: Offline" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Error = "Server is not reachable"
        return $result
    }
    
    try {
        Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Yellow
        
        $installResult = Invoke-Command -ComputerName $ServerName -ScriptBlock {
            # Check if NuGet is installed
            if (!(Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
                Write-Host "  Installing NuGet provider..." -ForegroundColor Gray
                Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null
            }
            
            # Set PSGallery as trusted
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            
            # Check if module is already installed
            if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Install-Module PSWindowsUpdate -Force -Confirm:$false
                return "Installed"
            } else {
                return "Already installed"
            }
        } -ErrorAction Stop
        
        $result.Status = $installResult
        Write-Host "Status: $installResult" -ForegroundColor Green
    }
    catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        $result.Status = "Failed"
        $result.Error = $_.Exception.Message
    }
    
    return $result
}

# Main script execution
Clear-Host
Write-Host "PSWindowsUpdate Module Deployment Script" -ForegroundColor Cyan
Write-Host "Servers to process: $($ServerList.Count) | Batch size: $BatchSize"

$allResults = @()
$totalBatches = [math]::Ceiling($ServerList.Count / $BatchSize)

for ($i = 0; $i -lt $ServerList.Count; $i += $BatchSize) {
    $batchServers = $ServerList[$i..([Math]::Min($i + $BatchSize - 1, $ServerList.Count - 1))]
    $currentBatch = [math]::Floor($i/$BatchSize) + 1
    
    Write-Host "`nBatch $currentBatch of $totalBatches" -ForegroundColor Yellow
    Write-Host ($batchServers -join ", ")
    
    foreach ($server in $batchServers) {
        $result = Install-PSWindowsUpdateModule -ServerName $server
        $allResults += $result
        
        # Export deployment status to CSV
        $result | Select-Object ServerName, Status, Error, Timestamp, Batch |
            Export-Csv -Path $ReportPath -NoTypeInformation -Append
    }
    
    # Add delay between batches if not the last batch
    if ($i + $BatchSize -lt $ServerList.Count) {
        $delaySeconds = 30
        Write-Host "`nWaiting $delaySeconds seconds before processing next batch..." -ForegroundColor Yellow
        Start-Sleep -Seconds $delaySeconds
    }
}

# Final summary
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Total: $($allResults.Count) | Successful: $(($allResults | Where-Object {$_.Status -in @('Installed', 'Already installed')}).Count) | Failed: $(($allResults | Where-Object {$_.Status -eq 'Failed'}).Count)"

$failed = $allResults | Where-Object { $_.Status -eq "Failed" }
if ($failed) {
    Write-Host "`nFailed Deployments:" -ForegroundColor Red
    foreach ($server in $failed) {
        Write-Host "- $($server.ServerName): $($server.Error)"
    }
}

# Display batch summary
Write-Host "`nDeployment Summary by Batch:" -ForegroundColor Yellow
$allResults | Group-Object Batch | ForEach-Object {
    Write-Host "`nBatch $($_.Name):"
    $_.Group | Format-Table ServerName, Status, Error -AutoSize
}

Write-Host "`nReport saved to: $ReportPath" -ForegroundColor Green
