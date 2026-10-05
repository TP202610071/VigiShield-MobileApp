package com.vigishield.app

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import com.cloudwebrtc.webrtc.FlutterWebRTCPlugin
import com.cloudwebrtc.webrtc.video.LocalVideoTrack
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.webrtc.VideoFrame

/**
 * Fija la rotación del video que publica el teléfono según su posición FÍSICA.
 *
 * La cámara de WebRTC en Android calcula la rotación de cada cuadro con la
 * orientación de la PANTALLA. Con la app en vertical y el teléfono acostado, el
 * video salía de lado; por eso antes la app entera giraba con el teléfono
 * mientras transmitía. Ahora cada cuadro lleva la rotación que corresponde a la
 * posición física y la interfaz puede quedarse en vertical. Entrar o salir de
 * la pestaña Cámara (que sí gira) tampoco cambia el tamaño del video.
 *
 * Misma cuenta que Camera2Session, con la posición física en lugar de la de la
 * pantalla: trasera (sensor − posición), frontal (sensor + posición).
 */
class RotacionCamara(private val context: Context, messenger: BinaryMessenger) {
    private class Fija(@Volatile var grados: Int) : LocalVideoTrack.ExternalVideoFrameProcessing {
        // Mismo buffer, solo cambia el dato de rotación: el codificador gira
        // los píxeles al enviar. No se toma otra referencia del buffer: la
        // suelta quien entregó el cuadro.
        override fun onFrame(frame: VideoFrame): VideoFrame =
            if (frame.rotation == grados) frame else VideoFrame(frame.buffer, grados, frame.timestampNs)
    }

    private val activas = HashMap<String, Pair<LocalVideoTrack, Fija>>()

    init {
        MethodChannel(messenger, "vigishield/rotacion_camara").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "fijar" -> {
                        val id = requireNotNull(call.argument<String>("trackId"))
                        val fisica = requireNotNull(call.argument<Int>("grados"))
                        val frontal = call.argument<Boolean>("frontal") == true
                        val pista = FlutterWebRTCPlugin.sharedSingleton?.getLocalTrack(id) as? LocalVideoTrack
                            ?: throw IllegalStateException("No se encontró la pista de video $id")
                        val sensor = orientacionSensor(frontal)
                        val grados = if (frontal) (sensor + fisica) % 360 else (sensor - fisica + 360) % 360
                        val previa = activas[id]
                        if (previa != null) previa.second.grados = grados
                        else Fija(grados).also { pista.addProcessor(it); activas[id] = pista to it }
                        result.success(grados)
                    }
                    "soltar" -> {
                        activas.remove(call.argument<String>("trackId"))?.let { (pista, fija) -> pista.removeProcessor(fija) }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("rotacion_camara", e.message, null)
            }
        }
    }

    /** Orientación del sensor de la primera cámara con esa lente: la misma
     *  que elige flutter_webrtc con facingMode. */
    private fun orientacionSensor(frontal: Boolean): Int {
        val manager = context.getSystemService(CameraManager::class.java)
        val lente = if (frontal) CameraCharacteristics.LENS_FACING_FRONT else CameraCharacteristics.LENS_FACING_BACK
        for (id in manager.cameraIdList) {
            val datos = manager.getCameraCharacteristics(id)
            if (datos.get(CameraCharacteristics.LENS_FACING) == lente) {
                return datos.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: if (frontal) 270 else 90
            }
        }
        return if (frontal) 270 else 90
    }
}
