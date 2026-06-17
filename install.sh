#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Variables
# -----------------------------

COMFY_DIR="$HOME/comfyui"

PYTHON_VERSION="3.11"
PYTHON_BIN="/opt/homebrew/bin/python${PYTHON_VERSION}"

TEMP_DIR="$COMFY_DIR/temp"
COMFY_TEMP_DIR="$TEMP_DIR/ComfyUI"

COMFY_REPO="https://github.com/comfy-org/ComfyUI.git"

MANAGER_DIR="$COMFY_DIR/custom_nodes/comfyui-manager"
MANAGER_REPO="https://github.com/Comfy-Org/ComfyUI-Manager.git"

# -----------------------------
# Colors
# -----------------------------

if [ -t 1 ]; then
  BOLD="$(tput bold)"
  RESET="$(tput sgr0)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
else
  BOLD=""
  RESET=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
fi

# -----------------------------
# Safety check
# -----------------------------

mkdir -p "$COMFY_DIR"
cd "$COMFY_DIR"

# -----------------------------
# Install Homebrew Python
# -----------------------------

brew install "python@${PYTHON_VERSION}"

if [ ! -x "$PYTHON_BIN" ]; then
  echo "${RED}${BOLD}ERROR:${RESET} Could not find $PYTHON_BIN"
  exit 1
fi

# -----------------------------
# Clone ComfyUI into temp, then copy into ~/comfyui
# -----------------------------

if [ ! -d "$COMFY_DIR/.git" ]; then
  mkdir -p "$TEMP_DIR"
  rm -rf "$COMFY_TEMP_DIR"

  git clone "$COMFY_REPO" "$COMFY_TEMP_DIR"

  rsync -a \
    --exclude 'temp' \
    "$COMFY_TEMP_DIR"/ \
    "$COMFY_DIR"/
else
  echo "${YELLOW}ComfyUI already appears installed at:${RESET} $COMFY_DIR"
fi

# -----------------------------
# Create Python venv
# -----------------------------

cd "$COMFY_DIR"

if [ ! -d "$COMFY_DIR/venv" ]; then
  "$PYTHON_BIN" -m venv venv
fi

# -----------------------------
# Install Python dependencies
# -----------------------------

"$COMFY_DIR/venv/bin/python" --version
"$COMFY_DIR/venv/bin/python" -m pip install --upgrade pip setuptools wheel
"$COMFY_DIR/venv/bin/pip" install torch torchvision torchaudio
"$COMFY_DIR/venv/bin/pip" install -r "$COMFY_DIR/requirements.txt"

# -----------------------------
# Install ComfyUI-Manager
# -----------------------------

mkdir -p "$COMFY_DIR/custom_nodes"

if [ ! -d "$MANAGER_DIR/.git" ]; then
  rm -rf "$MANAGER_DIR"
  git clone "$MANAGER_REPO" "$MANAGER_DIR"
else
  echo "${YELLOW}ComfyUI-Manager already appears installed at:${RESET} $MANAGER_DIR"
fi

"$COMFY_DIR/venv/bin/pip" install -r "$MANAGER_DIR/requirements.txt"

# -----------------------------
# Create start.sh
# -----------------------------

cat > "$COMFY_DIR/start.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/comfyui"

./venv/bin/python main.py --listen 0.0.0.0 --port 8188
EOF

chmod +x "$COMFY_DIR/start.sh"

# -----------------------------
# MPS verification
# -----------------------------

MPS_SUMMARY="$("$COMFY_DIR/venv/bin/python" - <<'PY'
import torch

mps_built = torch.backends.mps.is_built()
mps_available = torch.backends.mps.is_available()

print(f"torch_version={torch.__version__}")
print(f"mps_built={mps_built}")
print(f"mps_available={mps_available}")
PY
)"

TORCH_VERSION="$(echo "$MPS_SUMMARY" | awk -F= '/torch_version/ {print $2}')"
MPS_BUILT="$(echo "$MPS_SUMMARY" | awk -F= '/mps_built/ {print $2}')"
MPS_AVAILABLE="$(echo "$MPS_SUMMARY" | awk -F= '/mps_available/ {print $2}')"

if [ "$MPS_BUILT" = "True" ] && [ "$MPS_AVAILABLE" = "True" ]; then
  MPS_STATUS="${GREEN}ENABLED${RESET}"
else
  MPS_STATUS="${RED}NOT ENABLED${RESET}"

  echo
  echo "${RED}${BOLD}ERROR: Apple Silicon MPS is not fully enabled.${RESET}"
  echo
  echo "MPS built:      $MPS_BUILT"
  echo "MPS available:  $MPS_AVAILABLE"
  echo
  exit 1
fi

# -----------------------------
# Get LAN IP
# -----------------------------

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"

if [ -z "$LAN_IP" ]; then
  LAN_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

if [ -z "$LAN_IP" ]; then
  LAN_IP="$(route get default 2>/dev/null | awk '/interface:/ {print $2}' | xargs -I{} ipconfig getifaddr {} 2>/dev/null || true)"
fi

if [ -z "$LAN_IP" ]; then
  LAN_IP="<lan-ip>"
fi

# -----------------------------
# Cleanup temp
# -----------------------------

rm -rf "$TEMP_DIR"

# -----------------------------
# Done
# -----------------------------

echo
echo "${CYAN}${BOLD}============================================================${RESET}"
echo "${GREEN}${BOLD} ComfyUI install complete${RESET}"
echo "${CYAN}${BOLD}============================================================${RESET}"
echo
echo "${BOLD}Install path:${RESET}"
echo "  ${COMFY_DIR}"
echo
echo "${BOLD}Python:${RESET}"
echo "  ${PYTHON_VERSION}"
echo
echo "${BOLD}PyTorch:${RESET}"
echo "  ${TORCH_VERSION}"
echo
echo "${BOLD}Apple Silicon MPS:${RESET}"
echo "  Built:      ${MPS_BUILT}"
echo "  Available: ${MPS_AVAILABLE}"
echo "  Status:    ${MPS_STATUS}"
echo
echo "${BOLD}Launch ComfyUI:${RESET}"
echo "  ${GREEN}${COMFY_DIR}/start.sh${RESET}"
echo
echo "${BOLD}Open from browser:${RESET}"
echo "  ${BLUE}http://localhost:8188${RESET}"
echo "  ${BLUE}http://${LAN_IP}:8188${RESET}"
echo
echo "${CYAN}${BOLD}============================================================${RESET}"
echo

read -r -p "$(printf "%sStart ComfyUI now? [y/N]: %s" "$YELLOW" "$RESET")" START_COMFY

case "$START_COMFY" in
  y|Y|yes|YES)
    echo "${YELLOW}Starting ComfyUI...${RESET}"
    exec "$COMFY_DIR/start.sh"
    ;;
  *)
    echo "${CYAN}Not starting ComfyUI.${RESET}"
    echo "Launch later with:"
    echo "  ${GREEN}${COMFY_DIR}/start.sh${RESET}"
    ;;
esac
