package com.lotho33.pileus

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Pileus' Continue Watching in the system's own "Watch Next" / "Continua a
 * guardare" row on the Android TV / Google TV home screen, and the way back
 * in: a card there opens pileus://resume?plugin=…&id=…, which the Dart side
 * takes (takeLaunch) once the home is up and resumes like its own card.
 *
 * TV flavor only — the mobile flavor has a no-op twin (src/mobile), so the
 * phone app doesn't carry androidx.tvprovider. Everything is best-effort:
 * a box without the TV provider (Fire TV, some AOSP ROMs) or below Android 8
 * simply gets no row, never an error.
 */
object WatchNext {
    private const val CHANNEL = "pileus/watchnext"
    private const val TAG = "pileus/watchnext"
    private val io = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null
    @Volatile private var pendingLaunch: String? = null

    fun register(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "sync" -> {
                    val items = call.argument<List<Map<String, Any?>>>("items") ?: emptyList()
                    io.execute {
                        try {
                            sync(app, items)
                        } catch (t: Throwable) {
                            Log.w(TAG, "sync failed: $t")
                        }
                    }
                    result.success(null)
                }
                "takeLaunch" -> {
                    result.success(pendingLaunch)
                    pendingLaunch = null
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** A launch/new intent: remember a pileus:// card, tell Dart if it's running. */
    fun onIntent(intent: Intent?, notify: Boolean) {
        val uri = intent?.data ?: return
        if (uri.scheme != "pileus") return
        pendingLaunch = uri.toString()
        if (notify) channel?.invokeMethod("launch", null)
    }

    private fun sync(context: Context, items: List<Map<String, Any?>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val cr = context.contentResolver
        // No TV provider on this device: nothing to do.
        cr.acquireContentProviderClient(TvContractCompat.AUTHORITY)?.close() ?: return

        // Our own programs only (the provider scopes the query to the caller).
        val existing = HashMap<String, Pair<Long, Boolean>>()
        cr.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            WatchNextProgram.PROJECTION, null, null, null
        )?.use { c ->
            while (c.moveToNext()) {
                val p = WatchNextProgram.fromCursor(c)
                val key = p.internalProviderId ?: continue
                existing[key] = p.id to p.isBrowsable
            }
        }

        val now = System.currentTimeMillis()
        val wanted = HashSet<String>()
        items.forEachIndexed { i, item ->
            val key = item["key"] as? String ?: return@forEachIndexed
            wanted.add(key)
            val known = existing[key]
            // Removed by the user from the row: never put it back.
            if (known != null && !known.second) return@forEachIndexed
            // Most recent first, as Pileus orders its own row.
            val program = build(item, now - i * 1000L)
            if (known == null) {
                cr.insert(TvContractCompat.WatchNextPrograms.CONTENT_URI, program.toContentValues())
            } else {
                cr.update(
                    TvContractCompat.buildWatchNextProgramUri(known.first),
                    program.toContentValues(), null, null
                )
            }
        }
        // Gone from Continue Watching (finished, removed, other profile).
        for ((key, v) in existing) {
            if (key !in wanted) {
                cr.delete(TvContractCompat.buildWatchNextProgramUri(v.first), null, null)
            }
        }
    }

    private fun build(item: Map<String, Any?>, engagedAt: Long): WatchNextProgram {
        val episode = item["episode"] as? Boolean ?: false
        val b = WatchNextProgram.Builder()
        b.setType(
            if (episode) TvContractCompat.WatchNextPrograms.TYPE_TV_EPISODE
            else TvContractCompat.WatchNextPrograms.TYPE_MOVIE
        )
            .setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
            .setLastEngagementTimeUtcMillis(engagedAt)
            .setTitle(item["title"] as? String ?: "")
            .setPosterArtAspectRatio(TvContractCompat.PreviewPrograms.ASPECT_RATIO_16_9)
            .setLastPlaybackPositionMillis((item["positionMs"] as? Number)?.toInt() ?: 0)
            .setDurationMillis((item["durationMs"] as? Number)?.toInt() ?: 0)
            .setIntentUri(Uri.parse(item["uri"] as String))
            .setInternalProviderId(item["key"] as String)
        val poster = item["poster"] as? String
        if (!poster.isNullOrEmpty()) b.setPosterArtUri(Uri.parse(poster))
        if (episode) {
            (item["episodeTitle"] as? String)?.takeIf { it.isNotEmpty() }?.let { b.setEpisodeTitle(it) }
            (item["season"] as? Number)?.toInt()?.takeIf { it > 0 }?.let { b.setSeasonNumber(it) }
            (item["episodeNumber"] as? Number)?.toInt()?.takeIf { it > 0 }?.let { b.setEpisodeNumber(it) }
        }
        return b.build()
    }
}
