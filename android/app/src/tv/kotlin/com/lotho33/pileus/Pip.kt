package com.lotho33.pileus

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine

/** TV flavor: no picture-in-picture — see src/mobile/…/Pip.kt. */
object Pip {
    @Suppress("UNUSED_PARAMETER")
    fun register(engine: FlutterEngine, activity: Activity) {}

    @Suppress("UNUSED_PARAMETER")
    fun onUserLeaveHint(activity: Activity) {}

    @Suppress("UNUSED_PARAMETER")
    fun onModeChanged(inPip: Boolean) {}
}
