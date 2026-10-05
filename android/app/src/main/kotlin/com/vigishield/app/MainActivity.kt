package com.vigishield.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.*
import com.vigishield.app.validation.*
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var screenResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private val callGate = TestCallGate()
    /** Consentimiento de captura en curso; 0 si no hay ninguno. */
    private var consentToken = 0L
    private var tone: ToneGenerator? = null
    private var oldBrightness: Float? = null
    private val handler = Handler(Looper.getMainLooper())
    private val stopAlarmTask = Runnable { stopAlarm() }
    private val alarmPulse = object : Runnable {
        override fun run() { tone?.startTone(ToneGenerator.TONE_PROP_BEEP, 400); if (tone != null) handler.postDelayed(this, 900) }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        emergencyChannel(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vigishield/validation").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "deviceCapabilities" -> result.success(mapOf(
                        "platform" to "android", "screenCapture" to true, "testAlarm" to true,
                        "testCall" to packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY),
                        "screenBufferRunning" to ScreenBufferService.running, "lastStopReason" to ScreenBufferService.lastStopReason,
                        "callPermissionGranted" to callPermission(), "testCallArmed" to callGate.armed,
                        "testCallNumber" to TestCallPolicy.NUMBER, "audioCapture" to false,
                        "captureScope" to "entireDisplay", "preSeconds" to 10, "postSeconds" to 10))
                    "startScreenBuffer" -> {
                        check(callGate.resumed) { "Screen consent requires a resumed activity" }
                        check(screenResult == null && ScreenBufferService.onStarted == null) { "Consent/start already pending" }
                        if (ScreenBufferService.running) result.success(mapOf("running" to true))
                        else {
                            check(ScreenBufferService.instance == null) { "Previous capture is stopping; retry" }
                            screenResult = result
                            consentToken = ScreenBufferService.gate.begin()
                            val manager = getSystemService(MediaProjectionManager::class.java)
                            val intent = if (Build.VERSION.SDK_INT >= 34) manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay()) else manager.createScreenCaptureIntent()
                            startActivityForResult(intent, 7402)
                        }
                    }
                    "stopScreenBuffer" -> {
                        screenResult?.error("cancelled", "Screen capture cancelled", null); screenResult = null
                        ScreenBufferService.gate.cancel()
                        ScreenBufferService.onStarted?.invoke("Screen capture cancelled"); ScreenBufferService.onStarted = null
                        val service = ScreenBufferService.instance
                        if (service == null) result.success(mapOf("running" to false))
                        else service.stop("user_stop") { result.success(mapOf("running" to false)) }
                    }
                    "markScreenEvent" -> {
                        val id = requireNotNull(call.argument<String>("eventId"))
                        val service = checkNotNull(ScreenBufferService.instance) { "Screen buffer not running" }
                        service.mark(id) { metadata, error -> if (error != null) result.error("screen_event", error, null) else result.success(metadata) }
                    }
                    // Grabacion continua: del boton de grabar al de detener, para
                    // dejar evidencia de una sesion de validacion entera.
                    "startScreenRecording" -> {
                        val id = call.argument<String>("eventId") ?: "sesion"
                        val service = checkNotNull(ScreenBufferService.instance) { "Screen buffer not running" }
                        service.startContinuous(id) { metadata, error ->
                            if (error != null) result.error("screen_recording", error, null) else result.success(metadata)
                        }
                    }
                    "stopScreenRecording" -> {
                        val service = checkNotNull(ScreenBufferService.instance) { "Screen buffer not running" }
                        service.stopContinuous { metadata, error ->
                            if (error != null) result.error("screen_recording", error, null) else result.success(metadata)
                        }
                    }
                    "listScreenClips" -> result.success(ScreenBufferService.list(this))
                    "deleteScreenClip" -> {
                        val file = ClipPaths.owned(ScreenBufferService.directory(this), requireNotNull(call.argument<String>("path")))
                        val metadata = File(file.parentFile, "${file.nameWithoutExtension}.json")
                        // Pending muxers have no sidecar yet: never delete an open output.
                        check(metadata.exists()) { "Clip is pending or not found" }
                        check(!file.exists() || file.delete()) { "Cannot delete clip" }
                        result.success(metadata.delete())
                    }
                    "startTestAlarm" -> { startAlarm(); result.success(true) }
                    "stopTestAlarm" -> { stopAlarm(); result.success(true) }
                    "requestTestCallPermission" -> {
                        check(callGate.resumed) { "Permission request requires a resumed activity" }
                        check(permissionResult == null) { "Permission request pending" }
                        if (callPermission()) result.success(true)
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), 7403) }
                    }
                    "setTestCallArmed" -> result.success(callGate.setArmed(call.argument<Boolean>("enabled") == true, callPermission()))
                    "placeTestCall" -> {
                        check(callGate.consume(callPermission())) { "Resumed activity, explicit arming and CALL_PHONE permission required" }
                        check(packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) { "Telephony unavailable" }
                        // Gate consumes the one-shot opt-in before dispatch; no arbitrary dial target.
                        startActivity(Intent(Intent.ACTION_CALL, Uri.fromParts("tel", TestCallPolicy.NUMBER, null)))
                        result.success(true) // Intent dispatched, not a claim that a call connected.
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                if (screenResult === result) screenResult = null
                if (permissionResult === result) permissionResult = null
                result.error("validation_error", e.message, null)
            }
        }
    }
    /**
     * Alerta de emergencia del producto. A diferencia de la llamada de prueba
     * de validacion, el numero lo pone el usuario; aun asi se rechazan los
     * numeros cortos (105, 911, 112...): ninguna app debe llamarlos sola.
     * Sin permiso CALL_PHONE se abre el marcador con el numero puesto.
     */
    private fun emergencyChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vigishield/emergency").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "requestCallPermission" -> {
                        if (callPermission()) result.success(true)
                        else if (permissionResult != null) result.success(false)
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), 7403) }
                    }
                    "placeCall" -> {
                        val raw = requireNotNull(call.argument<String>("number"))
                        val digits = raw.filter { it.isDigit() }
                        check(digits.length in 7..15) { "Invalid number" }
                        val number = (if (raw.trim().startsWith("+")) "+" else "") + digits
                        check(packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)) { "Telephony unavailable" }
                        val action = if (callPermission()) Intent.ACTION_CALL else Intent.ACTION_DIAL
                        startActivity(Intent(action, Uri.fromParts("tel", number, null)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                if (permissionResult === result) permissionResult = null
                result.error("emergency_error", e.message, null)
            }
        }
    }
    private fun callPermission() = checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED
    @Deprecated("Uses existing Flutter activity result forwarding")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7402) return
        val result = screenResult ?: return
        screenResult = null
        val token = consentToken
        consentToken = 0L
        if (resultCode != RESULT_OK || data == null) {
            ScreenBufferService.gate.cancel(token)
            result.error("consent_denied", "Screen capture consent denied", null); return
        }
        // El usuario pudo cancelar mientras el dialogo del sistema estaba abierto.
        if (!ScreenBufferService.gate.isCurrent(token)) {
            result.error("cancelled", "Screen capture cancelled", null); return
        }
        ScreenBufferService.onStarted = { error ->
            if (error == null) result.success(mapOf("running" to true, "audio" to false, "preSeconds" to 10, "postSeconds" to 10))
            else result.error("screen_start", error, null)
        }
        try {
            startForegroundService(Intent(this, ScreenBufferService::class.java)
                .putExtra("consent", data).putExtra("consentToken", token))
        }
        catch (e: Exception) {
            ScreenBufferService.gate.cancel(token)
            ScreenBufferService.onStarted?.invoke(e.message); ScreenBufferService.onStarted = null
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7403) { permissionResult?.success(callPermission()); permissionResult = null }
    }
    @Suppress("DEPRECATION")
    private fun startAlarm() {
        check(callGate.resumed) { "Test alarm requires a resumed activity" }
        stopAlarm()
        try {
            oldBrightness = window.attributes.screenBrightness
            window.attributes = window.attributes.apply { screenBrightness = 1f }
            tone = ToneGenerator(AudioManager.STREAM_ALARM, 15)
            handler.post(alarmPulse)
            getSystemService(Vibrator::class.java).vibrate(VibrationEffect.createWaveform(longArrayOf(0, 300, 700), 0))
            handler.postDelayed(stopAlarmTask, 30_000)
        } catch (e: Exception) { stopAlarm(); throw e }
    }
    @Suppress("DEPRECATION")
    private fun stopAlarm() {
        handler.removeCallbacks(alarmPulse); handler.removeCallbacks(stopAlarmTask)
        tone?.stopTone(); tone?.release(); tone = null
        getSystemService(Vibrator::class.java).cancel()
        oldBrightness?.let { saved -> window.attributes = window.attributes.apply { screenBrightness = saved } }; oldBrightness = null
    }
    override fun onResume() { super.onResume(); callGate.setResumed(true) }
    override fun onPause() { callGate.setResumed(false); stopAlarm(); super.onPause() }
    override fun onStop() { stopAlarm(); callGate.setResumed(false); super.onStop() }
    override fun onDestroy() {
        stopAlarm(); callGate.setResumed(false)
        screenResult?.error("activity_destroyed", "Activity destroyed", null); screenResult = null
        permissionResult?.error("activity_destroyed", "Activity destroyed", null); permissionResult = null
        ScreenBufferService.onStarted?.invoke("Activity destroyed"); ScreenBufferService.onStarted = null
        ScreenBufferService.instance?.stop("activity_destroyed")
        super.onDestroy()
    }
}
