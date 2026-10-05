package com.vigishield.app.validation

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.*
import android.media.projection.*
import android.os.*
import android.view.Surface
import android.view.WindowManager
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.util.UUID

/** One consent, one virtual display, one continuous AVC encoder per session. No audio. */
class ScreenBufferService : Service() {
    companion object {
        @Volatile var instance: ScreenBufferService? = null
        @Volatile var running = false
        @Volatile var lastStopReason: String? = null
        var onStarted: ((String?) -> Unit)? = null

        /**
         * Token del consentimiento en curso. Lo comparten la actividad (que pide
         * el permiso) y el servicio (que arranca despues): entre lo uno y lo
         * otro el usuario puede cancelar o volver a conceder, y sin el token un
         * arranque ya encolado seguia adelante tras cancelar.
         */
        val gate = CaptureSessionGate()
        /** Tope de un clip de evento (ventana de 20 s). */
        const val LIMITE_CLIP = 32L * 1024 * 1024
        /** Tope de una grabacion continua: ~1 h a 720p, sin llenar el telefono. */
        const val LIMITE_CONTINUO = 512L * 1024 * 1024

        fun directory(context: Context) = File(context.filesDir, "validation_screen_clips").apply { mkdirs() }
        fun list(context: Context): List<Map<String, Any?>> = directory(context).listFiles().orEmpty()
            .filter { it.extension == "json" }.mapNotNull { file -> runCatching {
                val obj = JSONObject(file.readText())
                obj.keys().asSequence().associateWith { key -> obj.get(key).let { if (it == JSONObject.NULL) null else it } }
            }.getOrNull() }.sortedByDescending { (it["createdAtMs"] as? Number)?.toLong() ?: 0 }
    }
    private lateinit var thread: HandlerThread
    private lateinit var worker: Handler
    private val main = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var encoder: MediaCodec? = null
    private var display: VirtualDisplay? = null
    private var surface: Surface? = null
    private var format: MediaFormat? = null
    private val ring = SampleRing()
    private var closing = false
    private var width = 0
    private var height = 0
    private var sourceWidth = 0
    private var sourceHeight = 0
    private var rotation = 0
    private val clips = mutableListOf<PendingClip>()
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() { shutdown("revoked") }
        override fun onCapturedContentResize(w: Int, h: Int) {
            if (w != sourceWidth || h != sourceHeight) shutdown("display_resized")
        }
    }
    /**
     * Un clip en curso. Con [continuo] no se cierra solo a los 10 s: sigue
     * grabando hasta que el usuario pulse detener, que es lo que hace falta
     * para dejar evidencia de una sesion de validacion entera.
     */
    private inner class PendingClip(val eventId: String, val eventUs: Long,
                                    samples: List<EncodedSample>,
                                    val continuo: Boolean = false) {
        val file = File(directory(this@ScreenBufferService), "${UUID.randomUUID()}.mp4")
        val createdAtMs = System.currentTimeMillis()
        val muxer = MediaMuxer(file.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val track = muxer.addTrack(format!!)
        val firstUs = samples.first().ptsUs
        var lastUs = firstUs
        var keyframes = 0
        var bytes = 0L
        init { muxer.start(); samples.forEach { write(it) } }
        fun write(sample: EncodedSample) {
            val info = MediaCodec.BufferInfo().apply { set(0, sample.bytes.size, sample.ptsUs - firstUs, if (sample.keyframe) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0) }
            muxer.writeSampleData(track, ByteBuffer.wrap(sample.bytes), info)
            lastUs = sample.ptsUs; bytes += sample.bytes.size
            if (sample.keyframe) keyframes++
        }
        fun metadata(status: String, reason: String?) = linkedMapOf<String, Any?>(
            "eventId" to eventId, "path" to file.absolutePath, "status" to status,
            "createdAtMs" to createdAtMs, "preMs" to ((eventUs - firstUs).coerceAtLeast(0) / 1000),
            "postMs" to ((lastUs - eventUs).coerceAtLeast(0) / 1000),
            "durationMs" to ((lastUs - firstUs) / 1000), "startsWithKeyframe" to true,
            "keyframeCount" to keyframes, "width" to width, "height" to height,
            "audio" to false, "reason" to reason,
            "requestedPreMs" to 10000, "requestedPostMs" to 10000)
        fun finish(reason: String?) {
            var failure = reason
            try { muxer.stop() } catch (e: Exception) { failure = "muxer_error: ${e.message}" }
            finally { runCatching { muxer.release() } }
            val status = if (failure?.startsWith("muxer_error") == true) "failed" else if (failure != null) "partial" else "complete"
            if (status == "failed") file.delete()
            File(file.parentFile, "${file.nameWithoutExtension}.json").writeText(JSONObject(metadata(status, failure)).toString())
        }
    }
    override fun onCreate() {
        super.onCreate(); instance = this
        thread = HandlerThread("validation-screen").apply { start() }; worker = Handler(thread.looper)
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") { stop("notification_stop"); return START_NOT_STICKY }
        if (running || projection != null) return START_NOT_STICKY
        try {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(NotificationChannel("validation_screen", "Screen validation capture", NotificationManager.IMPORTANCE_LOW))
            val stop = PendingIntent.getService(this, 41, Intent(this, ScreenBufferService::class.java).setAction("STOP"), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            val notification = Notification.Builder(this, "validation_screen")
                .setSmallIcon(android.R.drawable.ic_menu_camera).setContentTitle("VigiShield screen buffer active")
                .setContentText("Entire display • no audio • tap Stop to end capture")
                .setOngoing(true).addAction(android.R.drawable.ic_media_pause, "Stop", stop).build()
            if (Build.VERSION.SDK_INT >= 29) startForeground(7401, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            else startForeground(7401, notification)
            @Suppress("DEPRECATION") val data = intent?.getParcelableExtra<Intent>("consent")
            requireNotNull(data) { "Fresh screen consent required" }
            // Si el usuario cancelo mientras este arranque estaba en camino, el
            // token ya no es el vigente y la captura no debe empezar.
            val token = intent.getLongExtra("consentToken", 0L)
            if (!gate.claim(token)) { stop("consent_cancelled"); return START_NOT_STICKY }
            worker.post { try { startCapture(data) } catch (e: Exception) { reportStart(e.message ?: "Capture failed"); shutdown("start_failed") } }
        } catch (e: Exception) { reportStart(e.message ?: "Foreground service failed"); stop("start_failed") }
        return START_NOT_STICKY
    }
    @Suppress("DEPRECATION")
    private fun startCapture(data: Intent) {
        val metrics = android.util.DisplayMetrics()
        val realDisplay = getSystemService(WindowManager::class.java).defaultDisplay
        realDisplay.getRealMetrics(metrics); rotation = realDisplay.rotation
        sourceWidth = metrics.widthPixels; sourceHeight = metrics.heightPixels
        val scale = minOf(1.0, 1280.0 / maxOf(sourceWidth, sourceHeight))
        width = ((sourceWidth * scale).toInt() / 2) * 2; height = ((sourceHeight * scale).toInt() / 2) * 2
        val config = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 2_000_000); setInteger(MediaFormat.KEY_FRAME_RATE, 15)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
            if (Build.VERSION.SDK_INT >= 29) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
        }
        encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).also {
            it.configure(config, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            surface = it.createInputSurface(); it.start()
        }
        projection = getSystemService(MediaProjectionManager::class.java).getMediaProjection(Activity.RESULT_OK, data)
        projection!!.registerCallback(projectionCallback, worker)
        display = projection!!.createVirtualDisplay("VigiShield validation", width, height, metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, surface, null, worker)
        running = true; lastStopReason = null; reportStart(null); worker.post(drain)
    }
    private fun reportStart(error: String?) { main.post { onStarted?.invoke(error); onStarted = null } }
    private val drain = object : Runnable {
        override fun run() {
            if (closing || !running) return
            try {
                val codec = encoder ?: return
                val info = MediaCodec.BufferInfo()
                repeat(64) {
                    val index = codec.dequeueOutputBuffer(info, 0)
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) format = codec.outputFormat
                    if (index >= 0) {
                        try {
                            if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                val buffer = codec.getOutputBuffer(index)!!
                                buffer.position(info.offset); buffer.limit(info.offset + info.size)
                                val bytes = ByteArray(info.size); buffer.get(bytes)
                                val sample = EncodedSample(info.presentationTimeUs, bytes, info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0)
                                ring.add(sample)
                                clips.toList().forEach { clip ->
                                    if (sample.ptsUs > clip.lastUs) clip.write(sample)
                                    // El tope de tamano se respeta siempre: sin el, una
                                    // sesion larga llenaria el almacenamiento del telefono.
                                    val tope = if (clip.continuo) LIMITE_CONTINUO else LIMITE_CLIP
                                    if (clip.bytes > tope) finish(clip, "size_limit")
                                    else if (!clip.continuo && sample.ptsUs >= clip.eventUs + 10_000_000) finish(clip, null)
                                }
                            }
                        } finally { codec.releaseOutputBuffer(index, false) }
                    }
                }
                worker.postDelayed(this, 20)
            } catch (e: Exception) { shutdown("encoder_error: ${e.message}") }
        }
    }
    fun mark(eventId: String, callback: (Map<String, Any?>?, String?) -> Unit) {
        worker.post {
            try {
                require(running && !closing && format != null) { "Screen buffer is not ready" }
                require(eventId.isNotBlank() && eventId.length <= 200) { "Invalid eventId" }
                require(clips.size < 3) { "At most three simultaneous screen clips" }
                val now = System.nanoTime() / 1000
                val samples = ring.before(now)
                require(samples.isNotEmpty()) { "Waiting for first screen keyframe" }
                val clip = PendingClip(eventId, now, samples); clips.add(clip)
                main.post { callback(clip.metadata("pending", null), null) }
                worker.postDelayed({ if (clip in clips) finish(clip, "post_window_timeout") }, 11_000)
            } catch (e: Exception) { main.post { callback(null, e.message) } }
        }
    }
    /**
     * Empieza una grabacion continua de la pantalla.
     *
     * Arranca con lo que haya en el anillo, asi que incluye unos segundos
     * previos a pulsar el boton. Solo puede haber una a la vez.
     */
    fun startContinuous(eventId: String, callback: (Map<String, Any?>?, String?) -> Unit) {
        worker.post {
            try {
                require(running && !closing && format != null) { "Screen buffer is not ready" }
                require(clips.none { it.continuo }) { "Ya hay una grabacion en curso" }
                require(clips.size < 3) { "At most three simultaneous screen clips" }
                val ahora = System.nanoTime() / 1000
                val samples = ring.before(ahora)
                require(samples.isNotEmpty()) { "Waiting for first screen keyframe" }
                val clip = PendingClip(eventId, ahora, samples, continuo = true)
                clips.add(clip)
                main.post { callback(clip.metadata("recording", null), null) }
            } catch (e: Exception) { main.post { callback(null, e.message) } }
        }
    }

    /** Cierra la grabacion continua y devuelve su ficha. */
    fun stopContinuous(callback: (Map<String, Any?>?, String?) -> Unit) {
        worker.post {
            val clip = clips.firstOrNull { it.continuo }
            if (clip == null) { main.post { callback(null, "No hay ninguna grabacion en curso") }; return@post }
            val ficha = clip.metadata("complete", null)
            finish(clip, null)
            main.post { callback(ficha, null) }
        }
    }

    private fun finish(clip: PendingClip, reason: String?) {
        clips.remove(clip)
        runCatching { clip.finish(reason) }.onFailure { lastStopReason = "clip_write_failed: ${it.message}" }
    }
    fun stop(reason: String, done: (() -> Unit)? = null) { worker.post { shutdown(reason); main.post { done?.invoke() } } }
    private fun shutdown(reason: String) {
        if (closing) return
        closing = true; running = false; lastStopReason = reason
        worker.removeCallbacksAndMessages(null)
        clips.toList().forEach { finish(it, reason) }
        runCatching { display?.release() }; display = null
        runCatching { encoder?.stop() }; runCatching { encoder?.release() }; encoder = null
        runCatching { surface?.release() }; surface = null
        runCatching { projection?.unregisterCallback(projectionCallback) }; runCatching { projection?.stop() }; projection = null
        ring.clear(); format = null
        main.post { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    }
    @Suppress("DEPRECATION")
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        if (getSystemService(WindowManager::class.java).defaultDisplay.rotation != rotation) stop("rotation")
    }
    override fun onDestroy() {
        instance = null
        worker.post { shutdown("service_destroyed"); thread.quitSafely() }
        super.onDestroy()
    }
}
