# ============================================
# Control-M: Database Health Check
# Executes monitoring sproc
# ============================================

$SqlInstance = "YOUR_SQL_SERVER_NAME"
$Database    = "recdb"          # Stable DB hosting the monitoring sproc
$Sproc       = "monitoring.sproc"

# Timestamp for logging
$NowLocal = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$NowUtc   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

Write-Host "[Check_OnyxRecon_Health] Starting at $NowLocal (Local), $NowUtc (UTC)"

# Build SQL command
$SqlCmd = @"
EXEC [$Database].[$Sproc];
"@

# Execute using integrated security (gMSA)
$sqlResult = sqlcmd -S $SqlInstance -d $Database -Q $SqlCmd
$exitCode  = $LASTEXITCODE

# Output SQLCMD results to Control-M logs
Write-Host $sqlResult

if ($exitCode -ne 0) {
    Write-Host "[Check_OnyxRecon_Health] FAILED with exit code $exitCode"
    exit 1
}

Write-Host "[Check_OnyxRecon_Health] PASSED successfully"
exit 0
