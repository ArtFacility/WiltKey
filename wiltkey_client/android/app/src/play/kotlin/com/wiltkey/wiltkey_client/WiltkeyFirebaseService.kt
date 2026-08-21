package com.wiltkey.wiltkey_client

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Play-flavor FCM receiver. This file is ONLY compiled into the Play build (it
 * lives in src/play/), so the FOSS build never references Firebase.
 *
 * The relay sends a content-free, data-only ping (no "notification" payload), so
 * Android hands it here even in the background. We post our OWN generic
 * notification — no message content ever comes through Google; the encrypted
 * payload is still sitting on the relay and gets pulled when the app next
 * connects. The only datum carried is `sender_id` (already a one-way key hash),
 * used purely to deep-link on tap.
 */
class WiltkeyFirebaseService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // The Dart side re-reads the current token via the push MethodChannel on
        // every relay (re)connect and re-registers it, so a rotated token is
        // picked up automatically — nothing to push here.
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val senderId = remoteMessage.data["sender_id"]
        val contentType = remoteMessage.data["content_type"]
        showMessageNotification(applicationContext, senderId, contentType)
    }

    companion object {
        // Must match the Dart side: kMsgChannelId / kMsgNotificationId in
        // notification_service.dart, so this notification collapses with (and is
        // cancelled alongside) the flutter_local_notifications one.
        const val CHANNEL_ID = "wk_messages"
        const val NOTIFICATION_ID = 1
        const val EXTRA_PENDING_CHAT = "wk_pending_chat"

        fun showMessageNotification(
            context: Context,
            senderId: String?,
            contentType: String?,
        ) {
            if (!senderId.isNullOrEmpty()) {
                try {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    if (contentType == "group_message") {
                        val mutedGroupMembersRaw = prefs.getString("flutter.wk_muted_group_members", null)
                        val mutedGroupMembersSet = try { prefs.getStringSet("flutter.wk_muted_group_members", null) } catch (_: Exception) { null }
                        if ((mutedGroupMembersRaw != null && mutedGroupMembersRaw.contains(senderId)) ||
                            (mutedGroupMembersSet != null && mutedGroupMembersSet.contains(senderId))) {
                            return
                        }
                    } else {
                        val mutedRaw = prefs.getString("flutter.wk_muted_chats", null)
                        val mutedSet = try { prefs.getStringSet("flutter.wk_muted_chats", null) } catch (_: Exception) { null }
                        if ((mutedRaw != null && mutedRaw.contains(senderId)) ||
                            (mutedSet != null && mutedSet.contains(senderId))) {
                            return
                        }
                    }
                } catch (_: Exception) {}
            }

            ensureChannel(context)

            // Tap → launch MainActivity carrying the target chat so the app can
            // deep-link (mirrors the flutter_local_notifications payload path).
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                if (!senderId.isNullOrEmpty()) putExtra(EXTRA_PENDING_CHAT, senderId)
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

            val text = if (contentType == "emergency_chat") {
                "Emergency chat request"
            } else {
                "New secure message"
            }

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_notif)
                .setContentTitle("Wiltkey")
                // Content-free by design — the message stays encrypted on the relay
                // until the device unlocks and pulls it.
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pending)
                .build()

            try {
                NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
            } catch (_: SecurityException) {
                // POST_NOTIFICATIONS not granted (Android 13+) — nothing to show.
            }
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Messages",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "New secure message alerts" }
            manager.createNotificationChannel(channel)
        }
    }
}
