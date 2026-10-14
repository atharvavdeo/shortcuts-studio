# Apple design and platform standards audit

**Scope:** Shortcut Studio 0.1.1, native macOS local distribution. Reviewed against primary Apple guidance on 13 October 2026. HIG recommendations, API contracts, distribution requirements and App Review rules have different applicability. There is no single automated test that certifies “all Apple standards.”

## Status terms

- **Implemented:** a concrete source/bundle change exists.
- **Checked locally:** a named automated or native observation supports the specified case.
- **Pending:** manual/device/account/distribution evidence still required.
- **Future feature:** no implementation; requirements become applicable when built.

## Design and accessibility

| Area | Current evidence | Remaining work |
|---|---|---|
| Native window/navigation | WindowGroup, NavigationSplitView, AppKit title bar, native sidebar | Multiple-scene ownership and more screen configurations |
| Narrow windows | 900×640 minimum; compact shortcut picker when detail width cannot fit library + editor | Resize/locale/large-text matrix; do not equate one host with universal fit |
| Native controls | Buttons, menu/pickers, forms, file panels, sheets and text editors | Full interaction review and focus order with assistive input |
| Keyboard selection | Library cards are Buttons; command menus; non-drag action movement | Full Keyboard Access and VoiceOver sweep on actual devices |
| Toolbar/menu parity | New/Import/Export and Describe are menu commands; Help menu opens handbook | Native toolbar customization may be expanded |
| Accessible names | Import/export/new/favorite/duplicate/output/reference/action controls labeled; selected cards announce state | VoiceOver/Switch Control/Voice Control validation remains pending |
| Status beyond color | Text status, active spinner, completed icon and labels | Screen-reader announcements of rapidly streaming changes |
| Appearance | Semantic native backgrounds; no custom toolbar backdrop | Light/dark/increased-contrast/reduced-transparency visual matrix |
| Custom tile contrast | Opaque sRGB palette and white labels; arithmetic ratio checked in artifact validator | Actual rendered pixels/font sizes/focus borders and increased-contrast review |
| Motion | Reduce Motion disables custom scroll/scale/expand transitions | Real preference/device validation; no fake runtime delays |
| Typography | System text styles and native editors; some fixed-size code labels | Large-text/localization/layout testing; not an iOS Dynamic Type claim |
| Drag alternatives | Options menus move/duplicate/remove complete blocks | Keyboard reorder discoverability can be improved |
| Errors/recovery | Native error alerts, save/recovery banners, preserved corruption, Cancel/Stop | Exhaustive denial/cancel/shutdown/low-disk paths |
| Help/discoverability | Bundled offline handbook; visible generation examples and typed input | Localization and onboarding studies |
| Original branding | Independent name, original connected-node mark; no Apple app icon artwork or approval badge | Layered icon variants in full Xcode/Icon Composer; flattened icon is the current asset |

Guidance: [HIG](https://developer.apple.com/design/human-interface-guidelines/), [accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [color](https://developer.apple.com/design/human-interface-guidelines/color), [keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards), [focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection), [app icons](https://developer.apple.com/design/human-interface-guidelines/app-icons).

This table maps our implementation to the guidance. It does not claim Apple performed a design review. Flat icons remain a supported design option; modern layered appearance work is documented as pending, not simulated as a system effect.

## Bundle and public API protocols

| Contract | Status |
|---|---|
| Distinct bundle ID, executable/name/version/minimum OS/icon | Implemented and mechanically checked |
| `.studio` ownership / JSON conformance | Exported UTI + LSItemContentTypes; typed native panels implemented |
| File-open lifecycle | Application delegate forwards URLs into validated import; busy imports are not queued |
| Public frameworks only | SwiftUI/AppKit/Foundation/AVFAudio/UserNotifications/UniformTypeIdentifiers/FoundationModels; no private Apple engine API |
| Model availability | macOS 26 gate and eligibility/enabled/readiness states; actual live calls checked |
| Parameter/result contracts | Typed core; strict reference/model draft validation; versioned library/export |
| Async cancellation | Task checks, sheet cancel, speech stop, bounded CLI task; side effects not rolled back |
| MainActor/UI ownership | Explicitly isolated store/host/engine; synchronous blocking work is a known limitation |
| Permissions | Notification authorization on use; local network purpose text; Apple bridge delegates Apple's permissions |
| ATS | No global arbitrary-load exemption; HTTP can fail under system transport policy |
| Privacy manifest | Bundled no-tracking/no-developer-collection declaration; no unsubstantiated required-reason codes |
| Local secrets | No remote pairing credentials exist yet; workflow values/history are plaintext local data |
| Logging/data minimization | Bounded local logs/history; no analytics uploader; workflow content can still be personal |

The current source uses file-size resource values, not direct file-timestamp/boot-time/UserDefaults reason APIs. Audit again when those APIs or third-party SDKs are introduced. Apple's required-reason documentation specifies affected platform categories; do not generalize every iOS App Store rule to this direct macOS build. [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [required-reason description](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), and [formal file types](https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app) are the reference points.

## Distribution channels and release gates

| Channel | Requirement / current status |
|---|---|
| This local build | Ad hoc signature + hardened runtime and strict signature check; app has been launched locally |
| Public direct download | Developer ID Application identity, hardened runtime, secure timestamp, accepted notarization, stapled ticket, Gatekeeper assessment; account/hardware checks pending |
| Mac App Store | Sandbox plus appropriate entitlements, store metadata/privacy answers, assets and App Review; not configured/submitted |
| Shared public source | License/ownership choice and actual release hosting; both unconfigured by the owner's current local-download decision |

[Preparing distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) distinguishes optional sandboxing for direct notarized distribution from the App Store sandbox requirement. [Notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) describes signing/hardened runtime/timestamp/ticket requirements. Notarization is not App Review.

Do not enable sandboxing as a metadata-only “compliance” change. The app currently reads explicitly authored paths and invokes a system CLI. A sandboxed edition needs security-scoped resource design, entitlement review and actual compatibility testing; those can change its functionality.

## Originality and policy

Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) include accurate functionality/metadata, public API use and copycat/impersonation rules. Familiar workflow concepts and native controls should coexist with distinct branding and honest capability descriptions. This app is not an Apple product and must not use an “Apple approved,” App Store, or full-parity badge without evidence. No App Review outcome is guaranteed by this audit.

## Manual acceptance checklist

Before a public release, record device/OS/build and result for:

1. Keyboard-only library/editor/forms/menu/dialog navigation; visible focus and no traps.
2. VoiceOver names, order, selection, disabled controls, errors and live progress; avoid continuous verbose speech from every snapshot.
3. Switch Control/Voice Control operation without drag gestures.
4. Light/dark, Increase Contrast, Reduce Motion, Reduce Transparency, text enlargement, smaller displays and long/localized labels.
5. Open/Save Cancel, permissions denied/revoked, app missing, unsupported model, network/ATS failure, file-size/encoding/low-disk failure.
6. Closing every window, reopen, quitting during running tasks, recovery after interruption, multiple windows and sleep/wake.
7. File association from Finder; only `.studio` documents claim this app; native Apple documents still route to Apple.
8. Developer ID signatures, accepted notarization, ticket validation, clean-machine Gatekeeper install and first launch.
9. Sandboxed capabilities and App Review requirements only if that channel is selected.
10. Android permission/pairing/revocation/transport tests only after the proposed companion is implemented.

**Current conclusion:** applicable local improvements and a compliance process are implemented; universal end-to-end Apple compliance is **not established**. External distribution and manual accessibility gates are explicit outstanding work.

## 0.3.0 Accessibility-based app control

The optional approved app-control action uses public ApplicationServices AXUIElement APIs and targeted Unicode keyboard events. AX trust is checked; the user must enable the app in macOS privacy settings. On this host's macOS 27, the visible permission panel is Device Control and Data Access. Native assistive Accessibility preferences and Files & Folders are separate. Desktop filename access uses its own macOS filesystem privacy decision. Broad compatibility with arbitrary third-party app accessibility trees is not established.

## Liquid Glass adoption — 14 October 2026

The native Mac control layer now uses real SwiftUI APIs: `.glass`, `.glassProminent`, `GlassEffectContainer`, and `.glassEffect(.regular.interactive(), in: .circle)`. The editor groups Favorite, Duplicate and Run/Stop; the output toggle uses a custom circular glass surface. Messenger Done/Connect/Pairing and New Automation use native glass button styles. The system toolbar and sidebar retain standard SwiftUI behavior. Workflow tiles, action cards, text editors and output bodies retain standard content surfaces.

`StudioGlass.swift` gates APIs at macOS 26. Reduced Transparency or Increased Contrast selects bordered opaque controls; earlier macOS uses the same fallback. No new custom animation loop or model calls were added. Existing labels and disabled states remain. Release compilation, packaging checks, live launch and the default dark editor were inspected. Light appearance, accessibility settings on actual hardware, older OS runtime and Instruments rendering costs were not separately measured. This adoption does not certify complete HIG compliance.

References: [custom Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [HIG materials](https://developer.apple.com/design/human-interface-guidelines/materials).
