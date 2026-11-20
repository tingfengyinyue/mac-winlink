#!/bin/bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")" && pwd)
bin_dir=${WINLINK_BIN_DIR:-"$HOME/.local/bin"}
mkdir -p "$bin_dir"
install -m 755 "$project_dir/bin/winlink" "$bin_dir/winlink"
printf 'Installed: %s/winlink\n' "$bin_dir"
printf 'If needed, add this directory to PATH in ~/.zshrc: %s\n' "$bin_dir"
printf 'Next: winlink keygen\n'
