package com.wiltkey.wiltkey_client

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// biometric prompt can attach to a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Hard-block screenshots and screen recording app-wide: FLAG_SECURE makes
        // the OS capture a blank frame and hides the app in the recents preview.
        //
        // Skipped for debuggable (debug) builds only, so we can capture screenshots
        // and screen recordings for documentation/store listings. Release builds are
        // never debuggable, so the block always applies to shipped APKs.
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        super.onCreate(savedInstanceState)
    }
}
