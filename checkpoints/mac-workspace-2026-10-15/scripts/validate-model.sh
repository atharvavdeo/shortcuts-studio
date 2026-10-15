#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .build/model-validation
sed '/^import WorkflowCore$/d' Sources/ShortcutStudio/OnDeviceIntelligence.swift > .build/model-validation/OnDeviceIntelligence.swift
xcrun swiftc -parse-as-library Sources/WorkflowCore/*.swift .build/model-validation/OnDeviceIntelligence.swift verification/validate-model.swift -o .build/model-validation/validate-model
.build/model-validation/validate-model
