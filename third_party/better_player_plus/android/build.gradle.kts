plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

group = "uz.shs.better_player_plus"
version = "1.4.1"

val lifecycleVersion = "2.9.4"
val annotationVersion = "1.9.1"
val media3Version = "1.11.0"
val workVersion = "2.10.5"

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

android {
    namespace = "uz.shs.better_player_plus"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets["main"].java.srcDirs("src/main/kotlin")
}

// Whoever applies Kotlin (this file on AGP < 9, AGP 9's built-in Kotlin, or
// kotlin-android when the host app sets android.builtInKotlin=false), pin its
// JVM target to the Java one above: otherwise it follows the build JDK (21 for
// AGP 9's lint) and fails "Inconsistent JVM-target compatibility".
afterEvaluate {
    extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java)?.apply {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

dependencies {
    implementation("androidx.media:media:1.7.1")

    implementation("androidx.media3:media3-ui:$media3Version")
    implementation("androidx.media3:media3-exoplayer:$media3Version")
    implementation("androidx.media3:media3-exoplayer-hls:$media3Version")
    implementation("androidx.media3:media3-exoplayer-dash:$media3Version")
    implementation("androidx.media3:media3-exoplayer-smoothstreaming:$media3Version")

    implementation("androidx.lifecycle:lifecycle-runtime-ktx:$lifecycleVersion")
    implementation("androidx.lifecycle:lifecycle-common:$lifecycleVersion")

    implementation("androidx.annotation:annotation:$annotationVersion")
    implementation("androidx.work:work-runtime:$workVersion")
}
