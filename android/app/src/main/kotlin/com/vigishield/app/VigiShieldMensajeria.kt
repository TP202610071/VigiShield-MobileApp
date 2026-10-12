package com.vigishield.app

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Recibe los mensajes de FCM. En segundo plano el sistema muestra la
 * notificación solo; aquí llegan las que llegan con la app abierta.
 */
class VigiShieldMensajeria : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushNativo.tokenRenovado(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val n = message.notification ?: return
        PushNativo.mostrar(this, n.title, n.body, message.data["eventId"])
    }
}
