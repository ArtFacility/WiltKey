package com.wiltkey.wiltkey_client

import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Play-flavor MainActivity. Lives in src/play/, so it REPLACES the base
 * src/main/ MainActivity for Play builds only; the FOSS build uses the plain one
 * and never references Firebase.
 *
 * Extends SecureFlutterActivity (src/main/) to inherit the shared hardening
 * (FLAG_SECURE, anti-tapjacking, the wiltkey/security channel) and adds the
 * `wiltkey/push` MethodChannel the Dart side uses to fetch/clear the FCM token
 * and to pick up the chat a tapped FCM notification targeted.
 */
class MainActivity : SecureFlutterActivity() {

    // Set from the launch/tap intent extra; consumed once by takePendingChat.
    private var pendingChat: String? = null

    // Google Play Billing bridge (wiltkey/billing). Play-flavor only; the FOSS
    // MainActivity has no equivalent and the FOSS Dart side no-ops.
    private var billingBridge: BillingBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capturePendingChat(intent)
    }

    override fun onNewIntent(@NonNull intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePendingChat(intent)
    }

    private fun capturePendingChat(intent: Intent?) {
        val key = intent?.getStringExtra(WiltkeyFirebaseService.EXTRA_PENDING_CHAT)
        if (!key.isNullOrEmpty()) pendingChat = key
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Stand up the Play Billing bridge (wiltkey/billing) alongside the push channel.
        billingBridge = BillingBridge(this, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wiltkey/push")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getToken" -> {
                        FirebaseMessaging.getInstance().token
                            .addOnCompleteListener { task ->
                                if (task.isSuccessful) {
                                    result.success(task.result)
                                } else {
                                    result.success(null)
                                }
                            }
                    }
                    "deleteToken" -> {
                        FirebaseMessaging.getInstance().deleteToken()
                            .addOnCompleteListener { result.success(null) }
                    }
                    "takePendingChat" -> {
                        val key = pendingChat
                        pendingChat = null
                        result.success(key)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        billingBridge?.dispose()
        billingBridge = null
        super.onDestroy()
    }
}
