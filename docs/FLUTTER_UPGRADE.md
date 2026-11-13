# Flutter / Android toolchain upgrades

The Flutter version is pinned in two places that must move together:
`.devcontainer/Dockerfile` (`git clone -b <version>`) and every
`flutter-version:` in `.github/workflows/*.yml`. CI never follows `stable`
on its own: a new stable that needed a migration broke the v1.8.2 tag
(Flutter 3.50 landed between two releases and every Android build failed).

## Current: Flutter 3.50.0 (November 2026)

| | Before | Now | Why |
|---|---|---|---|
| Flutter | 3.47.1 | 3.50.0 | |
| Gradle wrapper | 8.14.2 | 9.5.0 | Flutter 3.50 refuses < 9.3.1 |
| Android Gradle Plugin | 8.11.1 | 9.3.1 | Flutter 3.50 refuses < 9.1.1 |
| Kotlin Gradle Plugin | 2.3.20 | 2.4.20 | Flutter 3.50 refuses < 2.4.10 |
| JDK (devcontainer, CI) | 17 | 21 | AGP 9.3 lint calls Java 21 APIs |

Bytecode targets stay at Java/Kotlin 17 (`compileOptions`, `jvmTarget`).

### Changes this needed

- **`profile` build type**: Flutter copies the app's build types into every
  plugin project (`initWith`), and AGP 9 rejects `applicationIdSuffix` on a
  library. The `.profile` id and `-profile` version suffixes moved to
  `androidComponents.onVariants` in `android/app/build.gradle.kts`.
- **better_player_plus fork**: on AGP ≥ 9 its Kotlin JVM target was left
  unset, so it followed JDK 21 and clashed with Java 17. Now pinned whenever
  the Kotlin extension exists.
- **JDK 21**: without it `lintVitalAnalyzeRelease` crashes
  (`NoSuchMethodError: List.removeLast()`). CI jobs that run Gradle use
  `actions/setup-java` with Temurin 21.

### Still pending

- **`package:material_ui`**: Flutter 3.50 deprecates
  `package:flutter/material.dart` in favour of the `material_ui` pub package.
  It is a separate copy of the library, not a re-export: its `Theme`,
  `ThemeData` and `MaterialLocalizations` are different classes from the
  framework's. Dependencies that still import `flutter/material.dart` (the
  better_player fork and others) would then need the temporary
  `MaterialUiCompatibilityBridge` (itself deprecated) to find the app's theme.
  Until that migration is done and tested on devices, each import carries
  `// ignore: deprecated_member_use` (140 files): search for
  "material_ui migration pending".
- **Built-in Kotlin**: Flutter warns that applying the Kotlin Gradle Plugin
  in the app "will cause build failures in future versions". The switch is
  `android.builtInKotlin=true` in `android/gradle.properties`, but it applies
  to every plugin project too, and plugins that still apply `kotlin-android`
  break with it. Check plugin compatibility first:
  https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
- **Major package updates** left out (API changes): go_router 18,
  media_kit_video 2, cached_network_image 4, equatable 3, window_manager 0.7,
  better_player_plus 2 (we run a fork of 1.4.1).

## Next time

1. Download the new SDK in the devcontainer next to the pinned one and run
   `flutter analyze`, `flutter test` and the release builds with it
   (`flutter build apk --flavor tv`, `appbundle --flavor mobile`, `web`,
   `linux`).
2. Read the minimum versions in
   `packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt`
   (`errorGradleVersion`, `errorAGPVersion`, `errorKGPVersion`).
3. Move the Dockerfile and the workflow pins in the same commit, and
   rebuild the devcontainer.
