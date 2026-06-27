#!/bin/bash
set -e

echo "FramePack-Studio - macOS Update Script"
echo "======================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check for Git
if ! command -v git &>/dev/null; then
    echo "Error: Git is not installed. Install via: brew install git"
    exit 1
fi

# Check for Python venv
PYTHON_BIN="$SCRIPT_DIR/venv/bin/python"
if [ ! -f "$PYTHON_BIN" ]; then
    echo "Error: Virtual environment not found. Did you install correctly?"
    echo "Run ./install_mac.sh first."
    exit 1
fi

echo "Pulling latest changes from Git..."
git pull

echo ""
echo "Updating dependencies..."
"$PYTHON_BIN" -m pip install --upgrade -r requirements_mac.txt

echo ""
echo "Update complete!"
echo "Run with:  ./run_mac.sh"
