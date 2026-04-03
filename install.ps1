# ╔══════════════════════════════════════════════════════════════╗
# ║           Team CLI Tools Installer (Windows)                ║
# ║        Installs terminal tools, aliases & configs           ║
# ╚══════════════════════════════════════════════════════════════╝

#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗"
Write-Host "║           Team CLI Tools Installer (Windows)                ║"
Write-Host "╚══════════════════════════════════════════════════════════════╝"
Write-Host ""

# ------------------------------------------------------------------
# 1. SCOOP PACKAGE MANAGER
# ------------------------------------------------------------------
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing Scoop..."
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
} else {
    Write-Host "✅ Scoop already installed"
}

# Add extras bucket (needed for some packages)
scoop bucket list | Select-String -Quiet "extras" | Out-Null
if ($LASTEXITCODE -ne 0) {
    scoop bucket add extras
}
scoop bucket list | Select-String -Quiet "nerd-fonts" | Out-Null
if ($LASTEXITCODE -ne 0) {
    scoop bucket add nerd-fonts
}

# ------------------------------------------------------------------
# 2. SCOOP PACKAGES
# ------------------------------------------------------------------
Write-Host ""
Write-Host "📦 Installing CLI tools via Scoop..."

$ScoopPackages = @(
    "yt-dlp"          # YouTube downloader
    "ffmpeg"          # Video/audio converter
    "qpdf"            # PDF merge/split tool
    "imagemagick"     # Image processing (magick command)
    "eza"             # Modern ls replacement with icons
    "bat"             # Modern cat replacement with syntax highlighting
    "starship"        # Cross-shell prompt
    "fzf"             # Fuzzy finder
    "glow"            # Markdown renderer for the terminal
    "syncthing"       # Continuous file synchronization
)

foreach ($pkg in $ScoopPackages) {
    $installed = scoop list $pkg 2>&1 | Select-String -Quiet $pkg
    if ($installed) {
        Write-Host "  ✅ $pkg already installed"
    } else {
        Write-Host "  📥 Installing $pkg..."
        scoop install $pkg
    }
}

# ------------------------------------------------------------------
# 3. SYNCTHING SERVICE
# ------------------------------------------------------------------
Write-Host ""
Write-Host "🔄 Setting up Syncthing..."

$taskName = "Syncthing"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskExists) {
    Write-Host "  ✅ Syncthing scheduled task already exists"
} else {
    Write-Host "  🚀 Creating Syncthing startup task..."
    $syncthingPath = (Get-Command syncthing -ErrorAction SilentlyContinue).Source
    if ($syncthingPath) {
        $action = New-ScheduledTaskAction -Execute $syncthingPath -Argument "-no-browser"
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Start Syncthing at login" | Out-Null
        # Start it now too
        Start-Process -FilePath $syncthingPath -ArgumentList "-no-browser" -WindowStyle Hidden
        Write-Host "  ✅ Syncthing configured to start at login — web UI at http://127.0.0.1:8384"
    } else {
        Write-Host "  ⚠️  Could not find syncthing executable. Skipping service setup."
    }
}

# ------------------------------------------------------------------
# 4. NERD FONT
# ------------------------------------------------------------------
Write-Host ""
Write-Host "🔤 Installing JetBrainsMono Nerd Font..."
$fontInstalled = scoop list "JetBrainsMono-NF" 2>&1 | Select-String -Quiet "JetBrainsMono-NF"
if ($fontInstalled) {
    Write-Host "  ✅ Font already installed"
} else {
    scoop install nerd-fonts/JetBrainsMono-NF
}

# ------------------------------------------------------------------
# 5. WINDOWS TERMINAL CONFIG NOTE
# ------------------------------------------------------------------
Write-Host ""
Write-Host "💻 Windows Terminal"
Write-Host "  Windows Terminal should already be installed on Windows 10/11."
Write-Host "  Recommended: set JetBrainsMono Nerd Font in Settings > Profiles > Defaults > Appearance."
Write-Host "  If not installed, get it from: Microsoft Store or 'winget install Microsoft.WindowsTerminal'"

# ------------------------------------------------------------------
# 6. DOCKER CHECK
# ------------------------------------------------------------------
Write-Host ""
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "✅ Docker already installed (needed for rembg)"
} else {
    Write-Host "⚠️  Docker is NOT installed. It's required for the 'rembg' command."
    Write-Host "   Install it from: https://www.docker.com/products/docker-desktop/"
    Write-Host "   (Skipping for now)"
}

# ------------------------------------------------------------------
# 7. NVM FOR WINDOWS
# ------------------------------------------------------------------
Write-Host ""
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    Write-Host "✅ nvm-windows already installed"
} else {
    Write-Host "📦 Installing nvm-windows via Scoop..."
    scoop install nvm
}

# ------------------------------------------------------------------
# 8. POWERSHELL PROFILE
# ------------------------------------------------------------------
Write-Host ""
Write-Host "⚙️  Installing PowerShell profile..."

$profileDir = Split-Path $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (Test-Path $PROFILE) {
    Write-Host "  ⚠️  Existing profile found — backing up to profile.backup.ps1"
    Copy-Item $PROFILE "$PROFILE.backup" -Force
}

Copy-Item "$ScriptDir\configs\profile.ps1" $PROFILE -Force
Write-Host "  ✅ Installed to $PROFILE"

# ------------------------------------------------------------------
# 9. STARSHIP CONFIG
# ------------------------------------------------------------------
Write-Host ""
Write-Host "🚀 Installing Starship config..."
$starshipDir = "$env:USERPROFILE\.config"
if (-not (Test-Path $starshipDir)) {
    New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null
}

if (Test-Path "$starshipDir\starship.toml") {
    Write-Host "  ⚠️  Existing Starship config found — backing up to starship.toml.backup"
    Copy-Item "$starshipDir\starship.toml" "$starshipDir\starship.toml.backup" -Force
}

Copy-Item "$ScriptDir\configs\starship.toml" "$starshipDir\starship.toml" -Force
Write-Host "  ✅ Installed to $starshipDir\starship.toml"

# ------------------------------------------------------------------
# 10. PRE-PULL DOCKER IMAGE FOR REMBG
# ------------------------------------------------------------------
Write-Host ""
$dockerRunning = $false
if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
        docker info 2>&1 | Out-Null
        $dockerRunning = $true
    } catch { }
}

if ($dockerRunning) {
    Write-Host "🐳 Pre-pulling rembg Docker image (this may take a minute)..."
    docker pull danielgatis/rembg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠️  Could not pull image. Make sure Docker is running."
    }
} else {
    Write-Host "⏭️  Skipping rembg Docker image pull (Docker not running)"
}

# ------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗"
Write-Host "║                    ✅ All done!                             ║"
Write-Host "╚══════════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "Available commands:"
Write-Host ""
Write-Host "  Media:"
Write-Host "    yt <url>           Download YouTube video (1080p)"
Write-Host "    yt-a <url>         Download audio only (mp3/wav/flac)"
Write-Host "    mp4 <file>         Convert video to MP4"
Write-Host ""
Write-Host "  Images:"
Write-Host "    rembg <file|dir>   Remove background from images"
Write-Host "    mgck               Convert images to WebP in current folder"
Write-Host ""
Write-Host "  PDFs:"
Write-Host "    pdf-comp <file>    Compress a PDF"
Write-Host "    pdf-split <file>   Split PDF into images"
Write-Host "    pdf-merge          Merge all PDFs in current folder"
Write-Host "    qpdf-join <dir>    Merge all PDFs in a folder"
Write-Host ""
Write-Host "  Sync:"
Write-Host "    syncthing          Web UI at http://127.0.0.1:8384"
Write-Host ""
Write-Host "  Terminal:"
Write-Host "    ls / ll / la / lt  Modern file listing with icons"
Write-Host "    cat                Syntax-highlighted file viewer"
Write-Host "    c                  Clear terminal"
Write-Host "    reload             Reload profile"
Write-Host ""
Write-Host "👉 Restart Windows Terminal, or run:  . `$PROFILE"
Write-Host ""
