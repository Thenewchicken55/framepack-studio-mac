#!/bin/bash
set -e

echo "============================================"
echo "     FramePack Studio - macOS Installer"
echo "============================================"
echo ""

# Check for Python
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v $cmd &>/dev/null; then
        version=$($cmd --version 2>&1 | awk '{print $2}')
        major=$(echo $version | cut -d. -f1)
        minor=$(echo $version | cut -d. -f2)
        # Python 3.10 - 3.12 recommended
        if [ "$major" = "3" ] && [ "$minor" -ge 10 ] && [ "$minor" -le 12 ]; then
            PYTHON_CMD=$cmd
            break
        fi
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "Error: Python 3.10-3.12 is required."
    echo "Install from https://www.python.org/downloads/ or via Homebrew:"
    echo "  brew install python@3.12"
    exit 1
fi

echo "Using Python: $($PYTHON_CMD --version)"

# Detect Apple Silicon or Intel Mac
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo "Detected: Apple Silicon (M-series)"
    DEVICE_FLAG="--mps"
else
    echo "Detected: Intel Mac"
    DEVICE_FLAG="--cpu"
fi

# Create virtual environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -d "venv" ]; then
    echo ""
    echo "Virtual environment already exists."
    # Default to no reinstall if not interactive
    if [ -t 0 ]; then
        read -p "Do you want to reinstall packages? [y/N]: " REINSTALL
    else
        REINSTALL="n"
        echo "Non-interactive shell detected, defaulting to: no reinstall"
    fi
    if [ "$REINSTALL" != "y" ] && [ "$REINSTALL" != "Y" ]; then
        echo "Skipping installation."
        exit 0
    fi
fi

echo ""
echo "Creating virtual environment..."
$PYTHON_CMD -m venv venv

echo "Upgrading pip..."
./venv/bin/python -m pip install --upgrade pip

echo ""
echo "Installing PyTorch for macOS..."
echo "--------------------------------"
echo "1) Latest stable (recommended)"
echo "2) PyTorch 2.6.0"
echo "3) PyTorch 2.5.1"
if [ -t 0 ]; then
    read -p "Select version [1]: " TORCH_CHOICE
else
    TORCH_CHOICE="1"
    echo "Non-interactive shell detected, defaulting to latest PyTorch."
fi

case "$TORCH_CHOICE" in
    2) TORCH_VERSION="2.6.0" ;;
    3) TORCH_VERSION="2.5.1" ;;
    *) TORCH_VERSION="" ;;  # Latest
esac

if [ -n "$TORCH_VERSION" ]; then
    ./venv/bin/pip install torch==$TORCH_VERSION torchvision torchaudio
else
    ./venv/bin/pip install torch torchvision torchaudio
fi

echo ""
echo "Installing FFmpeg..."
if command -v brew &>/dev/null; then
    if ! command -v ffmpeg &>/dev/null; then
        echo "Installing ffmpeg via Homebrew..."
        brew install ffmpeg
    else
        echo "FFmpeg already installed."
    fi
else
    echo "Homebrew not found. imageio-ffmpeg will be used as fallback."
    echo "For best performance, install ffmpeg via: brew install ffmpeg"
fi

echo ""
echo "Installing remaining dependencies..."
./venv/bin/pip install -r requirements_mac.txt

echo ""
echo "============================================"
echo "  Installation complete!"
echo ""
echo "  Run with:  ./run_mac.sh"
echo "============================================"
