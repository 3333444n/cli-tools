# Team CLI Tools

One-command installer that sets up your Mac terminal with all the tools, aliases, and configs the team uses.

## What You Get

**Terminal:** [Ghostty](https://ghostty.org) with Catppuccin Frappe theme, split panes, and JetBrainsMono Nerd Font.

**Prompt:** [Starship](https://starship.rs) showing directory, git branch/status, and language versions.

**CLI Tools installed via Homebrew:**

| Tool | What it does |
|------|-------------|
| `yt-dlp` | YouTube video/audio downloader |
| `ffmpeg` | Video/audio converter |
| `imagemagick` | Image processing (convert, resize, compress) |
| `qpdf` | PDF merge/split/manipulate |
| `eza` | Modern `ls` with icons and git status |
| `bat` | Modern `cat` with syntax highlighting |
| `fzf` | Fuzzy finder |
| `glow` | Render Markdown in the terminal |
| `syncthing` | Continuous file synchronization between devices |
| `nvm` | Node.js version manager |

**Custom Commands:**

| Command | Description |
|---------|-------------|
| `yt <url>` | Download YouTube video at 1080p to ~/Downloads |
| `yt-a <url> [format]` | Download audio only (mp3, wav, flac, m4a) |
| `mp4 <file>` | Convert any video to MP4 |
| `rembg <file\|dir>` | Remove background from images (requires Docker) |
| `mgck` | Convert all images in current folder to WebP |
| `pdf-comp <file> [dpi]` | Compress a PDF (default 300 DPI) |
| `pdf-split <file> [format]` | Split PDF pages into individual images |
| `pdf-merge [output]` | Merge all PDFs in current directory |
| `qpdf-join <dir>` | Merge all PDFs in a specific folder |

**Shell Aliases:**

| Alias | Expands to |
|-------|-----------|
| `ls` | `eza --icons` |
| `ll` | `eza -l --icons --git` |
| `la` | `eza -la --icons --git` |
| `lt` | `eza --tree --icons --level=2` |
| `cat` | `bat` |
| `c` | `clear` |
| `reload` | `source ~/.zshrc` |

## Install

### macOS

```bash
git clone <this-repo-url>
cd cli-tools
bash install.sh
```

The script will:

1. Install Homebrew (if not already installed)
2. Install all CLI tools via `brew install` (including Syncthing)
3. Start Syncthing as a background service
4. Install JetBrainsMono Nerd Font
5. Install Ghostty terminal
6. Install NVM (Node Version Manager)
7. Copy shell configs (`.zshrc`, Starship, Ghostty)
8. Install the `rembg` background removal script
9. Pre-pull the rembg Docker image

### Windows

Open **PowerShell** and run:

```powershell
git clone <this-repo-url>
cd cli-tools
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

The script will:

1. Install [Scoop](https://scoop.sh) package manager (if not already installed)
2. Install all CLI tools via `scoop install` (including Syncthing)
3. Set up Syncthing to start at login via a scheduled task
4. Install JetBrainsMono Nerd Font
5. Install nvm-windows (Node Version Manager)
6. Install the PowerShell profile with all aliases and functions
7. Install Starship config
8. Pre-pull the rembg Docker image

> **Note:** Windows uses [Windows Terminal](https://aka.ms/terminal) + PowerShell instead of Ghostty + zsh. All commands (`yt`, `rembg`, `mp4`, `pdf-comp`, etc.) work the same way.

Existing configs are backed up automatically (e.g. `.zshrc` -> `.zshrc.backup`, `profile.ps1` -> `profile.ps1.backup`).

## Prerequisites

### macOS

- **macOS** (Apple Silicon or Intel)
- **Xcode Command Line Tools** — required by Homebrew. If not already installed, Homebrew will prompt you to install them, or run: `xcode-select --install`
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** — required for the `rembg` background removal command. The installer will skip Docker-related steps if it's not present.
- **Internet connection** — needed to download Homebrew packages, NVM, fonts, and the rembg Docker image

### Windows

- **Windows 10/11**
- **PowerShell 5.1+** (pre-installed on Windows 10/11)
- **[Git for Windows](https://git-scm.com/download/win)** — needed to clone the repo (or download the ZIP manually)
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** — required for the `rembg` background removal command. The installer will skip Docker-related steps if it's not present.
- **[Windows Terminal](https://aka.ms/terminal)** — recommended terminal (pre-installed on Windows 11, available from Microsoft Store on Windows 10)
- **Internet connection** — needed to download Scoop packages, NVM, fonts, and the rembg Docker image

## After Install

### macOS
1. Open **Ghostty** (it was installed for you)
2. Run `source ~/.zshrc` or restart the terminal
3. You're good to go

### Windows
1. Open **Windows Terminal**
2. In Settings > Profiles > Defaults > Appearance, set the font to **JetBrainsMono Nerd Font**
3. Restart the terminal or run `. $PROFILE`
4. You're good to go

## Ghostty Keybindings

| Shortcut | Action |
|----------|--------|
| `Cmd + D` | Split pane right |
| `Cmd + Shift + D` | Split pane down |
| `Cmd + Shift + Enter` | Toggle split zoom |
| `Cmd + Opt + Arrow` | Navigate between splits |
# cli-tools
