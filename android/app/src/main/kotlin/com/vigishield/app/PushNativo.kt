package com.vigishield.app

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Notificaciones push en Android, por FCM (Firebase Cloud Messaging).
 *
 * Canal "vigishield/push" con Dart:
 * - token: el token de FCM de este teléfono (null si Firebase no está
 *   configurado: falta google-services.json).
 * - eventoInicial: el evento de la notificación que abrió la app, si hubo.
 * - Hacia Dart: tokenRenovado(token) y abrirEvento(id).
 *
 * El permiso de Android 13+ lo pide Dart con permission_handler.
 */
object PushNativo {
    const val CANAL_ALERTAS = "alertas"
    private const val EXTRA_EVENTO = "eventId"

    private var canal: MethodChannel? = null
    private var contexto: Context? = null
    private var eventoPendiente: String? = null
    private val principal = Handler(Looper.getMainLooper())

    fun conectar(activity: Activity, messenger: BinaryMessenger) {
        contexto = activity.applicationContext
        crearCanalDeAlertas(activity)
        tomarEvento(activity.intent)
        canal = MethodChannel(messenger, "vigishield/push").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "plataforma" -> result.success("android")
                    "entorno" -> result.success("produccion")
                    "token" -> pedirToken(result)
                    "eventoInicial" -> {
                        result.success(eventoPendiente)
                        eventoPendiente = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** La app ya estaba abierta y se tocó una notificación (onNewIntent). */
    fun alAbrir(intent: Intent?) {
        val id = tomarEvento(intent) ?: return
        canal?.invokeMethod("abrirEvento", id)
    }

    fun tokenRenovado(token: String) {
        principal.post { canal?.invokeMethod("tokenRenovado", token) }
    }

    private fun tomarEvento(intent: Intent?): String? {
        val id = intent?.getStringExtra(EXTRA_EVENTO) ?: return null
        // Para que no se vuelva a abrir el evento si la actividad se recrea.
        intent.removeExtra(EXTRA_EVENTO)
        eventoPendiente = id
        return id
    }

    private fun pedirToken(result: MethodChannel.Result) {
        val ctx = contexto
        try {
            if (ctx == null || FirebaseApp.getApps(ctx).isEmpty()) {
                result.success(null)
                return
            }
            FirebaseMessaging.getInstance().token.addOnCompleteListener { t ->
                if (t.isSuccessful) result.success(t.result)
                else result.error("token", t.exception?.message, null)
            }
        } catch (e: Exception) {
            result.success(null)
        }
    }

    /** Importancia alta: suena y aparece arriba de la pantalla. */
    fun crearCanalDeAlertas(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CANAL_ALERTAS) != null) return
        nm.createNotificationChannel(
            NotificationChannel(CANAL_ALERTAS, "Alertas de seguridad", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Personas desconocidas, merodeo, intrusión y otros eventos de tus cámaras."
                enableVibration(true)
            })
    }

    /**
     * Con la app en primer plano FCM no muestra la notificación: la mostramos
     * nosotros. En segundo plano la muestra el sistema con el canal "alertas".
     */
    fun mostrar(context: Context, titulo: String?, cuerpo: String?, eventId: String?) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        crearCanalDeAlertas(context)
        val abrir = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (eventId != null) putExtra(EXTRA_EVENTO, eventId)
        }
        val pendiente = PendingIntent.getActivity(
            context, (eventId ?: "vigishield").hashCode(), abrir,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notificacion = Notification.Builder(context, CANAL_ALERTAS)
            .setSmallIcon(R.drawable.ic_notificacion)
            .setColor(0xFF00C2FF.toInt())
            .setContentTitle(titulo)
            .setContentText(cuerpo)
            .setAutoCancel(true)
            .setContentIntent(pendiente)
            .build()
        context.getSystemService(NotificationManager::class.java)
            .notify((eventId ?: "vigishield").hashCode(), notificacion)
    }
}
