# ╔══════════════════════════════════════════════════════════════╗
# ║                 Team PowerShell Profile                     ║
# ║           Aliases • Functions • Prompt • Colors             ║
# ╚══════════════════════════════════════════════════════════════╝

# ==============================================================================
# 1. PROMPT (Starship)
# ==============================================================================

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# ==============================================================================
# 2. NVM FOR WINDOWS
# ==============================================================================

# nvm-windows manages its own PATH — no extra config needed.

# ==============================================================================
# 3. ALIASES
# ==============================================================================

# Eza (modern ls with icons)
Set-Alias -Name ls -Value eza -Option AllScope
function ll { eza -l --icons --git @args }
function la { eza -la --icons --git @args }
function lt { eza --tree --icons --level=2 @args }
function lta { eza --tree --icons --level=2 -a @args }

# Bat (modern cat)
Set-Alias -Name cat -Value bat -Option AllScope

# System
function .. { Set-Location .. }
function ... { Set-Location ../.. }
Set-Alias -Name c -Value Clear-Host
function reload { . $PROFILE }

# arko-dump (flatten media subdirs with timestamps)
function arko-dump {
    & "$env:USERPROFILE\arko-dump.ps1" @args
}

# ==============================================================================
# 4. MEDIA FUNCTIONS
# ==============================================================================

# Download YouTube video at 1080p
function yt {
    param([Parameter(Mandatory)][string]$Url)
    $outDir = [System.IO.Path]::Combine($HOME, "Downloads")
    yt-dlp -f "bestvideo[height<=1080]+bestaudio/best[height<=1080]" -ciw -o "$outDir/%(channel_handle,channel)s.%(ext)s" $Url
}

# Download Audio Only from YouTube
function yt-a {
    param(
        [Parameter(Mandatory)][string]$Url,
        [string]$Format = "mp3"
    )
    $outDir = [System.IO.Path]::Combine($HOME, "Downloads")
    Write-Host "🎵 Downloading best audio and converting to $Format..."
    yt-dlp -x --audio-format $Format --audio-quality 0 -o "$outDir/%(title)s.%(ext)s" $Url
    Write-Host "✅ Done!"
}

# Simple MP4 Converter
function mp4 {
    param([Parameter(Mandatory)][string]$InputFile)

    if (-not (Test-Path $InputFile)) {
        Write-Host "Error: File '$InputFile' not found"
        return
    }

    $output = [System.IO.Path]::ChangeExtension($InputFile, ".mp4")
    Write-Host "🎥 Converting '$InputFile' to '$output'..."
    ffmpeg -i $InputFile -c:v libx264 -c:a aac $output
    if ($LASTEXITCODE -eq 0) { Write-Host "✅ Done: $output" }
}

# ==============================================================================
# 5. IMAGE FUNCTIONS
# ==============================================================================

# Convert all images in current folder to WebP and delete originals
function mgck {
    Write-Host "🖼️  Converting images to WebP..."
    $exts = @("*.jpg", "*.JPG", "*.jpeg", "*.png", "*.PNG", "*.gif", "*.heic")
    $images = $exts | ForEach-Object { Get-ChildItem -Filter $_ -ErrorAction SilentlyContinue }

    if (-not $images) {
        Write-Host "No images found in current directory."
        return
    }

    magick mogrify -quality 75 -format webp ($images | ForEach-Object { $_.Name })

    Write-Host "🗑️  Deleting originals..."
    $images | Remove-Item -Force

    Write-Host "✅ WebP conversion complete."
}

# Remove background from images (requires Docker)
function rembg {
    param([Parameter(Mandatory)][string]$Path)

    $Path = $Path.TrimEnd('\', '/')

    if (Test-Path $Path -PathType Leaf) {
        $dir = (Resolve-Path (Split-Path $Path)).Path
        $filename = Split-Path $Path -Leaf
        $name = [System.IO.Path]::GetFileNameWithoutExtension($filename)

        Write-Host "Processing: $filename"
        docker run --rm -v "${dir}:/data" danielgatis/rembg i "/data/$filename" "/data/nobg-${name}.png"
        Write-Host "Done! Saved as: $dir\nobg-${name}.png"
    }
    elseif (Test-Path $Path -PathType Container) {
        $dir = (Resolve-Path $Path).Path
        Write-Host "Processing images in: $dir"
        Write-Host "---"

        $count = 0
        $exts = @("*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG", "*.webp", "*.WEBP")
        $images = $exts | ForEach-Object { Get-ChildItem -Path $dir -Filter $_ -ErrorAction SilentlyContinue }

        foreach ($img in $images) {
            $filename = $img.Name
            $name = [System.IO.Path]::GetFileNameWithoutExtension($filename)

            Write-Host "Processing: $filename"
            docker run --rm -v "${dir}:/data" danielgatis/rembg i "/data/$filename" "/data/nobg-${name}.png"
            $count++
        }

        Write-Host "---"
        Write-Host "Done! Processed $count images in $dir"
    }
    else {
        Write-Host "Error: '$Path' is not a valid file or directory"
    }
}

# ==============================================================================
# 6. PDF FUNCTIONS
# ==============================================================================

# Compress PDF using ImageMagick
function pdf-comp {
    param(
        [Parameter(Mandatory)][string]$InputFile,
        [int]$Dpi = 300
    )

    if (-not (Test-Path $InputFile)) {
        Write-Host "Error: File '$InputFile' not found"
        return
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $ext = [System.IO.Path]::GetExtension($InputFile)
    $dir = Split-Path $InputFile
    $output = Join-Path $dir "$base (comp)$ext"

    Write-Host "📉 Compressing PDF at ${Dpi} DPI..."
    magick -density $Dpi $InputFile -quality 75 -compress jpeg $output
    Write-Host "✅ Saved as: $output"
}

# Split PDF into images
function pdf-split {
    param(
        [Parameter(Mandatory)][string]$InputFile,
        [string]$Format = "jpg"
    )

    if (-not (Test-Path $InputFile)) {
        Write-Host "Error: File '$InputFile' not found"
        return
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outDir = "$base-pages"

    Write-Host "📂 Creating folder: $outDir"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null

    Write-Host "✂️  Splitting PDF..."
    magick -density 300 $InputFile -quality 85 "$outDir/$base-%03d.$Format"
    Write-Host "✅ Done."
}

# Merge all PDFs in current directory
function pdf-merge {
    param([string]$OutputFile = "merged-output.pdf")

    $pdfs = Get-ChildItem -Filter *.pdf -ErrorAction SilentlyContinue
    if (-not $pdfs) {
        Write-Host "❌ No PDF files found in this directory."
        return
    }

    Write-Host "🔗 Merging all PDFs in folder..."
    qpdf --empty --pages ($pdfs | ForEach-Object { $_.Name }) -- $OutputFile
    Write-Host "✅ Saved as: $OutputFile"
}

# Join PDFs from a specific folder
function qpdf-join {
    param([Parameter(Mandatory)][string]$Folder)

    if (-not (Test-Path $Folder -PathType Container)) {
        Write-Host "Error: '$Folder' is not a directory"
        return
    }

    $pdfs = Get-ChildItem -Path $Folder -Filter *.pdf | Sort-Object Name
    if (-not $pdfs) {
        Write-Host "No PDF files found in '$Folder'"
        return
    }

    $output = Join-Path $Folder "merged.pdf"
    Write-Host "Merging $($pdfs.Count) PDFs from $Folder..."
    qpdf --empty --pages ($pdfs | ForEach-Object { $_.FullName }) -- $output
    Write-Host "✅ Done: $output"
}

# ==============================================================================
# 7. PSReadLine (better editing experience)
# ==============================================================================

if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
