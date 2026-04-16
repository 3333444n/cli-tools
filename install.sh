#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              Team CLI Tools Installer                       ║
# ║        Installs terminal tools, aliases & configs           ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Team CLI Tools Installer                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ------------------------------------------------------------------
# 1. HOMEBREW
# ------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew already installed"
fi

# ------------------------------------------------------------------
# 2. BREW PACKAGES
# ------------------------------------------------------------------
echo ""
echo "📦 Installing CLI tools via Homebrew..."

BREW_PACKAGES=(
    yt-dlp          # YouTube downloader
    ffmpeg          # Video/audio converter
    qpdf            # PDF merge/split tool
    imagemagick     # Image processing (magick command)
    eza             # Modern ls replacement with icons
    bat             # Modern cat replacement with syntax highlighting
    starship        # Cross-shell prompt
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf             # Fuzzy finder
    glow            # Markdown renderer for the terminal
    syncthing       # Continuous file synchronization
    exiftool        # Metadata reader (used by arko-dump)
)

for pkg in "${BREW_PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        echo "  ✅ $pkg already installed"
    else
        echo "  📥 Installing $pkg..."
        brew install "$pkg"
    fi
done

# ------------------------------------------------------------------
# 3. SYNCTHING SERVICE
# ------------------------------------------------------------------
echo ""
echo "🔄 Setting up Syncthing..."
if brew services list | grep -q "syncthing.*started"; then
    echo "  ✅ Syncthing service already running"
else
    echo "  🚀 Starting Syncthing as a background service..."
    brew services start syncthing
    echo "  ✅ Syncthing started — web UI at http://127.0.0.1:8384"
fi

# ------------------------------------------------------------------
# 4. NERD FONT
# ------------------------------------------------------------------
echo ""
echo "🔤 Installing JetBrainsMono Nerd Font..."
if brew list --cask font-jetbrains-mono-nerd-font &>/dev/null; then
    echo "  ✅ Font already installed"
else
    brew install --cask font-jetbrains-mono-nerd-font
fi

# ------------------------------------------------------------------
# 5. GHOSTTY TERMINAL
# ------------------------------------------------------------------
echo ""
echo "👻 Installing Ghostty terminal..."
if brew list --cask ghostty &>/dev/null; then
    echo "  ✅ Ghostty already installed"
else
    brew install --cask ghostty
fi

# ------------------------------------------------------------------
# 6. DOCKER CHECK
# ------------------------------------------------------------------
echo ""
if command -v docker &>/dev/null; then
    echo "✅ Docker already installed (needed for rembg)"
else
    echo "⚠️  Docker is NOT installed. It's required for the 'rembg' command."
    echo "   Install it from: https://www.docker.com/products/docker-desktop/"
    echo "   (Skipping for now)"
fi

# ------------------------------------------------------------------
# 7. NVM (Node Version Manager)
# ------------------------------------------------------------------
echo ""
if [ -d "$HOME/.nvm" ]; then
    echo "✅ NVM already installed"
else
    echo "📦 Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi

# ------------------------------------------------------------------
# 8. REMBG SCRIPT
# ------------------------------------------------------------------
echo ""
echo "📄 Installing rembg-tool.sh..."
cp "$SCRIPT_DIR/configs/rembg-tool.sh" "$HOME/rembg-tool.sh"
chmod +x "$HOME/rembg-tool.sh"
echo "  ✅ Installed to ~/rembg-tool.sh"

# ------------------------------------------------------------------
# 8b. ARKO-DUMP SCRIPT
# ------------------------------------------------------------------
echo ""
echo "📄 Installing arko-dump..."
cp "$SCRIPT_DIR/configs/arko-dump.sh" "$HOME/arko-dump.sh"
chmod +x "$HOME/arko-dump.sh"
echo "  ✅ Installed to ~/arko-dump.sh"

# ------------------------------------------------------------------
# 9. GHOSTTY CONFIG
# ------------------------------------------------------------------
echo ""
echo "👻 Installing Ghostty config..."
mkdir -p "$HOME/.config/ghostty"
if [ -f "$HOME/.config/ghostty/config" ]; then
    echo "  ⚠️  Existing Ghostty config found — backing up to config.backup"
    cp "$HOME/.config/ghostty/config" "$HOME/.config/ghostty/config.backup"
fi
cp "$SCRIPT_DIR/configs/ghostty-config" "$HOME/.config/ghostty/config"
echo "  ✅ Installed to ~/.config/ghostty/config"

# ------------------------------------------------------------------
# 10. STARSHIP CONFIG
# ------------------------------------------------------------------
echo ""
echo "🚀 Installing Starship config..."
mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/starship.toml" ]; then
    echo "  ⚠️  Existing Starship config found — backing up to starship.toml.backup"
    cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.backup"
fi
cp "$SCRIPT_DIR/configs/starship.toml" "$HOME/.config/starship.toml"
echo "  ✅ Installed to ~/.config/starship.toml"

# ------------------------------------------------------------------
# 11. ZSHRC
# ------------------------------------------------------------------
echo ""
echo "⚙️  Installing .zshrc..."
if [ -f "$HOME/.zshrc" ]; then
    echo "  ⚠️  Existing .zshrc found — backing up to .zshrc.backup"
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup"
fi
cp "$SCRIPT_DIR/configs/zshrc" "$HOME/.zshrc"
echo "  ✅ Installed to ~/.zshrc"

# ------------------------------------------------------------------
# 12. PRE-PULL DOCKER IMAGE FOR REMBG
# ------------------------------------------------------------------
echo ""
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
    echo "🐳 Pre-pulling rembg Docker image (this may take a minute)..."
    docker pull danielgatis/rembg || echo "  ⚠️  Could not pull image. Make sure Docker is running."
else
    echo "⏭️  Skipping rembg Docker image pull (Docker not running)"
fi

# ------------------------------------------------------------------
# DONE
# ------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ All done!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Available commands:"
echo ""
echo "  Media:"
echo "    yt <url>           Download YouTube video (1080p)"
echo "    yt-a <url>         Download audio only (mp3/wav/flac)"
echo "    mp4 <file>         Convert video to MP4"
echo "    arko-dump <dir>    Flatten media subdirs with timestamps"
echo ""
echo "  Images:"
echo "    rembg <file|dir>   Remove background from images"
echo "    mgck               Convert images to WebP in current folder"
echo ""
echo "  PDFs:"
echo "    pdf-comp <file>    Compress a PDF"
echo "    pdf-split <file>   Split PDF into images"
echo "    pdf-merge          Merge all PDFs in current folder"
echo "    qpdf-join <dir>    Merge all PDFs in a folder"
echo ""
echo "  Sync:"
echo "    syncthing          Web UI at http://127.0.0.1:8384"
echo ""
echo "  Terminal:"
echo "    ls / ll / la / lt  Modern file listing with icons"
echo "    cat                Syntax-highlighted file viewer"
echo "    c                  Clear terminal"
echo "    reload             Reload .zshrc"
echo ""
echo "👉 Open Ghostty and run:  source ~/.zshrc"
echo ""
