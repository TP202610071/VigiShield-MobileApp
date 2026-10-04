package com.vigishield.app.validation

import java.io.File
import java.util.ArrayDeque

data class EncodedSample(val ptsUs: Long, val bytes: ByteArray, val keyframe: Boolean)

/** Bounded encoded GOP ring; never expose an undecodable leading delta frame. */
class SampleRing(private val durationUs: Long = 10_000_000, private val maxBytes: Int = 16 * 1024 * 1024) {
    private val samples = ArrayDeque<EncodedSample>()
    var byteCount: Int = 0; private set
    fun add(sample: EncodedSample) {
        if (samples.isEmpty() && !sample.keyframe) return
        samples.addLast(sample); byteCount += sample.bytes.size
        // Strict ten-second bound. A missing keyframe shortens pre-roll instead
        // of retaining an arbitrarily old GOP. Metadata exposes actual coverage.
        while (samples.isNotEmpty() &&
            (samples.first.ptsUs < sample.ptsUs - durationUs || byteCount > maxBytes)) {
            byteCount -= samples.removeFirst().bytes.size
        }
        while (samples.isNotEmpty() && !samples.first.keyframe) byteCount -= samples.removeFirst().bytes.size
    }
    fun before(eventUs: Long): List<EncodedSample> {
        val eligible = samples.filter { it.ptsUs in (eventUs - durationUs)..eventUs }
        return eligible.dropWhile { !it.keyframe }
    }
    fun clear() { samples.clear(); byteCount = 0 }
}

object TestCallPolicy {
    const val NUMBER = "+51986913791"
    fun allowed(number: String, armed: Boolean, permission: Boolean) = armed && permission && number == NUMBER
}

/** Main-thread activity gate: a permission grant is never itself an opt-in. */
class TestCallGate {
    var resumed = false; private set
    var armed = false; private set
    fun setResumed(value: Boolean) {
        resumed = value
        if (!value) armed = false
    }
    fun setArmed(enabled: Boolean, permission: Boolean): Boolean {
        armed = enabled && resumed && permission
        return armed
    }
    fun consume(permission: Boolean): Boolean {
        val allowed = resumed && TestCallPolicy.allowed(TestCallPolicy.NUMBER, armed, permission)
        armed = false
        return allowed
    }
}

object ClipPaths {
    fun owned(root: File, path: String): File {
        val file = File(path).canonicalFile
        require(file.parentFile == root.canonicalFile && file.extension == "mp4") { "Not an owned screen clip" }
        return file
    }
}

/**
 * Token del consentimiento de captura de pantalla.
 *
 * Entre que el usuario concede el permiso y que el servicio arranca de verdad
 * pasa tiempo, y en ese hueco el usuario puede cancelar o volver a conceder.
 * Con una sola bandera mutable había dos carreras: un arranque ya encolado
 * seguía adelante después de cancelar, y un servicio viejo al terminar se
 * llevaba por delante un consentimiento nuevo.
 *
 * Cada consentimiento recibe un identificador propio: sólo el vigente puede
 * reclamar el arranque, y sólo una vez.
 */
class CaptureSessionGate {
    private var secuencia = 0L
    private var vigente = 0L
    private var reclamado = false

    /** Abre un consentimiento nuevo e invalida el anterior. */
    @Synchronized fun begin(): Long {
        vigente = ++secuencia
        reclamado = false
        return vigente
    }

    /** Arranca el servicio. Cierto sólo para el consentimiento vigente y una vez. */
    @Synchronized fun claim(id: Long): Boolean {
        if (id != vigente || reclamado) return false
        reclamado = true
        return true
    }

    /**
     * Cancela el consentimiento vigente. Con [id], sólo cancela si ese sigue
     * siendo el vigente: así un servicio que termina tarde no puede tumbar un
     * consentimiento posterior.
     */
    @Synchronized fun cancel(id: Long? = null) {
        if (id != null && id != vigente) return
        vigente = 0
        reclamado = false
    }

    @Synchronized fun isCurrent(id: Long) = id != 0L && id == vigente
}
