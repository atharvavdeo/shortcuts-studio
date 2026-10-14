#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .build/assistant-validation
for STUDIO_SOURCE in OnDeviceIntelligence AppControl PhoneAssistant; do
 sed '/^import WorkflowCore$/d' "Sources/ShortcutStudio/$STUDIO_SOURCE.swift" > ".build/assistant-validation/$STUDIO_SOURCE.swift"
done
xcrun swiftc -parse-as-library Sources/WorkflowCore/*.swift .build/assistant-validation/*.swift verification/validate-assistant.swift -o .build/assistant-validation/validate-assistant
.build/assistant-validation/validate-assistant
