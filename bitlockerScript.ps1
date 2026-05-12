try {
    $vol = Get-BitLockerVolume -MountPoint "C:" -ErrorAction Stop
} catch {
    exit 1
}

# Pre-check TPM
$tpm = Get-Tpm
if (-not $tpm.TpmPresent -or -not $tpm.TpmEnabled -or -not $tpm.TpmActivated) {
    exit 0
}

if ($vol.VolumeStatus -eq "FullyDecrypted") {

    try {
        Enable-BitLocker -MountPoint "C:" -RecoveryPasswordProtector -SkipHardwareTest -ErrorAction Stop
    } catch {
        exit 1
    }

    try {
        $KeyID = (Get-BitLockerVolume -MountPoint "C:").KeyProtector |
                 Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } |
                 Select-Object -ExpandProperty KeyProtectorId

        if (-not $KeyID) {
            exit 1
        }

        Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KeyID -ErrorAction Stop
    } catch {
        exit 1
    }
}

if ($vol.VolumeStatus -eq "FullyEncrypted" -and $vol.ProtectionStatus -eq "Off") {

    $hasTpm = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "Tpm" }
    if (-not $hasTpm) {
        try {
            Add-BitLockerKeyProtector -MountPoint "C:" -TpmProtector -ErrorAction Stop
        } catch {
            exit 1
        }
    }

    $hasRecoveryPassword = $vol.KeyProtector | Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" }
    if (-not $hasRecoveryPassword) {
        try {
            Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector -ErrorAction Stop
        } catch {
            exit 1
        }
    }

    try {
        $KeyID = (Get-BitLockerVolume -MountPoint "C:").KeyProtector |
                 Where-Object { $_.KeyProtectorType -eq "RecoveryPassword" } |
                 Select-Object -ExpandProperty KeyProtectorId

        if (-not $KeyID) {
            exit 1
        }

        Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KeyID -ErrorAction Stop
    } catch {
        exit 1
    }

    try {
        Resume-BitLocker -MountPoint "C:" -ErrorAction Stop
    } catch {
        exit 1
    }
}