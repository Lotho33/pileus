package com.lotho33.pileus

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-picture for the phone app: leaving Pileus while a video plays
 * (home gesture/button) keeps it playing in a small window. Dart says when
 * that's wanted (setEligible — a video is playing) and hears when the window
 * opens or closes (pipChanged), to hide the player controls inside it.
 *
 * Android 12+: the system enters PiP by itself (auto-enter). Android 8–11:
 * onUserLeaveHint does it. Mobile flavor only — the TV build has a no-op twin.
 */
object Pip {
    private const val CHANNEL = "pileus/pip"
    private var channel: MethodChannel? = null
    private var eligible = false
    private var aspect = Rational(16, 9)

    fun register(engine: FlutterEngine, activity: Activity) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEligible" -> {
                    eligible = call.argument<Boolean>("eligible") ?: false
                    val w = call.argument<Int>("width") ?: 16
                    val h = call.argument<Int>("height") ?: 9
                    aspect = clamp(w, h)
                    apply(activity)
                    result.success(supported(activity))
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    fun onUserLeaveHint(activity: Activity) {
        if (!eligible || !supported(activity)) return
        // Android 12+ enters on its own (setAutoEnterEnabled below).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        try {
            activity.enterPictureInPictureMode(params())
        } catch (_: Throwable) {
        }
    }

    fun onModeChanged(inPip: Boolean) {
        channel?.invokeMethod("pipChanged", inPip)
    }

    private fun apply(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || !supported(activity)) return
        try {
            activity.setPictureInPictureParams(params())
        } catch (_: Throwable) {
        }
    }

    private fun params(): PictureInPictureParams {
        val b = PictureInPictureParams.Builder().setAspectRatio(aspect)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setAutoEnterEnabled(eligible).setSeamlessResizeEnabled(true)
        }
        return b.build()
    }

    private fun supported(activity: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    // The system refuses ratios outside 1:2.39 … 2.39:1.
    private fun clamp(w: Int, h: Int): Rational {
        if (w <= 0 || h <= 0) return Rational(16, 9)
        val r = w.toDouble() / h
        return when {
            r > 2.39 -> Rational(239, 100)
            r < 1 / 2.39 -> Rational(100, 239)
            else -> Rational(w, h)
        }
    }
}
