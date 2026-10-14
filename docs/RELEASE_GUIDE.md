# Build, validation and release guide

## Local artifacts

The owner's current choice is **local downloads**. Packaging produces:

- `dist/Shortcut Studio.app`: native executable, original icon, bundle metadata, privacy declaration and offline handbook.
- `dist/Shortcut-Studio-macOS.zip`: app archive for local one-click download.
- `dist/Shortcut-Studio-Source.zip`: allowlisted project source/docs/examples/scripts/gateway/synthetic evidence; no `.build`, Git state, user library or credentials.
- `dist/SHA256SUMS`: archive checksums.
- `verification/build-manifest.json`: dated configuration/signature/source/binary/archive hashes.
- `verification/distribution-validation.json`: mechanical packaging, catalog, handbook and contrast checks.

The README uses locally generated SVG badges linked to actual local artifacts or evidence. There is no fake GitHub release, CI, App Store, Apple-approved or HIG-certified badge. A public link needs real hosting, which is intentionally not configured.

## Reproduce the developer checks

```sh
bash scripts/test.sh
bash scripts/validate-store.sh
node --test gateway/test/*.test.mjs
bash scripts/validate-messenger.sh
bash scripts/validate-model.sh
swift run --package-path examples/EngineClient
bash scripts/generate-reference.sh
python3 scripts/render-handbook.py
bash scripts/build-app.sh release
python3 scripts/validate-distribution.py
```

Run from the package root. The model command requires eligible, ready Apple Intelligence. The store harness uses a temporary library, not the user's data. The external example uses the exported `WorkflowCore` product.

`render-handbook.py` uses the Python Markdown package pinned in `scripts/requirements-docs.txt`. Generated HTML is retained in the source snapshot. Normal app packaging needs Python 3 for validation/provenance but uses already-rendered HTML, so it does not install Python packages or fetch assets. A freshness check rejects stale Markdown/reference/HTML inputs.

## Default signing

`build-app.sh` defaults to `STUDIO_SIGNING_IDENTITY=-` (ad hoc) and enables hardened runtime. It verifies the bundle strictly, copies current handbook/privacy assets, makes ZIPs and hashes. It does not submit to Apple or publish. Ad hoc integrity verification is not Developer ID trust, notarization or a successful clean-machine Gatekeeper installation.

Full Xcode is recommended for a distribution workflow. Command Line Tools successfully built this local app but are not a substitute for account/certificate/entitlement/device checks.

## Direct public distribution, when selected

Apple documents Developer ID Application signing, hardened runtime, secure timestamps and notarization for direct distribution. [Notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [distribution preparation](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) are the authority.

Configure a real installed identity and a notarytool Keychain profile yourself. Credentials must not enter source files, shell history examples, README, archives or logs. The script reads profile/identity names, not pasted Apple passwords.

```sh
STUDIO_SIGNING_IDENTITY='Developer ID Application: Your Verified Organization (TEAMID)' \
STUDIO_NOTARY_PROFILE='your-existing-keychain-profile' \
bash scripts/build-app.sh release
```

These are illustrative identity/profile values, not working credentials. When a profile is explicitly supplied, the script signs with a timestamp, submits the app ZIP, requires an Accepted result, staples/validates the ticket, rebuilds the ZIP to include it, then records checksums. Do not supply a profile unless uploading the app to Apple's service is intended.

Afterward assess the exact deliverable on a clean machine using current Gatekeeper behavior, check the offline help/type association/first-launch permissions, and publish only the verified artifact. A notarization ticket is not App Review, a design approval or a malware-proof guarantee.

## Mac App Store path

The current app is not sandboxed, provisioned or submitted. Apple requires App Sandbox for that channel. A sandboxed edition must redesign arbitrary path access around user grants/security-scoped resources and test CLI/system integration. Register capabilities and targets through a valid Apple development setup; use least-privilege entitlements. Do not add broad exceptions or disable library validation/JIT protections to pass a superficial checklist.

Also complete accurate store metadata, privacy answers, support/privacy URLs, appropriate assets/localizations, App Review notes and ownership/license checks. Confirm originality and actual functionality. Review remains Apple's decision. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) and the [standards audit](APPLE_STANDARDS_AUDIT.md) enumerate applicability.

## Version and API discipline

Info.plist is the packaged app's version source; the About panel reads it. Public library/API changes need migration/compatibility notes. `.studio` file version and library schema version do not automatically track the product version. New optional fields need old-fixture tests; new required fields/formats need explicit migration and preserved bytes.

The generated catalog and tagged-value samples reflect actual Swift code. The standards audit must not promote a successful build or contrast calculation to complete accessibility compliance. Static badges should link to dated evidence and should be updated after checks, not used as perpetual CI claims.

## Before handing over

1. Preserve the user's local edits/data and exclude them from artifacts.
2. Run core/store/model/example checks as relevant; record failures as failures.
3. Update reference, handbook, source map, privacy/capability inventory and Android proposal status.
4. Verify Markdown/HTML internal links, bundled assets and rendered critical layouts.
5. Verify signature/runtime flags and matching archive/binary/source hashes.
6. Distinguish user confirmation from agent-observed page/app behavior.
7. Record outstanding manual/Apple-account/device gates.
8. Leave the native app usable with demonstration automations disabled unless the owner enabled them.

### Build while the application is running

The packager creates and signs a separate staged bundle. It moves the previous generated app into `.build/app-stage.*` before installing the replacement, retaining mapped executable inodes instead of overwriting them. Earlier in-place executable copying caused confirmed macOS Invalid Page code-signature kills. Staging directories are excluded from source downloads. Clean them only after the old app process has exited. The running process uses its already-loaded version until deliberately restarted; installing a new artifact is not an automatic process reload.
