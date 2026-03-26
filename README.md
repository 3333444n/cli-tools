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
| `nvm` | Node.js version manager |

**Custom Commands:**

| Command | Description |
|---------|-------------|
| `yt <url>` | Download YouTube video at 1080p to ~/Downloads |
| `yt-audio <url> [format]` | Download audio only (mp3, wav, flac, m4a) |
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

```bash
git clone <this-repo-url>
cd cli-tools
bash install.sh
```

That's it. The script will:

1. Install Homebrew (if not already installed)
2. Install all CLI tools via `brew install`
3. Install JetBrainsMono Nerd Font
4. Install Ghostty terminal
5. Install NVM (Node Version Manager)
6. Copy shell configs (`.zshrc`, Starship, Ghostty)
7. Install the `rembg` background removal script
8. Pre-pull the rembg Docker image

Existing configs are backed up automatically (e.g. `.zshrc` -> `.zshrc.backup`).

## Requirements

- macOS
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (only needed for the `rembg` command)

## After Install

1. Open **Ghostty** (it was installed for you)
2. Run `source ~/.zshrc` or restart the terminal
3. You're good to go

## Ghostty Keybindings

| Shortcut | Action |
|----------|--------|
| `Cmd + D` | Split pane right |
| `Cmd + Shift + D` | Split pane down |
| `Cmd + Shift + Enter` | Toggle split zoom |
| `Cmd + Opt + Arrow` | Navigate between splits |
# cli-tools
