package com.lotho33.pileus

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Picture-in-picture for the phone app: leaving Pileus while a video plays
 * (home gesture/button) keeps it playing in a small window. Dart says when
 * that's wanted (setEligible — a video is playing) and hears when the window
 * opens or closes (pipChanged), to hide the player controls inside it.
 *
 * The window carries −10 s, play/pause and +10 s buttons, as YouTube's:
 * each press is a broadcast back to this app, handed to Dart as
 * pipAction("rewind" | "toggle" | "forward"). [playing] picks the middle
 * icon.
 *
 * Android 12+: the system enters PiP by itself (auto-enter). Android 8–11:
 * onUserLeaveHint does it. Mobile flavor only — the TV build has a no-op twin.
 */
object Pip {
    private const val CHANNEL = "pileus/pip"
    private const val ACTION = "com.lotho33.pileus.PIP_ACTION"
    private const val EXTRA = "action"
    private var channel: MethodChannel? = null
    private var receiver: BroadcastReceiver? = null
    private var eligible = false
    private var playing = true
    private var aspect = Rational(16, 9)

    fun register(engine: FlutterEngine, activity: Activity) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "setEligible" -> {
                    eligible = call.argument<Boolean>("eligible") ?: false
                    playing = call.argument<Boolean>("playing") ?: true
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
        listen(activity)
    }

    // The buttons' broadcasts, back to Dart. Not exported: only this app's
    // own PendingIntents (setPackage below) reach it.
    private fun listen(activity: Activity) {
        receiver?.let { runCatching { activity.unregisterReceiver(it) } }
        val r = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val a = intent.getStringExtra(EXTRA) ?: return
                channel?.invokeMethod("pipAction", a)
            }
        }
        val filter = IntentFilter(ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            activity.registerReceiver(r, filter)
        }
        receiver = r
    }

    fun onUserLeaveHint(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (!eligible || !supported(activity)) return
        // Android 12+ enters on its own (setAutoEnterEnabled below).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        try {
            activity.enterPictureInPictureMode(params(activity))
        } catch (_: Throwable) {
        }
    }

    fun onModeChanged(inPip: Boolean) {
        channel?.invokeMethod("pipChanged", inPip)
    }

    // Kept current even before Android 12 (no auto-enter there): the
    // buttons of an open window follow play/pause.
    private fun apply(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !supported(activity)) return
        try {
            activity.setPictureInPictureParams(params(activity))
        } catch (_: Throwable) {
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun params(context: Context): PictureInPictureParams {
        val b = PictureInPictureParams.Builder()
            .setAspectRatio(aspect)
            .setActions(actions(context))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            b.setAutoEnterEnabled(eligible).setSeamlessResizeEnabled(true)
        }
        return b.build()
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun actions(context: Context): List<RemoteAction> = listOf(
        action(context, "rewind", android.R.drawable.ic_media_rew, "Indietro 10 secondi", 1),
        if (playing) {
            action(context, "toggle", android.R.drawable.ic_media_pause, "Pausa", 2)
        } else {
            action(context, "toggle", android.R.drawable.ic_media_play, "Riproduci", 2)
        },
        action(context, "forward", android.R.drawable.ic_media_ff, "Avanti 10 secondi", 3),
    )

    @RequiresApi(Build.VERSION_CODES.O)
    private fun action(context: Context, name: String, icon: Int, label: String, code: Int): RemoteAction {
        val intent = Intent(ACTION).setPackage(context.packageName).putExtra(EXTRA, name)
        val pi = PendingIntent.getBroadcast(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return RemoteAction(Icon.createWithResource(context, icon), label, label, pi)
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
