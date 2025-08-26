# -----------------------------
# Recursive hardlink clone (fsutil)
# -----------------------------
# Edit $Src and $Dst, then run in an elevated PowerShell
# Both must be on the same NTFS volume (same drive letter)
# -----------------------------

$Src = 'PATH:\TO\SRC'
$Dst = 'PATH:\TO\DST'

# normalize
$Src = $Src.TrimEnd('\')
$Dst = $Dst.TrimEnd('\')

if (-not (Test-Path $Src)) {
    Write-Error "Source does not exist: $Src"
    exit 1
}

# same-volume check
$srcRoot = (Get-Item $Src).PSDrive.Root
$dstRoot = [System.IO.Path]::GetPathRoot($Dst)
if ($srcRoot -ne $dstRoot) {
    Write-Error "Source and destination are on different volumes."
    Write-Error "Hard links require same NTFS volume. Aborting."
    exit 1
}

# create destination root if needed
if (-not (Test-Path $Dst)) {
    New-Item -Path $Dst -ItemType Directory | Out-Null
}

$total = 0
$created = 0
$skipped = 0
$failed = 0

# iterate files recursively
Get-ChildItem -LiteralPath $Src -Recurse -File -Force | ForEach-Object {
    $total++
    $full = $_.FullName
    # relative path from source root
    $rel = $full.Substring($Src.Length).TrimStart('\')
    $target = Join-Path $Dst $rel
    $parent = Split-Path $target -Parent

    # ensure parent dir exists
    if (-not (Test-Path -LiteralPath $parent)) {
        try {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        } catch {
            Write-Warning "Failed to create dir: $parent : $($_.Exception.Message)"
            $failed++; return
        }
    }

    if (Test-Path -LiteralPath $target) {
        $skipped++
        Write-Host "Skipped exists: $rel"
        return
    }

    # use fsutil to avoid wildcard/literal issues with [] etc.
    $cmd = "fsutil hardlink create `"$target`" `"$full`""
    $res = cmd /c $cmd 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "fsutil failed for: $rel`n  -> $res"
        $failed++
    } else {
        $created++
        if ($created % 100 -eq 0) { Write-Host "Linked $created files so far..." }
        else { Write-Host "Linked: $rel" }
    }
}

Write-Host ""
Write-Host "Done."
Write-Host "  Total files scanned: $total"
Write-Host "  Hard links created:  $created"
Write-Host "  Skipped existing:     $skipped"
Write-Host "  Failed:               $failed"
Write-Host ""
Write-Host "Verify a file with:"
Write-Host "  fsutil hardlink list `"$Dst\<relative\path\to\file>`""
