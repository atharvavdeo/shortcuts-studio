#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
STUDIO_SWIFTC="$(xcrun --find swiftc)"
STUDIO_PLUGIN="$(dirname "$STUDIO_SWIFTC")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [ -f "$STUDIO_PLUGIN" ]; then
    swift test -Xswiftc -load-plugin-library -Xswiftc "$STUDIO_PLUGIN"
else
    swift test
fi
