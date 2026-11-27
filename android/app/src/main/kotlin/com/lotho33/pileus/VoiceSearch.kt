package com.lotho33.pileus

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Voice search through the system's speech recognition, two ways:
 *
 *  - "dialog": the system's own dictation dialog (RecognizerIntent). It
 *    listens — on a TV, through the remote's microphone — and hands back the
 *    text; Pileus never touches audio, so no permission.
 *  - "service": many TVs (Google TV included) have no such dialog but do have
 *    a recognition service (SpeechRecognizer). Pileus drives it and shows its
 *    own "listening" dialog on the Flutter side; the service needs the
 *    microphone permission, asked the first time.
 *
 * `available` answers "dialog", "service" or "" (no recognizer at all: some
 * Fire TV and AOSP boxes) — with "" the app shows no microphone button.
 */
object VoiceSearch {
    private const val REQUEST = 0x5650 // "VP"
    private const val PERMISSION_REQUEST = 0x5651
    private var pending: MethodChannel.Result? = null
    private var recognizer: SpeechRecognizer? = null
    private var afterPermission: (() -> Unit)? = null

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "pileus/voice")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(mode(activity))
                    "listen" -> listen(activity, call.argument<String>("prompt"), result)
                    "cancel" -> {
                        recognizer?.cancel()
                        finish(null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun mode(activity: Activity): String = when {
        intent(null).resolveActivity(activity.packageManager) != null -> "dialog"
        SpeechRecognizer.isRecognitionAvailable(activity) -> "service"
        else -> ""
    }

    private fun intent(prompt: String?) = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        if (prompt != null) putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
    }

    private fun listen(activity: Activity, prompt: String?, result: MethodChannel.Result) {
        // A second request while one is open: the first one gets nothing.
        finish(null)
        pending = result
        when (mode(activity)) {
            "dialog" -> try {
                activity.startActivityForResult(intent(prompt), REQUEST)
            } catch (_: Throwable) {
                finish(null)
            }
            "service" -> withMicrophone(activity) { listenService(activity) }
            else -> finish(null)
        }
    }

    private fun withMicrophone(activity: Activity, then: () -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        ) {
            then()
            return
        }
        afterPermission = then
        activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST)
    }

    /** True when it was ours. Denied: the search gets nothing. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val then = afterPermission
        afterPermission = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            then?.invoke()
        } else {
            finish(null)
        }
        return true
    }

    private fun listenService(activity: Activity) {
        recognizer?.destroy()
        val r = try {
            SpeechRecognizer.createSpeechRecognizer(activity)
        } catch (_: Throwable) {
            finish(null)
            return
        }
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                finish(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull())
            }

            override fun onError(error: Int) = finish(null)
            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        try {
            r.startListening(intent(null))
        } catch (_: Throwable) {
            finish(null)
        }
    }

    private fun finish(text: String?) {
        val p = pending
        pending = null
        recognizer?.destroy()
        recognizer = null
        p?.success(text?.takeIf { it.isNotBlank() })
    }

    /** True when it was ours. The text, or null when cancelled/nothing heard. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val text = if (resultCode == Activity.RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else {
            null
        }
        finish(text)
        return true
    }
}
