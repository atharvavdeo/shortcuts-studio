# Build evidence — 2026-10-15

## Completed

Command, from `android-agent/`:

```sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home ./gradlew :core:compileKotlin --no-daemon
```

Final result: **BUILD SUCCESSFUL**, 14 seconds, one task executed. This was repeated after adding exact runtime/profile identity matching. Kotlin core production sources compiled with Java 21 and Kotlin 2.2.21. No tests were added or run. No model was loaded.

Gradle 9.2.1 distribution SHA-256, enforced by the wrapper:
`72f44c9f8ebcb1af43838f45ee5c4aa9c5444898b3468ab3f4af7b6076c5bc3f`

Copied wrapper JAR SHA-256:
`238e777fcddd7e34f9708186085def2abd6e08e658505b38718d79d74c21abd5`

## Pending

- Android SDK was absent at inspection. The owner chose to install it through Android Studio and accept Google's SDK license themselves.
- The Compose application has **not** compiled yet; core compilation does not prove Android build compatibility.
- No APK, device installation, Android inference, physical RAM-cap enforcement, notification control or third-party app journey is verified.
- Native inference worker, supervisor, telemetry and allocation-accounted backend integration remain implementation work. The admission governor and lease are independent core components, not a running resource manager.

The original Mac app was not rebuilt, launched or modified during this pass. No OS or device permissions were granted.
