package com.lotho33.pileus

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "pileus/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getProfile" -> result.success(deviceProfile())
                    else -> result.notImplemented()
                }
            }
    }

    // Coarse hardware description for main.dart's weak-device auto-detect
    // (auto-enables "hardware modesto" on boxes that can't sustain 1080p
    // video + Flutter compositing — Amlogic S905W/X etc.). Everything here
    // is best-effort: any field may come back null/0.
    private fun deviceProfile(): Map<String, Any?> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val mem = ActivityManager.MemoryInfo()
        am?.getMemoryInfo(mem)
        val totalRamMb = if (mem.totalMem > 0) (mem.totalMem / (1024 * 1024)).toInt() else 0

        return mapOf(
            "hardware" to safe { Build.HARDWARE },
            "board" to safe { Build.BOARD },
            "socModel" to safe {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) Build.SOC_MODEL else null
            },
            "boardPlatform" to safe { systemProp("ro.board.platform") },
            "totalRamMb" to totalRamMb,
            "isLowRamDevice" to (am?.isLowRamDevice ?: false),
            "isTv" to isTv(),
        )
    }

    // Real device-class check (TV box vs. phone/tablet), not just "is
    // Android" — main.dart uses this to decide whether the system density
    // already normalizes the logical canvas (true on TV firmware only) or
    // whether it needs the same readability text-scale boost desktop/web
    // get. FEATURE_LEANBACK is Google's own recommended Android TV check
    // (also what Amazon's Fire TV declares); UiModeManager is queried too as
    // a backstop for a launcher/ROM that skips the feature flag.
    private fun isTv(): Boolean {
        val leanback = try {
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        } catch (_: Throwable) {
            false
        }
        val uiMode = try {
            val um = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            um?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        } catch (_: Throwable) {
            false
        }
        return leanback || uiMode
    }

    private inline fun <T> safe(block: () -> T): T? = try {
        block()
    } catch (_: Throwable) {
        null
    }

    // ro.* props aren't in the public API; read them via the hidden
    // android.os.SystemProperties by reflection. Returns "" on any failure.
    private fun systemProp(key: String): String {
        return try {
            val cls = Class.forName("android.os.SystemProperties")
            val get = cls.getMethod("get", String::class.java)
            (get.invoke(null, key) as? String) ?: ""
        } catch (_: Throwable) {
            ""
        }
    }
}
