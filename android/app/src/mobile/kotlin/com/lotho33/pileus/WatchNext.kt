package com.lotho33.pileus

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine

/** Mobile flavor: no Android TV home screen row — see src/tv/…/WatchNext.kt. */
object WatchNext {
    @Suppress("UNUSED_PARAMETER")
    fun register(engine: FlutterEngine, context: Context) {}

    @Suppress("UNUSED_PARAMETER")
    fun onIntent(intent: Intent?, notify: Boolean) {}
}
