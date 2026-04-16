# ╔══════════════════════════════════════════════════════════════╗
# ║  arko-dump v1.0                                             ║
# ║  Flatten media subdirectories with metadata timestamps      ║
# ╚══════════════════════════════════════════════════════════════╝

param(
    [Parameter(Position = 0)]
    [string]$TargetDir,

    [switch]$DryRun,
    [switch]$Help
)

$Version = "1.0"

# ------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------
function Show-Usage {
    Write-Host @"
arko-dump v1.0 -- Flatten media subdirectories with metadata timestamps

Usage:
  arko-dump <carpeta>              Flatten subdirectories in place
  arko-dump -DryRun <carpeta>      Show what would happen without moving
  arko-dump -Help                  Show this help

What it does:
  Reads first-level subdirectories (named by source), renames files
  with a prefix + metadata timestamp, and flattens them to the base
  folder. Operates in-place (move, not copy).

Naming convention:
  {source}_{YYYYMMDD}-{HHmmss}.{ext}

Example:
  arko-dump rollo\

  BEFORE:                          AFTER:
  rollo\                           rollo\
  +-- sony-a\                      +-- sony-a_20260415-143215.mp4
  |   +-- C0001.MP4                +-- sony-a_20260415-144032.mp4
  |   +-- C0002.MP4                +-- sony-b_20260415-143218.mp4
  +-- sony-b\                      +-- dji-mic_20260415-143210.wav
  |   +-- C0001.MP4
  +-- dji-mic\
      +-- TX1_0001.WAV

Dependencies: ffprobe (ffmpeg), exiftool
"@
    exit 0
}

if ($Help) { Show-Usage }

if (-not $TargetDir) {
    Write-Host "Error: No directory specified."
    Write-Host "Run 'arko-dump -Help' for usage."
    exit 1
}

# Remove trailing slash
$TargetDir = $TargetDir.TrimEnd('\', '/')

if (-not (Test-Path $TargetDir -PathType Container)) {
    Write-Host "Error: '$TargetDir' is not a directory."
    exit 1
}

$TargetDir = (Resolve-Path $TargetDir).Path

# ------------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------------
$MissingDeps = @()

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    $MissingDeps += "ffprobe"
}
if (-not (Get-Command exiftool -ErrorAction SilentlyContinue)) {
    $MissingDeps += "exiftool"
}

if ($MissingDeps.Count -gt 0) {
    Write-Host "Error: Missing dependencies: $($MissingDeps -join ', ')"
    Write-Host ""
    foreach ($dep in $MissingDeps) {
        switch ($dep) {
            "ffprobe" {
                Write-Host "  ffprobe: Install ffmpeg"
                Write-Host "    scoop install ffmpeg"
                Write-Host "    or: winget install ffmpeg"
            }
            "exiftool" {
                Write-Host "  exiftool: Install exiftool"
                Write-Host "    scoop install exiftool"
            }
        }
        Write-Host ""
    }
    exit 1
}

# ------------------------------------------------------------------
# Counters
# ------------------------------------------------------------------
$Processed = 0
$Warnings = 0
$Errors = 0
$SeqCounter = 0
$ReservedNames = @{}

# ------------------------------------------------------------------
# Get metadata timestamp from a file
# Returns: YYYYMMDD-HHmmss or $null
# ------------------------------------------------------------------
function Get-MetadataTimestamp {
    param([string]$FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()
    $ts = $null

    $videoExts = @('mp4','mov','avi','mkv','mxf','m4v','mts','m2ts','3gp','webm')
    $audioExts = @('wav','mp3','aac','flac','m4a','ogg','wma','aiff','aif')
    $photoExts = @('jpg','jpeg','png','tiff','tif','heic','heif','cr2','cr3','nef','arw','dng','raf','rw2')

    $isVideo = $videoExts -contains $ext
    $isAudio = $audioExts -contains $ext
    $isPhoto = $photoExts -contains $ext

    # Video/Audio: ffprobe first, then exiftool
    if ($isVideo -or $isAudio) {
        # Try ffprobe stream-level creation_time
        $raw = & ffprobe -v quiet -select_streams v:0 -show_entries stream_tags=creation_time -of csv=p=0 $FilePath 2>$null
        if (-not $raw) {
            $raw = & ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 $FilePath 2>$null
        }

        if ($raw -and $raw.Trim() -ne "N/A") {
            $raw = $raw.Trim()
            if ($raw -match '^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})') {
                return "$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])$($Matches[6])"
            }
        }

        # Fallback to exiftool
        foreach ($tag in @('CreateDate', 'DateTimeOriginal')) {
            $raw = & exiftool -s3 -$tag $FilePath 2>$null
            if ($raw -and $raw.Trim() -ne "0000:00:00 00:00:00") {
                $raw = $raw.Trim()
                if ($raw -match '^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})') {
                    return "$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])$($Matches[6])"
                }
            }
        }
    }

    # Photos: exiftool
    if ($isPhoto) {
        foreach ($tag in @('DateTimeOriginal', 'CreateDate', 'ModifyDate')) {
            $raw = & exiftool -s3 -$tag $FilePath 2>$null
            if ($raw -and $raw.Trim() -ne "0000:00:00 00:00:00") {
                $raw = $raw.Trim()
                if ($raw -match '^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})') {
                    return "$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])$($Matches[6])"
                }
            }
        }
    }

    # Generic fallback for unknown types
    if (-not $isVideo -and -not $isAudio -and -not $isPhoto) {
        $raw = & ffprobe -v quiet -show_entries format_tags=creation_time -of csv=p=0 $FilePath 2>$null
        if ($raw -and $raw.Trim() -ne "N/A") {
            $raw = $raw.Trim()
            if ($raw -match '^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})') {
                return "$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])$($Matches[6])"
            }
        }

        foreach ($tag in @('DateTimeOriginal', 'CreateDate', 'ModifyDate')) {
            $raw = & exiftool -s3 -$tag $FilePath 2>$null
            if ($raw -and $raw.Trim() -ne "0000:00:00 00:00:00") {
                $raw = $raw.Trim()
                if ($raw -match '^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})') {
                    return "$($Matches[1])$($Matches[2])$($Matches[3])-$($Matches[4])$($Matches[5])$($Matches[6])"
                }
            }
        }
    }

    return $null
}

# ------------------------------------------------------------------
# Resolve collision
# ------------------------------------------------------------------
function Resolve-FileName {
    param(
        [string]$Dir,
        [string]$Base,
        [string]$Ext
    )

    $name = "$Base.$Ext"
    $candidate = Join-Path $Dir $name
    if (-not (Test-Path $candidate) -and -not $script:ReservedNames.ContainsKey($name)) {
        $script:ReservedNames[$name] = $true
        return $name
    }

    $n = 2
    while ($true) {
        $suffix = "{0:D2}" -f $n
        $name = "$Base-$suffix.$Ext"
        $candidate = Join-Path $Dir $name
        if (-not (Test-Path $candidate) -and -not $script:ReservedNames.ContainsKey($name)) {
            $script:ReservedNames[$name] = $true
            return $name
        }
        $n++
    }
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
Write-Host ""
Write-Host "arko-dump v$Version"
Write-Host ([string][char]0x2500 * 14)
Write-Host "Carpeta: $TargetDir\"

if ($DryRun) {
    Write-Host "Modo: --dry-run (no se movera nada)"
}

# Discover subdirectories
$Sources = Get-ChildItem -Path $TargetDir -Directory | Sort-Object Name

if ($Sources.Count -eq 0) {
    Write-Host ""
    Write-Host "No se encontraron subcarpetas en $TargetDir\"
    exit 0
}

# Print source summary
$summary = "Fuentes detectadas:"
foreach ($src in $Sources) {
    $count = (Get-ChildItem -Path $src.FullName -File -ErrorAction SilentlyContinue).Count
    $summary += " $($src.Name) ($count)"
}
Write-Host $summary
Write-Host ""

# Validate subdirectory names
$hasInvalid = $false
foreach ($src in $Sources) {
    if ($src.Name -notmatch '^[a-z0-9-]+$') {
        Write-Host "  X Nombre invalido: '$($src.Name)' -- solo se permite [a-z0-9-]"
        $hasInvalid = $true
        $Errors++
    }
}

if ($hasInvalid) {
    Write-Host ""
    Write-Host "Error: Renombra las subcarpetas invalidas y vuelve a ejecutar."
    Write-Host ([string][char]0x2500 * 14)
    Write-Host "Procesados: 0  |  Warnings: $Warnings  |  Errores: $Errors"
    exit 1
}

# Process each source
foreach ($src in $Sources) {
    $srcName = $src.Name

    # Check for nested subdirectories
    $nested = Get-ChildItem -Path $src.FullName -Directory -ErrorAction SilentlyContinue
    if ($nested) {
        Write-Host "  [WARN] $srcName\ contiene subcarpetas anidadas -- se omiten:"
        foreach ($nd in $nested) {
            Write-Host "      $($nd.Name)\"
        }
        $Warnings++
    }

    # Get files (first level only)
    $files = Get-ChildItem -Path $src.FullName -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $files) { continue }

    Write-Host "Procesando $srcName\ ($($files.Count) archivos)..."

    foreach ($file in $files) {
        $ext = $file.Extension.TrimStart('.').ToLower()
        $warnMsg = ""

        # Get timestamp
        $ts = Get-MetadataTimestamp -FilePath $file.FullName

        if (-not $ts) {
            # Filesystem fallback
            $modTime = $file.LastWriteTime
            if ($modTime) {
                $ts = $modTime.ToString("yyyyMMdd-HHmmss")
                $warnMsg = "sin metadata, usando filesystem"
                $Warnings++
            } else {
                $SeqCounter++
                $ts = "{0:D5}" -f $SeqCounter
                $warnMsg = "sin metadata ni fecha de filesystem, usando secuencial"
                $Warnings++
            }
        }

        # Build new name
        $newBase = "${srcName}_${ts}"
        $newName = Resolve-FileName -Dir $TargetDir -Base $newBase -Ext $ext

        if ($DryRun) {
            if ($warnMsg) {
                Write-Host "  -> $newName ([WARN] $warnMsg)"
            } else {
                Write-Host "  -> $newName"
            }
        } else {
            Move-Item -Path $file.FullName -Destination (Join-Path $TargetDir $newName)
            if ($warnMsg) {
                Write-Host "  [WARN] $newName ($warnMsg)"
            } else {
                Write-Host "  [OK] $newName"
            }
        }

        $Processed++
    }
}

# Remove empty subdirectories
if (-not $DryRun) {
    foreach ($src in $Sources) {
        if (Test-Path $src.FullName) {
            $remaining = (Get-ChildItem -Path $src.FullName -File -Recurse -ErrorAction SilentlyContinue).Count
            if ($remaining -eq 0) {
                Remove-Item -Path $src.FullName -Recurse -Force
            }
        }
    }
}

Write-Host ""
Write-Host ([string][char]0x2500 * 14)
Write-Host "Procesados: $Processed  |  Warnings: $Warnings  |  Errores: $Errors"
Write-Host ""

if ($DryRun) {
    Write-Host "(dry-run -- no se movio nada)"
} else {
    Write-Host "[OK] Dump completo."
}
