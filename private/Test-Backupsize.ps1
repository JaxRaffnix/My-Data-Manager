function Test-Backupsize {
    param (
        [Parameter(Mandatory)]
        [string]$Folder,

        [string]$ExcludeFile,

        [Parameter(Mandatory)]
        [int64]$MaxFileSize ,

        [Parameter(Mandatory)]
        [int64]$MaxFolderSize 
    )

    Write-Host "`n🔍 Scanning Source for large files" -ForegroundColor Cyan
    Write-Host "  ├─ Source folder: '$Folder'"
    Write-Host "  ├─ File threshold: $($MaxFileSize / 1MB) MB"
    Write-Host "  ├─ Folder threshold: $($MaxFolderSize / 1GB) GB"
    Write-Host "  └─ Exclude file: '$ExcludeFile'"

    if (-not (Test-Path $Folder)) {
        Throw "❌ Folder '$Folder' does not exist."
    }
    if ($ExcludeFile -and -not (Test-Path $ExcludeFile)) {
        Throw "❌ Exclude file '$ExcludeFile' does not exist."
    }

    # Load exclusions
    $excludePatterns = @()
    if ($ExcludeFile) {
        $excludePatterns = Get-Content $ExcludeFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    }

    # Inline helper for exclusions
    function Test-Excluded {
        param ([string]$Path)
        foreach ($pattern in $excludePatterns) {
            $regex = if ($pattern -like "/*") {
                "^" + [regex]::Escape((Join-Path $Folder $pattern.TrimStart('/'))).Replace("\\*", ".*").Replace("\\?", ".") + "$"
            } else {
                [regex]::Escape($pattern).Replace("\\*", ".*").Replace("\\?", ".")
            }
            if ($Path -match $regex) { return $true }
        }
        return $false
    }

    # Write-Host "📦 Gathering file and folder info..."

    # Collect all files and dirs
    $allFiles = Get-ChildItem $Folder -Recurse -File -Force
    $allDirs  = Get-ChildItem $Folder -Recurse -Directory -Force

    # Filter large files
    $largeFiles = $allFiles | Where-Object {
        $_.Length -gt $MaxFileSize -and -not (Test-Excluded $_.FullName)
    }

    # Scan for large folders
    $largeFolders = foreach ($dir in $allDirs) {
        if (Test-Excluded -Path $dir.FullName) { continue }

        $dirFiles = Get-ChildItem $dir.FullName -Recurse -File -Force | Where-Object {
            -not (Test-Excluded $_.FullName)
        }
        $size = ($dirFiles | Measure-Object -Property Length -Sum).Sum
        if ($size -gt $MaxFolderSize) {
            [PSCustomObject]@{
                FullName = $dir.FullName
                SizeGB    = "{0:N2}" -f ($size / 1GB)
            }
        }
    }

    # Show large files
    if ($largeFiles.Count -gt 0) {
        Write-Host "🚨 Large Files Detected:"
        $largeFiles | Sort-Object Length -Descending |
            Select-Object FullName, @{Name="Size (GB)"; Expression={"{0:N2}" -f ($_.Length / 1GB)}} |
            Format-Table -AutoSize
    }

    # Show large folders
    if ($largeFolders.Count -gt 0) {
        Write-Host "🚨 Large Folders Detected:"
        $largeFolders | Sort-Object {[decimal]$_.SizeGB} -Descending |
            Format-Table FullName, FileCount, SizeGB -AutoSize
    }

    # Prompt if large items were found
    if ($largeFiles.Count -gt 0 -or $largeFolders.Count -gt 0) {
        Write-Warning "⚠️ Large items found. Confirm to proceed."
        $response = Read-Host "Continue with backup? (y/n)"
        if ($response -ne 'y') {
            Throw "❌ Backup aborted by user."
        } else {
            Write-Host "✅ Proceeding with backup..." -ForegroundColor Green
        }
    } else {
        Write-Host "✅ No large files or folders found. Safe to proceed." -ForegroundColor Green
    }
    # Write-Host ""
}
