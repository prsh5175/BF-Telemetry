#!/bin/bash
# BF-Telemetry Safe SD Card Installer for macOS
# This script safely merges widget files into your SD card without deleting other scripts (Yaapu, iNav, etc.)
# Usage: ./install-to-sd.sh

set -e

usage() {
    cat <<'EOF'
Usage:
    ./install-to-sd.sh
    ./install-to-sd.sh --sd /Volumes/EDGETX --yes [--with-sounds] [--with-scripts]

Options:
    --sd PATH         SD card mount path (non-interactive mode)
    --yes             Skip confirmation prompt (non-interactive mode)
    --with-sounds     Merge SOUNDS/en without prompting
    --with-scripts    Merge SCRIPTS without prompting
    --help            Show this help

Examples:
    ./install-to-sd.sh --sd /Volumes/EDGETX --yes
    ./install-to-sd.sh --sd /Volumes/EDGETX --yes --with-sounds --with-scripts
EOF
}

SD_PATH=""
AUTO_CONFIRM=0
INCLUDE_SOUNDS=0
INCLUDE_SCRIPTS=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --sd)
            SD_PATH="${2:-}"
            if [ -z "$SD_PATH" ]; then
                echo "Error: --sd requires a path"
                exit 1
            fi
            shift 2
            ;;
        --yes)
            AUTO_CONFIRM=1
            shift
            ;;
        --with-sounds)
            INCLUDE_SOUNDS=1
            shift
            ;;
        --with-scripts)
            INCLUDE_SCRIPTS=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}BF-Telemetry Safe SD Card Installer${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "This script will safely merge BF-Telemetry files to your SD card"
echo "without deleting other scripts (Yaapu, iNav, etc.)"
echo "Default mode installs only WIDGETS/BFTelem (recommended)."
echo ""

if [ -z "$SD_PATH" ]; then
    # List mounted volumes
    echo -e "${YELLOW}Mounted volumes:${NC}"
    diskutil list | grep '/Volumes/' | head -20 | nl

    echo ""
    echo -e "${YELLOW}Enter your SD card mount path (e.g., /Volumes/ELRS):${NC}"
    read -p "> " SD_PATH
fi

# Validate SD path
if [ ! -d "$SD_PATH" ]; then
    echo -e "${RED}Error: Path does not exist: $SD_PATH${NC}"
    exit 1
fi

if [ ! -w "$SD_PATH" ]; then
    echo -e "${RED}Error: No write permission to: $SD_PATH${NC}"
    exit 1
fi

# Confirm before proceeding
echo ""
echo -e "${YELLOW}Ready to install to: ${GREEN}$SD_PATH${NC}"
echo ""
echo "This will always merge:"
echo "  • WIDGETS/BFTelem -> $SD_PATH/WIDGETS/BFTelem/"
echo ""
echo "Optional extras (you can choose later):"
echo "  • SOUNDS/en/*.wav -> $SD_PATH/SOUNDS/en/"
echo "  • SCRIPTS/* -> $SD_PATH/SCRIPTS/"
echo ""
echo -e "${RED}WARNING: Ensure your SD card is mounted correctly!${NC}"
if [ "$AUTO_CONFIRM" -eq 1 ]; then
    echo "Auto-confirm enabled via --yes"
else
    read -p "Proceed? (yes/no) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure destination folders exist
echo -e "${BLUE}Creating destination folders if needed...${NC}"
mkdir -p "$SD_PATH/WIDGETS"

# Safe rsync merge: updates files, does NOT delete unrelated folders
echo ""
echo -e "${BLUE}Syncing WIDGETS/BFTelem...${NC}"
if rsync -av --exclude ".DS_Store" "$SCRIPT_DIR/WIDGETS/BFTelem/" "$SD_PATH/WIDGETS/BFTelem/"; then
    echo -e "${GREEN}✓ WIDGETS merged successfully${NC}"
else
    echo -e "${RED}✗ WIDGETS sync failed${NC}"
    exit 1
fi

if [ -d "$SCRIPT_DIR/SOUNDS/en" ] && [ "$(ls -A "$SCRIPT_DIR/SOUNDS/en")" ]; then
    if [ "$INCLUDE_SOUNDS" -eq 0 ] && [ "$AUTO_CONFIRM" -eq 1 ]; then
        echo -e "${BLUE}Skipping SOUNDS merge (use --with-sounds to include).${NC}"
    elif [ "$INCLUDE_SOUNDS" -eq 1 ]; then
        mkdir -p "$SD_PATH/SOUNDS/en"
        echo -e "${BLUE}Syncing SOUNDS/en...${NC}"
        if rsync -av --exclude ".DS_Store" "$SCRIPT_DIR/SOUNDS/en/" "$SD_PATH/SOUNDS/en/"; then
            echo -e "${GREEN}✓ SOUNDS merged successfully${NC}"
        else
            echo -e "${RED}✗ SOUNDS sync failed${NC}"
            exit 1
        fi
    else
    echo ""
    echo -e "${YELLOW}Optional: merge custom SOUNDS/en files? (yes/no)${NC}"
    echo "Tip: not required for BF-Telemetry; EdgeTX system voices work by default."
    read -p "> " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        mkdir -p "$SD_PATH/SOUNDS/en"
        echo -e "${BLUE}Syncing SOUNDS/en...${NC}"
        if rsync -av --exclude ".DS_Store" "$SCRIPT_DIR/SOUNDS/en/" "$SD_PATH/SOUNDS/en/"; then
            echo -e "${GREEN}✓ SOUNDS merged successfully${NC}"
        else
            echo -e "${RED}✗ SOUNDS sync failed${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}Skipping SOUNDS merge.${NC}"
    fi
    fi
fi

# Optional scripts (ask user first to avoid conflicts)
if [ -d "$SCRIPT_DIR/SCRIPTS" ] && [ "$(ls -A "$SCRIPT_DIR/SCRIPTS")" ]; then
    if [ "$INCLUDE_SCRIPTS" -eq 0 ] && [ "$AUTO_CONFIRM" -eq 1 ]; then
        echo -e "${BLUE}Skipping SCRIPTS merge (use --with-scripts to include).${NC}"
    elif [ "$INCLUDE_SCRIPTS" -eq 1 ]; then
        mkdir -p "$SD_PATH/SCRIPTS"
        echo -e "${BLUE}Syncing SCRIPTS...${NC}"
        if rsync -av --exclude ".DS_Store" "$SCRIPT_DIR/SCRIPTS/" "$SD_PATH/SCRIPTS/"; then
            echo -e "${GREEN}✓ SCRIPTS merged successfully${NC}"
        else
            echo -e "${RED}✗ SCRIPTS sync failed${NC}"
            exit 1
        fi
    else
    echo ""
    echo -e "${YELLOW}SCRIPTS folder found in repo. Merge to SD? (yes/no)${NC}"
    read -p "> " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        mkdir -p "$SD_PATH/SCRIPTS"
        echo -e "${BLUE}Syncing SCRIPTS...${NC}"
        if rsync -av --exclude ".DS_Store" "$SCRIPT_DIR/SCRIPTS/" "$SD_PATH/SCRIPTS/"; then
            echo -e "${GREEN}✓ SCRIPTS merged successfully${NC}"
        else
            echo -e "${RED}✗ SCRIPTS sync failed${NC}"
            exit 1
        fi
    fi
    fi
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Your SD card is ready. No existing scripts were removed."
echo ""
echo "Next steps:"
echo "  1. Eject SD card safely"
echo "  2. Insert into your radio"
echo "  3. Add BF Telemetry widget to your screen in model settings"
echo ""
