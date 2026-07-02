import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: reads android/key.properties when present (created by CI
// from repo secrets, or by you locally — see android/key.properties.example).
// Absent → the release build falls back to the debug keys so a local
// `flutter run --release` still works.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.lotho33.pileus"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Package id on the device — MUST stay stable forever: changing it
        // makes Android treat it as a different app (no updates over an
        // existing install). Kept in sync with `namespace` above.
        applicationId = "com.lotho33.pileus"
        // Pinned explicitly rather than riding flutter.minSdkVersion, which
        // moves with the Flutter SDK. 21 is the floor for AndroidX Media3 /
        // ExoPlayer (better_player_plus); every target TV box (Amlogic
        // S905W = API 28, Fire Stick 4K = API 30+) is well above it. Bump
        // deliberately if a dependency needs it, don't let a Flutter
        // upgrade decide.
        minSdk = flutter.minSdkVersion
        // Pinned explicit: Google Play requires targetSdk 35 for apps
        // submitted from Aug 2025 on. Bump in lockstep with a Play deadline,
        // not silently via the Flutter SDK. Must stay <= compileSdk (36).
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // The UI is Italian-only; keep just it/en framework+plugin string
        // resources (androidx / Media3 ship ~85 locales). App text is not
        // affected. On a Play AAB the language split already handles this;
        // this trims the Amazon per-ABI / universal APK.
        resourceConfigurations += listOf("en", "it")
        // ABI restriction is done via `flutter build ... --target-platform
        // android-arm,android-arm64` (see the CI workflow / RELEASE.md), NOT
        // via `ndk { abiFilters }` here: an abiFilters block in defaultConfig
        // conflicts with the per-ABI splits that `--split-per-abi` turns on
        // ("Conflicting configuration ... splits abi filters are set").
    }

    // Two shipping apps from one codebase:
    //   tv      -> Android TV / Fire TV (this repo's primary target)
    //   mobile  -> phone / tablet, a distinct store listing
    //              (applicationId com.lotho33.pileus.mobile)
    // Pick with `flutter build|run --flavor tv|mobile`. The mobile entrypoint
    // is `lib/main_mobile.dart` (`-t`); tv keeps `lib/main.dart`.
    // Flavor-specific manifest bits live in src/tv/ and src/mobile/.
    flavorDimensions += "target"
    productFlavors {
        create("tv") {
            dimension = "target"
        }
        create("mobile") {
            dimension = "target"
            applicationIdSuffix = ".mobile"
            versionNameSuffix = "-mobile"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)
                    ?.let { rootProject.file("app/$it") }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Store / CI builds must never be debug-signed — Play and
                // Amazon reject a debug-signed artifact outright. The store
                // workflow passes -PpileusRequireSigning=true, which turns
                // the otherwise-silent debug fallback into a hard failure.
                // A local `flutter run --release` with no keystore still
                // works (property absent → debug keys, as before).
                if (project.findProperty("pileusRequireSigning") == "true") {
                    throw GradleException(
                        "Release signing is required (-PpileusRequireSigning=true) but " +
                        "android/key.properties is missing. Configure the keystore " +
                        "(see RELEASE.md) — refusing to fall back to debug keys."
                    )
                }
                signingConfig = signingConfigs.getByName("debug")
            }
            // R8 code + resource shrinking. OFF by default (a mis-strip only
            // shows up at runtime); the store pipeline opts in with
            // -PpileusR8=true and must run a real playback + gRPC + SVG
            // smoke test on a device before shipping. See proguard-rules.pro.
            if (project.findProperty("pileusR8") == "true") {
                isMinifyEnabled = true
                isShrinkResources = true
                proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
                )
            }
        }
    }

    // libmpv (media_kit) is dead weight on Android — PlayerEngine.create()
    // always returns the ExoPlayer backend on Android/iOS, and
    // _MpvPlayerEngine now throws if it's ever constructed there. But the
    // media_kit_libs_android_video AAR links libmpv.so (~12.4 MB/ABI)
    // regardless. Strip it in store builds with -PpileusExcludeMpv=true
    // (kept off `flutter run` so the desktop dev loop is unaffected — that
    // uses the Linux build, not this).
    if (project.findProperty("pileusExcludeMpv") == "true") {
        packaging {
            jniLibs {
                excludes += listOf("**/libmpv.so", "**/libmediakitandroidhelper.so")
            }
        }
    }
}

// Pin Kotlin's JVM target. Without this it follows the build machine's JDK
// (17 in the devcontainer, 21 in the CI Flutter image), and a mismatch with the
// Java target in compileOptions above fails :app:compileReleaseKotlin with
// "Inconsistent JVM-target compatibility". Kotlin 2.3 removed the old
// `kotlinOptions { jvmTarget = "..." }` form — this is the compilerOptions DSL
// (https://kotl.in/u1r8ln).
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
