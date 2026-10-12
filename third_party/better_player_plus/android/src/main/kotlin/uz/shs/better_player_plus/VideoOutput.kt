package uz.shs.better_player_plus

import android.view.Surface
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.view.TextureRegistry.SurfaceProducer
import io.flutter.view.TextureRegistry.SurfaceTextureEntry

// PILEUS PATCH: where ExoPlayer renders video. Upstream 2.0.0 (PR #138)
// switched from a SurfaceTexture to a SurfaceProducer; Pileus keeps the old
// path selectable per device ("rendering video compatibile") in case a
// driver handles the new one worse.
@UnstableApi
internal interface VideoOutput {
    fun id(): Long

    /** False when frames arrive unrotated and Dart has to rotate the texture. */
    fun handlesCropAndRotation(): Boolean

    fun attach(player: ExoPlayer)

    /**
     * False while the engine has taken the surface away (app in background):
     * no frames can be rendered then, which is not a freeze.
     */
    fun hasSurface(): Boolean

    /**
     * Detach and re-attach the current surface: ExoPlayer then hands the
     * decoder a fresh output surface. Recovery for a picture frozen while
     * audio keeps playing.
     */
    fun reattach(player: ExoPlayer)

    fun detach()

    /** Only after the player has been released. */
    fun release()
}

/**
 * Flutter picks the backend: an ImageReader under Impeller/Vulkan (no
 * GL→Vulkan interop and fence wait per frame), a SurfaceTexture otherwise.
 */
@UnstableApi
internal class ProducerVideoOutput(private val producer: SurfaceProducer) : VideoOutput {
    private var surfaceAvailable = true

    override fun id(): Long = producer.id()

    override fun hasSurface(): Boolean = surfaceAvailable

    override fun handlesCropAndRotation(): Boolean = producer.handlesCropAndRotation()

    override fun attach(player: ExoPlayer) {
        // The engine may destroy the surface (e.g. in background) and hand out a new one later.
        producer.setCallback(object : SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                surfaceAvailable = true
                player.setVideoSurface(producer.surface)
            }

            override fun onSurfaceCleanup() {
                surfaceAvailable = false
                player.setVideoSurface(null)
            }
        })
        player.setVideoSurface(producer.surface)
    }

    override fun reattach(player: ExoPlayer) {
        if (!surfaceAvailable) return
        player.setVideoSurface(null)
        player.setVideoSurface(producer.surface)
    }

    override fun detach() = producer.setCallback(null)

    override fun release() = producer.release()
}

/** better_player_plus ≤1.4.1 behaviour: one GL SurfaceTexture for the player's whole life. */
@UnstableApi
internal class SurfaceTextureVideoOutput(private val entry: SurfaceTextureEntry) : VideoOutput {
    private var surface: Surface? = null

    override fun id(): Long = entry.id()

    override fun hasSurface(): Boolean = surface != null

    // The SurfaceTexture's transform matrix already carries the rotation.
    override fun handlesCropAndRotation(): Boolean = true

    override fun attach(player: ExoPlayer) {
        val s = Surface(entry.surfaceTexture())
        surface = s
        player.setVideoSurface(s)
    }

    override fun reattach(player: ExoPlayer) {
        player.setVideoSurface(null)
        player.setVideoSurface(surface)
    }

    override fun detach() {}

    override fun release() {
        entry.release()
        surface?.release()
        surface = null
    }
}
