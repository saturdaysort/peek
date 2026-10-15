#!/bin/zsh -f
# Builds build/Peek.app from the Swift package: release binary, Info.plist, font, hook.
# Ad-hoc signed (no developer account needed); that is enough for a personal agent app.
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release --product Peek
bin="$(swift build -c release --show-bin-path)/Peek"

app=build/Peek.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Peek"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/PressStart2P-Regular.ttf Resources/OFL.txt "$app/Contents/Resources/"
install -m 755 hook/peek-hook "$app/Contents/Resources/peek-hook"

codesign --force --sign - "$app"
codesign --verify "$app"
echo "Built $app"
