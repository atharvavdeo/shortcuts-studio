# Shortcut Studio handbook

**Version 0.6.0 · reviewed 14 October 2026 · macOS implementation**

This handbook is for people running workflows, developers extending the Swift implementation, and contributors planning the Android companion. It documents the current implementation, its construction, the platform APIs it calls, and the checks needed to distribute it responsibly.

The current app has 67 action definitions, an independent interpreter, native macOS controls, local persistence, six automation triggers, and Apple on-device model integration. Apple Shortcuts delegation is optional. Android Chrome command delivery is implemented through a test messenger gateway; native Android remains future work. Neither this handbook nor a successful build certifies Apple approval, complete HIG conformity, or one-to-one Shortcuts parity.

## Read in this order

| Reader | Start here | Continue |
|---|---|---|
| New user | [User guide](USER_GUIDE.md) | [Action reference](ACTION_REFERENCE.md), [privacy and security](PRIVACY_AND_SECURITY.md) |
| Swift developer | [Developer guide](DEVELOPER_GUIDE.md) | [Swift API reference](SWIFT_API_REFERENCE.md), [system construction](SYSTEM_CONSTRUCTION.md) |
| Designer / release owner | [Apple standards audit](APPLE_STANDARDS_AUDIT.md) | [Release guide](RELEASE_GUIDE.md), [verification](../VERIFICATION.md) |
| Deployment/framework contributor | [Cloudflare setup framework](CLOUDFLARE_FRAMEWORK.md) | [Messenger guide](MESSENGER_GUIDE.md) |
| Phone user | [Create and run phone shortcuts](PHONE_AUTHORING.md) | [Messenger setup and use](MESSENGER_GUIDE.md), [Android scope](ANDROID_SCOPE.md) |
| Android contributor | [Android scope and evaluation](ANDROID_SCOPE.md) | [proposed command protocol](REMOTE_PROTOCOL_PROPOSAL.md) |
| Product reviewer | [Comparison with Apple Shortcuts](COMPARISON.md) | [standards audit](APPLE_STANDARDS_AUDIT.md), verification evidence |

## Three distinct execution paths

1. **Independent actions:** a typed Swift interpreter resolves references, validates blocks, and performs an action through the core or macOS host.
2. **Apple bridge:** the host spawns Apple's supported `shortcuts` CLI. Apple executes the delegated workflow; Studio handles bounded input/output and cancellation of the CLI process.
3. **On-device model:** a fresh `LanguageModelSession` uses `SystemLanguageModel.default`. Text snapshots stream; authoring uses two structured requests. The interpreter executes accepted actions. No automatic cloud fallback is configured.

## Distribution and help

- [Local app ZIP](../dist/Shortcut-Studio-macOS.zip): unzip and open the native app on this Mac.
- [Local source ZIP](../dist/Shortcut-Studio-Source.zip): source, examples, scripts, documentation, and synthetic verification fixtures.
- The packaged app's **Help → Shortcut Studio Handbook** opens an offline HTML edition.
- Online download hosting is intentionally not configured. These links are local files, not public release URLs.

The current local package uses an ad hoc signature with hardened runtime. Developer ID signing and notarization are separate release steps. The project has no selected public source license; this handbook describes implementation and does not assign a license.

## Evidence hierarchy

Source defines behavior. Automated tests establish their named cases. Native UI observations establish their specific interactions. A user's confirmation is identified as such. Apple and Android documentation establish platform guidance. Proposed architecture and estimates are explicitly marked as proposals. A green badge is a dated summary, not continuous CI or approval by Apple.

## Maintenance

Update this handbook when behavior changes. Regenerate the catalog with `bash scripts/generate-reference.sh`; render the offline edition with `python3 scripts/render-handbook.py`; run the applicable checks before packaging. [Sources](SOURCES.md) records primary references. [Release guide](RELEASE_GUIDE.md) explains the verification and packaging scripts.

## Mac assistant upgrade

See [files, model controls, app results and permanent connection setup](MAC_ASSISTANT_UPGRADE.md) for version 0.5.0 capabilities and limits.

## Hosted gateway

[Stable hosted URL, migration, deployment and evidence](HOSTED_GATEWAY.md).
