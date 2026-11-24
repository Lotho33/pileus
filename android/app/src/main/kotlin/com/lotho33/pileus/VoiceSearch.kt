package com.lotho33.pileus

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Voice search through the system's own recognizer (RecognizerIntent): its
 * dialog listens — on a TV, through the remote's microphone — and hands back
 * the text. Pileus never records audio itself, so it needs no microphone
 * permission. Devices without a recognizer (some Fire TV) say
 * `available = false` and the app shows no microphone button.
 */
object VoiceSearch {
    private const val REQUEST = 0x5650 // "VP"
    private var pending: MethodChannel.Result? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "pileus/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(intent(null).resolveActivity(activity.packageManager) != null)
                    "listen" -> listen(activity, call.argument<String>("prompt"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun intent(prompt: String?) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        if (prompt != null) putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
    }

    private fun listen(activity: Activity, prompt: String?, result: MethodChannel.Result) {
        // A second request while the dialog is up: the first one gets nothing.
        pending?.success(null)
        pending = result
        try {
            activity.startActivityForResult(intent(prompt), REQUEST)
        } catch (_: Throwable) {
            pending = null
            result.success(null)
        }
    }

    /** True when it was ours. The text, or null when cancelled/nothing heard. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val text = if (resultCode == Activity.RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else {
            null
        }
        pending?.success(text?.takeIf { it.isNotBlank() })
        pending = null
        return true
    }
}
