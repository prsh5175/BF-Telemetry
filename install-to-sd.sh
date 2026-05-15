#!/bin/bash
# BF-Telemetry Safe SD Card Installer for macOS
# This script safely merges widget files into your SD card without deleting other scripts (Yaapu, iNav, etc.)
# Usage: ./install-to-sd.sh

set -e

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

# List mounted volumes
echo -e "${YELLOW}Mounted volumes:${NC}"
diskutil list | grep '/Volumes/' | head -20 | nl

echo ""
echo -e "${YELLOW}Enter your SD card mount path (e.g., /Volumes/ELRS):${NC}"
read -p "> " SD_PATH

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
read -p "Proceed? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Installation cancelled."
    exit 1
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

# Optional scripts (ask user first to avoid conflicts)
if [ -d "$SCRIPT_DIR/SCRIPTS" ] && [ "$(ls -A "$SCRIPT_DIR/SCRIPTS")" ]; then
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
