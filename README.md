# Apple Silicon ComfyUI Installer
Simple [ComfyUI](https://github.com/comfy-org/comfyui) installer for Apple Silicon Macs.  
Includes [ComfyUI Manager](https://github.com/Comfy-Org/ComfyUI-Manager).

Requires [homebrew](https://brew.sh/).

## Install

To get started, simply paste this command into Terminal:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/notmayo/apple-silicon-comfyui-installer/main/install.sh)"
```

ComfyUI will be installed to:
`~/comfyui`

## Launching

After installation, the installer will ask whether you want to start ComfyUI.
For future launches, run:
```bash
bash ~/comfyui/start.sh
```
Then open ComfyUI in your browser:
```bash
http://localhost:8188
```
