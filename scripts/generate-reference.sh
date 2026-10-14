#!/bin/bash
set -euo pipefail
STUDIO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$STUDIO_ROOT"
mkdir -p .build/reference
xcrun swiftc -parse-as-library Sources/WorkflowCore/*.swift scripts/export-reference.swift -o .build/reference/export-reference
.build/reference/export-reference "$STUDIO_ROOT"
python3 - <<'PY'
from pathlib import Path
import hashlib,json
r=Path.cwd();files=sorted((r/'Sources/WorkflowCore').glob('*.swift'))+[r/'scripts/export-reference.swift',r/'scripts/generate-reference.sh',r/'docs/ACTION_REFERENCE.md',r/'docs/action-catalog.json',r/'docs/workflow-value-encoding.json']
(r/'docs/.reference-hashes.json').write_text(json.dumps({str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},indent=2)+'\n')
PY
