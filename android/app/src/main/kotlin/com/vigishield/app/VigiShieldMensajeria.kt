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
        // Los avisos del panel traen su canal (e imagen); las alertas de la IA, no.
        if (message.data["canal"] != null) {
            PushNativo.mostrarMensaje(this, n.title, n.body, message.data,
                n.imageUrl?.toString() ?: message.data["imagen"])
        } else {
            PushNativo.mostrar(this, n.title, n.body, message.data["eventId"])
        }
    }
}
