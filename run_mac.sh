#!/bin/bash
echo "Starting FramePack-Studio..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$(command -v python)" ] && [ -z "$(command -v python3)" ]; then
  echo "Did not find a Python binary. Exiting."
  exit 1
fi

PYTHON_CMD="python3"
if [ ! -f "$SCRIPT_DIR/venv/bin/python3" ]; then
    if [ -f "$SCRIPT_DIR/venv/bin/python" ]; then
        PYTHON_CMD="python"
    else
        echo "Did not find a Python virtual environment. Exiting."
        exit 1
    fi
fi

source "$SCRIPT_DIR/venv/bin/activate"

"$SCRIPT_DIR/venv/bin/$PYTHON_CMD" "$SCRIPT_DIR/studio.py" "$@"
