#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .build/messenger-validation
for STUDIO_SOURCE in StudioStore ProcessRunner OnDeviceIntelligence MessengerConnector AppControl PhoneAssistant; do
 sed '/^import WorkflowCore$/d' "Sources/ShortcutStudio/$STUDIO_SOURCE.swift" > ".build/messenger-validation/$STUDIO_SOURCE.swift"
done
xcrun swiftc -parse-as-library Sources/WorkflowCore/*.swift .build/messenger-validation/*.swift verification/validate-messenger.swift -o .build/messenger-validation/validate-messenger
node gateway/test/mac-integration.mjs .build/messenger-validation/validate-messenger
