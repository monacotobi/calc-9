#!/usr/bin/env bash
# Renders the real SwiftUI views to docs/*.png. See Tools/RenderScreenshots.swift.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN="$(mktemp -d)/render-screenshots"

# The same UI sources the app builds, minus anything that needs a window server.
swiftc -O \
  Sources/Engine/*.swift \
  Sources/UI/CalcTheme.swift \
  Sources/UI/CalcState.swift \
  Sources/UI/CalcView.swift \
  Sources/UI/HelpContent.swift \
  Tools/RenderScreenshots.swift \
  -o "$BIN"

echo "Rendering screenshots into docs/"
"$BIN" docs
