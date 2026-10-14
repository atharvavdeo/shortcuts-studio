#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .build/store-validation
for STUDIO_SOURCE in StudioStore ProcessRunner OnDeviceIntelligence MessengerConnector AppControl PhoneAssistant; do
    sed '/^import WorkflowCore$/d' "Sources/ShortcutStudio/$STUDIO_SOURCE.swift" > ".build/store-validation/$STUDIO_SOURCE.swift"
done
xcrun swiftc -parse-as-library Sources/WorkflowCore/*.swift .build/store-validation/*.swift verification/validate-store.swift -o .build/store-validation/validate-store
.build/store-validation/validate-store
