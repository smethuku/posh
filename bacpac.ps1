# Configuration
$server   = "yourserver.database.windows.net"
$database = "yourdbname"
$username = "yourusername"
$password  = "yourpassword"
$backupPath = "C:\Users\$env:USERNAME\Documents\$database-$(Get-Date -Format 'yyyyMMdd-HHmmss').bacpac"

# Export BACPAC
Write-Host "Starting BACPAC export..." -ForegroundColor Cyan

sqlpackage /Action:Export `
    /TargetFile:"$backupPath" `
    /SourceServerName:"$server" `
    /SourceDatabaseName:"$database" `
    /SourceUser:"$username" `
    /SourcePassword:"$password" `
    /SourceTrustServerCertificate:True

# Check if export was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "BACPAC export successful!" -ForegroundColor Green
    Write-Host "File saved to: $backupPath" -ForegroundColor Green
} else {
    Write-Host "BACPAC export failed!" -ForegroundColor Red
}
