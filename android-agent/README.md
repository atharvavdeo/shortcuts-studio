# Studio Agent for Android — first native foundation

This project is separate from the Swift Mac application. The Android app is under construction; no APK or Android inference has been verified yet.

Read [the source investigation](../research/android-first/GALLERY_SOURCE_INVESTIGATION.md) and [resource contract](policy/RESOURCE_CONTRACT.md) first.

## Implemented source

- `core`: deterministic command routing, resource admission decisions, single inference lease.
- `app`: Compose command screen and read-only model catalogue; status, opening Wi-Fi settings and HTTPS URLs through Android intents.
- LiteRT-LM Android dependency pinned to 0.18.0. No model adapter/worker is active yet.

No app-control permission, model license or OS authorization is granted automatically. The manifest currently requests no permissions. The app has no model downloader or background service. Models stay disabled. Memory gates are code, not yet a device-enforced physical RAM ceiling. The canonical catalogue is generated into app assets from the research JSON during the Android build.

## Build the Kotlin core

Java 21 is required. On this Mac:

```sh
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
./gradlew :core:compileKotlin --no-daemon
```

This compiles production source; it does not run tests or execute models.

## Build the native Android application

The owner is installing Android Studio and accepting the Android SDK license themselves. In SDK Manager install Android SDK Platform 37 and the requested build tools. Set `sdk.dir` in an untracked `local.properties`, or set `ANDROID_HOME` to the SDK path.

```sh
./gradlew -Pandroid=true :app:assembleDebug --no-daemon
```

Expected output after a successful build: `app/build/outputs/apk/debug/app-debug.apk`. This is an expected path, not a currently delivered APK. Enable USB debugging and authorize this Mac yourself before any device installation.

## Current boundaries

Unknown free-form commands return an explicit unavailable message. There are no simulated product offers, generated answers or delivery claims. Model downloads, streaming, the isolated worker, native allocation accounting, notifications, Accessibility app execution, OCR, shopping extraction and Mac routing are not implemented in this native slice.

The next implementation gate is the native worker/supervisor plus a qualifying allocation-accounted backend. A valid model-family name or a compact download is insufficient to enable inference under the agreed memory contract.
