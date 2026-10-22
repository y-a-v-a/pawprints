#!/bin/bash
# Captures the Pawprints window (not the whole screen) to a PNG.
#   scripts/screenshot.sh out.png
set -euo pipefail
OUT="${1:-pawprints.png}"
ID="$(swift -e '
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
let w = list.first { ($0[kCGWindowOwnerName as String] as? String) == "Pawprints" && ($0[kCGWindowLayer as String] as? Int) == 0 }
print(w?[kCGWindowNumber as String] as? Int ?? 0)
' 2>/dev/null)"
if [[ "$ID" == "0" || -z "$ID" ]]; then echo "Pawprints window not found" >&2; exit 1; fi
screencapture -x -o -l "$ID" "$OUT"
echo "$OUT"
