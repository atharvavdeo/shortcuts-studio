# Primary sources and authority

Reviewed 13 October 2026. These are primary references for guidance and public interfaces, not proof that our app passed a vendor review. Some Apple documentation requires JavaScript; available text, published documentation JSON and the installed public SDK interfaces were used. Local source/tests remain the authority for Studio behavior.

## Apple design

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/): platform design principles; apply relevant guidance by surface/platform.
- [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): input, perception and assistive interaction.
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars): command/menu access and native presentation.
- [Color](https://developer.apple.com/design/human-interface-guidelines/color): semantic and custom appearance/contrast.
- [Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards): familiar modifier/shortcut behavior.
- [Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection): visible, platform-consistent focus.
- [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons): original identity, modern layers and accepted flat artwork.
- [Icon Composer](https://developer.apple.com/icon-composer/): layered icon authoring; full asset work remains pending.

## Apple API and distribution

- [SwiftUI](https://developer.apple.com/documentation/swiftui), [AppKit](https://developer.apple.com/documentation/appkit), [Foundation](https://developer.apple.com/documentation/foundation): public frameworks used by this source.
- [Defining file/data types](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app): UTI export and JSON conformance.
- [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api): declarations must match actual use and affected platform.
- [Preparing distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution): signing, hardened runtime, sandbox applicability and metadata.
- [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution): Developer ID/timestamp/hardened runtime/notary workflow.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): accurate functionality, public APIs, originality and channel-specific review.
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels), [WWDC25 introduction](https://developer.apple.com/videos/play/wwdc2025/286/): system on-device model/session/guided generation and streaming.
- [Local-network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy): macOS identity/permission handling and Bonjour declarations.
- [NWListener](https://developer.apple.com/documentation/network/nwlistener), [TLS parameters](https://developer.apple.com/documentation/network/nwparameters/tls): proposed network transport primitives, not a complete implemented server.

The installed macOS 27 SDK declarations were inspected for FoundationModels, AppKit and file/system APIs. The CLT SDK was not modified. Swift code snippets either correspond to actual implementation or are clearly labeled insertion/example/proposal code.

## Apple Shortcuts comparison

- [CLI execution](https://support.apple.com/guide/shortcuts-mac/apd455c82f02/mac): supported bridge and prompt behavior.
- [Variables](https://support.apple.com/guide/shortcuts-mac/apdb5506f698/mac): Apple's richer value/content model.
- [Sync](https://support.apple.com/guide/shortcuts-mac/apdb3a4240b0/mac): documented cross-device iCloud synchronization.
- [Intelligent actions on iPhone/iPad](https://support.apple.com/guide/shortcuts/use-apple-intelligence-in-shortcuts-tpg3vrvwmclv/ios): Apple's model capabilities; availability is platform/version dependent.

These sources establish feature context. No matched benchmark or original-app usability study was performed.

## Android proposal

- [Local network permission](https://developer.android.com/privacy-and-security/local-network-permission): Android 16 opt-in/Android 17 target SDK 37 enforcement and user-mediated NSD alternatives; recheck before implementation.
- [Android Keystore](https://developer.android.com/privacy-and-security/keystore): device credential/key storage.
- [Network security configuration](https://developer.android.com/privacy-and-security/security-config): transport trust policy; do not globally bypass TLS.
- [BLE background communication](https://developer.android.com/develop/connectivity/bluetooth/ble/background): constraints if BLE/companion services are adopted; not a Wi-Fi exemption.

## Research lineage

The initial investigation referenced [REA source](https://github.com/morluto/rea) and [REA site](https://rea.tools/). The existing sibling research dossiers document that earlier investigation. REA is not linked or vendored into the current app, and this handbook does not claim its license grants rights to our source or Apple's assets. Pages, Keynote, Numbers and Image Playground research is separate from implemented Studio integration.

## Refresh policy

Recheck platform guidance when the OS/SDK/target SDK, distribution channel, data use, third-party dependencies or remote protocol changes. Record the retrieval date and relevant test artifact. A source URL in this list is not an Apple/Google endorsement of Shortcut Studio.

## Messenger notification references

- [Android notification permission](https://developer.android.com/develop/ui/views/notifications/notification-permission): Android 13+ ordinary notification permission and denial behavior.
- [Firebase message types](https://firebase.google.com/docs/cloud-messaging/customize-messages/set-message-type): notification/data message behavior; push service is an implementation candidate.
- [Firebase payload encryption](https://firebase.google.com/docs/cloud-messaging/encryption): transport protection alone does not supply application end-to-end encryption.
- [URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask): candidate outbound Mac transport primitive, not a complete gateway.
