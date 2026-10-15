#!/bin/zsh -f
# Builds Peek, replaces $HOME/Applications/Peek.app, and relaunches it.
# Claude Code's hook entries (scripts/hooks.py) point at the hook inside this exact path.
set -euo pipefail
cd "${0:A:h}/.."

scripts/build.sh
pkill -x Peek 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$HOME/Applications/Peek.app"
ditto build/Peek.app "$HOME/Applications/Peek.app"
open -g "$HOME/Applications/Peek.app"
echo "Installed $HOME/Applications/Peek.app"
