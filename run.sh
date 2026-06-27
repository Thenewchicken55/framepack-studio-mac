echo Starting FramePack-Studio...

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_CMD=""
for cmd in python3 python; do
    if command -v $cmd &>/dev/null; then
        PYTHON_CMD=$cmd
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
  echo "Did not find a Python binary. Exiting."
  exit 1
fi

if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
  source "$SCRIPT_DIR/venv/bin/activate"
  "$SCRIPT_DIR/venv/bin/$PYTHON_CMD" "$SCRIPT_DIR/studio.py" "$@"
elif [ -f "./venv/bin/activate" ]; then
  source ./venv/bin/activate
  python studio.py "$@"
else
  echo "Did not find a Python virtual environment. Exiting."
  exit 1
fi