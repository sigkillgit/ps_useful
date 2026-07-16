<#
.SYNOPSIS
	- Checks E: drive free space; if usage is at/above 80%, deletes the oldest
	.evtx file in E:\DC-Logs\ArchivedLogs to reclaim space.
	- Keeps its own log located in the archive drive. Once log size reaches 1GB 
	it deletes the first 1000 entries in its logfile. 
.NOTES	
	- Deletes ONE file per run (the oldest by LastWriteTime), not a batch.	
	Run on a recurring schedule (e.g. Task Scheduler, hourly/daily) so it
	keeps trimming one file at a time as needed.
	- gMSA-LogCleanUp has been created and assigned permissions to the 
	permissions of the archive folder.

Mark Killen 07-16-2026
#>


$DriveLetter  = "E:"
$ArchivePath  = "E:\DC-Logs\ArchivedLogs"
$ThresholdPct = 80
$LogFile      = "E:\DC-Logs\RemovedLogs\DiskCleanup.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp  $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

try {
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$DriveLetter'"

    if (-not $disk) {
        Write-Log "ERROR: Could not find drive $DriveLetter."
        return
    }

    $usedPct = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
    Write-Log "Drive $DriveLetter is $usedPct% used (threshold: $ThresholdPct%)."

    if ($usedPct -ge $ThresholdPct) {

        if (-not (Test-Path $ArchivePath)) {
            Write-Log "ERROR: Archive path $ArchivePath not found. Nothing to delete."
            return
        }

        $oldestFile = Get-ChildItem -Path $ArchivePath -Filter "*.evtx" -File |
            Sort-Object LastWriteTime |
            Select-Object -First 1

        if ($oldestFile) {
            Write-Log "Threshold reached. Deleting oldest file: $($oldestFile.FullName) (LastWriteTime: $($oldestFile.LastWriteTime))"
            Remove-Item -Path $oldestFile.FullName -Force
            Write-Log "Deleted successfully: $($oldestFile.FullName)"
        }
        else {
            Write-Log "Threshold reached, but no .evtx files found in $ArchivePath."
        }
    }
    else {
        Write-Log "Usage below threshold. No action taken."
    }
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
}

# --- Rotate log: trim oldest 1000 entries if DiskCleanup.log exceeds 1GB ---
$LogSizeThresholdBytes = 1GB
$LinesToTrim           = 1000
 
try {
    if (Test-Path $LogFile) {
        $logFileInfo = Get-Item -Path $LogFile
 
        if ($logFileInfo.Length -gt $LogSizeThresholdBytes) {
            $allLines = Get-Content -Path $LogFile
            $allLines | Select-Object -Skip $LinesToTrim | Set-Content -Path $LogFile -Encoding utf8
            Write-Log "Log file exceeded 1GB ($([math]::Round($logFileInfo.Length / 1GB, 2)) GB). Trimmed oldest $LinesToTrim entries."
        }
    }
}
catch {
    Write-Log "ERROR during log rotation: $($_.Exception.Message)"
}
