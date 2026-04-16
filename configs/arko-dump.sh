#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  arko-dump v1.0                                             ║
# ║  Flatten media subdirectories with metadata timestamps      ║
# ╚══════════════════════════════════════════════════════════════╝

set -euo pipefail

VERSION="1.0"
DRY_RUN=false
TARGET_DIR=""

# ------------------------------------------------------------------
# Usage
# ------------------------------------------------------------------
usage() {
    cat <<'EOF'
arko-dump v1.0 — Flatten media subdirectories with metadata timestamps

Usage:
  arko-dump <carpeta>          Flatten subdirectories in place
  arko-dump --dry-run <carpeta> Show what would happen without moving
  arko-dump --help             Show this help

What it does:
  Reads first-level subdirectories (named by source), renames files
  with a prefix + metadata timestamp, and flattens them to the base
  folder. Operates in-place (move, not copy).

Naming convention:
  {source}_{YYYYMMDD}-{HHmmss}.{ext}

Example:
  arko-dump rollo/

  BEFORE:                          AFTER:
  rollo/                           rollo/
  ├── sony-a/                      ├── sony-a_20260415-143215.mp4
  │   ├── C0001.MP4                ├── sony-a_20260415-144032.mp4
  │   └── C0002.MP4                ├── sony-b_20260415-143218.mp4
  ├── sony-b/                      └── dji-mic_20260415-143210.wav
  │   └── C0001.MP4
  └── dji-mic/
      └── TX1_0001.WAV

Dependencies: ffprobe (ffmpeg), exiftool
EOF
    exit 0
}

# ------------------------------------------------------------------
# Parse arguments
# ------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            usage
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            echo "Run 'arko-dump --help' for usage."
            exit 1
            ;;
        *)
            if [[ -n "$TARGET_DIR" ]]; then
                echo "Error: Multiple directories specified."
                exit 1
            fi
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET_DIR" ]]; then
    echo "Error: No directory specified."
    echo "Run 'arko-dump --help' for usage."
    exit 1
fi

# Remove trailing slash
TARGET_DIR="${TARGET_DIR%/}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "Error: '$TARGET_DIR' is not a directory."
    exit 1
fi

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ------------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------------
MISSING_DEPS=()

if ! command -v ffprobe &>/dev/null; then
    MISSING_DEPS+=("ffprobe")
fi
if ! command -v exiftool &>/dev/null; then
    MISSING_DEPS+=("exiftool")
fi

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            ffprobe)
                echo "  ffprobe: Install ffmpeg"
                echo "    macOS:  brew install ffmpeg"
                echo "    Ubuntu: sudo apt install ffmpeg"
                ;;
            exiftool)
                echo "  exiftool: Install exiftool"
                echo "    macOS:  brew install exiftool"
                echo "    Ubuntu: sudo apt install libimage-exiftool-perl"
                ;;
        esac
        echo ""
    done
    exit 1
fi

# ------------------------------------------------------------------
# Counters
# ------------------------------------------------------------------
PROCESSED=0
WARNINGS=0
ERRORS=0

# ------------------------------------------------------------------
# Get metadata timestamp from a file
# Returns: YYYYMMDD-HHmmss or empty string
# ------------------------------------------------------------------
get_timestamp() {
    local file="$1"
    local ext="${file##*.}"
    ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    local ts=""

    # Determine file type category
    local is_video=false
    local is_audio=false
    local is_photo=false

    case "$ext" in
        mp4|mov|avi|mkv|mxf|m4v|mts|m2ts|3gp|webm)
            is_video=true ;;
        wav|mp3|aac|flac|m4a|ogg|wma|aiff|aif)
            is_audio=true ;;
        jpg|jpeg|png|tiff|tif|heic|heif|cr2|cr3|nef|arw|dng|raf|rw2)
            is_photo=true ;;
    esac

    # Video/Audio: ffprobe first, then exiftool
    if $is_video || $is_audio; then
        # Try ffprobe creation_time (stream level first, then format)
        ts=$(ffprobe -v quiet -select_streams v:0 -show_entries stream_tags=creation_time \
            -of csv=p=0 "$file" 2>/dev/null | head -1 | tr -d '[:space:]')

        if [[ -z "$ts" ]]; then
            ts=$(ffprobe -v quiet -show_entries format_tags=creation_time \
                -of csv=p=0 "$file" 2>/dev/null | head -1 | tr -d '[:space:]')
        fi

        # Parse ffprobe timestamp: 2026-04-15T14:32:15.000000Z
        if [[ -n "$ts" && "$ts" != "N/A" ]]; then
            # Extract date and time parts
            local parsed
            parsed=$(echo "$ts" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})[T ]([0-9]{2}):([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5\6/')
            if [[ "$parsed" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                echo "$parsed"
                return 0
            fi
        fi

        # Fallback to exiftool
        ts=$(exiftool -s3 -CreateDate "$file" 2>/dev/null | head -1)
        if [[ -z "$ts" || "$ts" == "0000:00:00 00:00:00" ]]; then
            ts=$(exiftool -s3 -DateTimeOriginal "$file" 2>/dev/null | head -1)
        fi
        if [[ -n "$ts" && "$ts" != "0000:00:00 00:00:00" ]]; then
            local parsed
            parsed=$(echo "$ts" | sed -E 's/^([0-9]{4}):([0-9]{2}):([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5\6/')
            if [[ "$parsed" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                echo "$parsed"
                return 0
            fi
        fi
    fi

    # Photos: exiftool first
    if $is_photo; then
        for tag in DateTimeOriginal CreateDate ModifyDate; do
            ts=$(exiftool -s3 -"$tag" "$file" 2>/dev/null | head -1)
            if [[ -n "$ts" && "$ts" != "0000:00:00 00:00:00" ]]; then
                local parsed
                parsed=$(echo "$ts" | sed -E 's/^([0-9]{4}):([0-9]{2}):([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5\6/')
                if [[ "$parsed" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                    echo "$parsed"
                    return 0
                fi
            fi
        done
    fi

    # Generic fallback: try ffprobe then exiftool for unknown types
    if ! $is_video && ! $is_audio && ! $is_photo; then
        ts=$(ffprobe -v quiet -show_entries format_tags=creation_time \
            -of csv=p=0 "$file" 2>/dev/null | head -1 | tr -d '[:space:]')
        if [[ -n "$ts" && "$ts" != "N/A" ]]; then
            local parsed
            parsed=$(echo "$ts" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})[T ]([0-9]{2}):([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5\6/')
            if [[ "$parsed" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                echo "$parsed"
                return 0
            fi
        fi

        for tag in DateTimeOriginal CreateDate ModifyDate; do
            ts=$(exiftool -s3 -"$tag" "$file" 2>/dev/null | head -1)
            if [[ -n "$ts" && "$ts" != "0000:00:00 00:00:00" ]]; then
                local parsed
                parsed=$(echo "$ts" | sed -E 's/^([0-9]{4}):([0-9]{2}):([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}).*/\1\2\3-\4\5\6/')
                if [[ "$parsed" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
                    echo "$parsed"
                    return 0
                fi
            fi
        done
    fi

    # No metadata timestamp found
    return 1
}

# ------------------------------------------------------------------
# Get filesystem modification time as fallback
# ------------------------------------------------------------------
get_fs_timestamp() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f "%Sm" -t "%Y%m%d-%H%M%S" "$file" 2>/dev/null
    else
        date -r "$file" "+%Y%m%d-%H%M%S" 2>/dev/null
    fi
}

# ------------------------------------------------------------------
# Resolve collision: returns final filename
# ------------------------------------------------------------------
# resolve_name sets RESOLVED_NAME (avoids subshell so RESERVED_NAMES persists)
resolve_name() {
    local dir="$1"
    local base="$2"   # e.g. sony-a_20260415-143215
    local ext="$3"    # e.g. mp4

    local name="${base}.${ext}"
    local candidate="${dir}/${name}"

    if [[ ! -e "$candidate" ]] && ! echo "$RESERVED_NAMES" | grep -qF "|${name}|"; then
        RESERVED_NAMES="${RESERVED_NAMES}|${name}|"
        RESOLVED_NAME="$name"
        return
    fi

    local n=2
    while true; do
        local suffix
        suffix=$(printf "%02d" "$n")
        name="${base}-${suffix}.${ext}"
        candidate="${dir}/${name}"
        if [[ ! -e "$candidate" ]] && ! echo "$RESERVED_NAMES" | grep -qF "|${name}|"; then
            RESERVED_NAMES="${RESERVED_NAMES}|${name}|"
            RESOLVED_NAME="$name"
            return
        fi
        ((n++))
    done
}

# ------------------------------------------------------------------
# Main
# ------------------------------------------------------------------
echo ""
echo "arko-dump v${VERSION}"
echo "──────────────"
echo "Carpeta: ${TARGET_DIR}/"

if $DRY_RUN; then
    echo "Modo: --dry-run (no se moverá nada)"
fi

# Discover subdirectories (first level only)
SOURCES=()
while IFS= read -r d; do
    SOURCES+=("$d")
done < <(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#SOURCES[@]} -eq 0 ]]; then
    echo ""
    echo "No se encontraron subcarpetas en ${TARGET_DIR}/"
    exit 0
fi

# Print source summary
echo -n "Fuentes detectadas:"
for src_dir in "${SOURCES[@]}"; do
    src_name="$(basename "$src_dir")"
    file_count=$(find "$src_dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
    echo -n " ${src_name} (${file_count})"
done
echo ""
echo ""

# Validate subdirectory names
HAS_INVALID=false
for src_dir in "${SOURCES[@]}"; do
    src_name="$(basename "$src_dir")"
    if ! echo "$src_name" | grep -qE '^[a-z0-9-]+$'; then
        echo "  ✗ Nombre inválido: '${src_name}' — solo se permite [a-z0-9-]"
        HAS_INVALID=true
        ((ERRORS++))
    fi
done

if $HAS_INVALID; then
    echo ""
    echo "Error: Renombra las subcarpetas inválidas y vuelve a ejecutar."
    echo "──────────────"
    echo "Procesados: 0  |  Warnings: ${WARNINGS}  |  Errores: ${ERRORS}"
    exit 1
fi

# Process each source
# Track reserved names for collision resolution (needed for dry-run)
RESERVED_NAMES=""
SEQ_COUNTER=0

for src_dir in "${SOURCES[@]}"; do
    src_name="$(basename "$src_dir")"

    # Check for nested subdirectories
    nested=$(find "$src_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    if [[ -n "$nested" ]]; then
        echo "  ⚠ ${src_name}/ contiene subcarpetas anidadas — se omiten:"
        while IFS= read -r nd; do
            echo "      $(basename "$nd")/"
        done <<< "$nested"
        ((WARNINGS++))
    fi

    # Get files (first level only)
    FILES=()
    while IFS= read -r f; do
        [[ -n "$f" ]] && FILES+=("$f")
    done < <(find "$src_dir" -maxdepth 1 -type f | sort)

    if [[ ${#FILES[@]} -eq 0 ]]; then
        continue
    fi

    echo "Procesando ${src_name}/ (${#FILES[@]} archivos)..."

    for file in "${FILES[@]}"; do
        filename="$(basename "$file")"
        ext="${filename##*.}"
        ext="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"

        # Get timestamp
        ts=""
        warn_msg=""

        ts=$(get_timestamp "$file") || true

        if [[ -z "$ts" ]]; then
            # Try filesystem fallback
            ts=$(get_fs_timestamp "$file")
            if [[ -n "$ts" ]]; then
                warn_msg="sin metadata, usando filesystem"
                ((WARNINGS++))
            else
                # Sequential fallback
                ((SEQ_COUNTER++))
                ts=$(printf "%05d" "$SEQ_COUNTER")
                warn_msg="sin metadata ni fecha de filesystem, usando secuencial"
                ((WARNINGS++))
            fi
        fi

        # Build new name
        new_base="${src_name}_${ts}"
        resolve_name "$TARGET_DIR" "$new_base" "$ext"
        new_name="$RESOLVED_NAME"

        if $DRY_RUN; then
            if [[ -n "$warn_msg" ]]; then
                echo "  → ${new_name} (⚠ ${warn_msg})"
            else
                echo "  → ${new_name}"
            fi
        else
            mv "$file" "${TARGET_DIR}/${new_name}"
            if [[ -n "$warn_msg" ]]; then
                echo "  ⚠ ${new_name} (${warn_msg})"
            else
                echo "  ✓ ${new_name}"
            fi
        fi

        ((PROCESSED++))
    done
done

# Remove empty subdirectories
if ! $DRY_RUN; then
    for src_dir in "${SOURCES[@]}"; do
        if [[ -d "$src_dir" ]]; then
            # Only remove if empty (no files, no subdirectories with files)
            remaining=$(find "$src_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$remaining" -eq 0 ]]; then
                rm -rf "$src_dir"
            fi
        fi
    done
fi

echo ""
echo "──────────────"
echo "Procesados: ${PROCESSED}  |  Warnings: ${WARNINGS}  |  Errores: ${ERRORS}"
echo ""

if $DRY_RUN; then
    echo "(dry-run — no se movió nada)"
else
    echo "✓ Dump completo."
fi
