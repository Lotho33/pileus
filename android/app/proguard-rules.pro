# Applied only when built with -PpileusR8=true (see build.gradle.kts).
# Media3/ExoPlayer, gRPC, protobuf and better_player_plus all ship their own
# consumer rules; these are belt-and-suspenders keeps for the reflective
# entry points R8 has historically over-stripped.

# ── Flutter embedding ──────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── better_player_plus / AndroidX Media3 (ExoPlayer) ───────────────────────
-keep class uz.shs.better_player_plus.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
# Cronet data source is referenced reflectively and is optional.
-dontwarn org.chromium.net.**
-dontwarn com.google.android.gms.net.**

# ── gRPC + OkHttp/Okio (grpc-dart uses the native stack, but plugins may) ──
-keep class io.grpc.** { *; }
-dontwarn io.grpc.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ── protobuf ──────────────────────────────────────────────────────────────
-keep class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
  <fields>;
}
-dontwarn com.google.protobuf.**

# ── androidx.work (pulled by better_player_plus) ──────────────────────────
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# ── flutter_svg / vector_graphics ────────────────────────────────────────
-dontwarn com.caverock.androidsvg.**

# Keep annotations & enums used via reflection.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepclassmembers enum * { *; }

# Parcelables.
-keepclassmembers class * implements android.os.Parcelable {
  public static final ** CREATOR;
}
