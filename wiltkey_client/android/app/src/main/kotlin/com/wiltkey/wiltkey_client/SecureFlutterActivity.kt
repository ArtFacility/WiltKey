package com.wiltkey.wiltkey_client

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Shared secure host activity. Lives in src/main/ (NOT as `MainActivity`, which
 * each flavor supplies from its own source set — a same-named class can't exist
 * in both `main` and a flavor set). Both flavor MainActivities extend this so the
 * hardening lives in exactly one place.
 *
 * FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
 * biometric prompt can attach to a FragmentActivity host.
 *
 * Provides:
 *  - FLAG_SECURE (release builds only): the OS captures a blank frame for
 *    screenshots / screen recording / casting and blanks the Recents preview.
 *  - Anti-tapjacking: filterTouchesWhenObscured on the content root so taps are
 *    dropped while another app draws an overlay on top (helps pre-Android-12,
 *    where the OS doesn't block untrusted overlay touches by default).
 *  - The `wiltkey/security` MethodChannel used by the Dart SecurityService to
 *    surface a soft, informational warning when a third-party accessibility
 *    service is active.
 */
open class SecureFlutterActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Hard-block screenshots / screen recording / casting app-wide in shipped
        // builds. Skipped for debuggable (debug/profile) builds so dev runs can
        // still be captured for bug reports.
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            // NOTE: window.setHideOverlayWindows(true) was tried here but it
            // requires the privileged HIDE_OVERLAY_WINDOWS permission and throws
            // a SecurityException at launch for a normal app — do NOT re-add it.
            // Anti-tapjacking is covered by filterTouchesWhenObscured (onPostResume).
        }
        super.onCreate(savedInstanceState)
    }

    override fun onPostResume() {
        super.onPostResume()
        // Set here (not in configureFlutterEngine) because the Flutter view tree
        // is reliably attached by the time the activity has resumed. Dropping
        // touches while obscured is the core anti-tapjacking defence.
        findViewById<View>(android.R.id.content)?.rootView?.filterTouchesWhenObscured = true
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkUnsafeAccessibility" -> {
                        val am = getSystemService(Context.ACCESSIBILITY_SERVICE)
                                as AccessibilityManager
                        val enabled = am.getEnabledAccessibilityServiceList(
                            AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
                        )
                        val labels = ArrayList<String>()
                        for (service in enabled) {
                            val pkg = service.resolveInfo.serviceInfo.packageName
                            if (!TRUSTED_A11Y_PACKAGES.contains(pkg)) {
                                labels.add(
                                    service.resolveInfo.loadLabel(packageManager).toString(),
                                )
                            }
                        }
                        // Soft signal only: Dart decides how (and whether) to warn.
                        result.success(
                            mapOf("unsafe" to labels.isNotEmpty(), "labels" to labels),
                        )
                    }
                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val SECURITY_CHANNEL = "wiltkey/security"

        // System-trusted screen readers we never flag. Everything else (password
        // managers, clipboard tools, remappers, real spyware) is surfaced to the
        // user as an informational heads-up — never a hard block.
        private val TRUSTED_A11Y_PACKAGES = listOf(
            "com.google.android.marvin.talkback",
            "com.android.talkback",
            "com.samsung.android.accessibility.talkback",
        )
    }
}
