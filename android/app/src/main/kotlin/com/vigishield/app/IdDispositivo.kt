package com.vigishield.app

import android.annotation.SuppressLint
import android.content.Context
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Identificador estable del teléfono (ANDROID_ID): no cambia al reinstalar la
 * app ni al crear otra cuenta. El administrador lo usa para bloquear un
 * teléfono que abusa del servidor de cámaras con varias cuentas.
 */
object IdDispositivo {
    @SuppressLint("HardwareIds")
    fun conectar(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "vigishield/dispositivo").setMethodCallHandler { call, result ->
            if (call.method == "id") {
                result.success(Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID))
            } else {
                result.notImplemented()
            }
        }
    }
}
