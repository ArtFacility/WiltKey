package com.wiltkey.wiltkey_client

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
// Needed again when the FLAG_SECURE block in onCreate is re-enabled for release:
// import android.content.pm.ApplicationInfo
// import android.view.WindowManager

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so the
// biometric prompt can attach to a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Hard-block screenshots and screen recording app-wide: FLAG_SECURE makes
        // the OS capture a blank frame and hides the app in the recents preview.
        //
        // TEMPORARILY DISABLED for the closed-testing phase so testers can capture
        // screenshots / screen recordings to attach to bug reports. The block is
        // otherwise applied to every non-debuggable (release/testing) build.
        //
        // TODO(release): RE-ENABLE before the public release by uncommenting below.
        // val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        // if (!isDebuggable) {
        //     window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        // }
        super.onCreate(savedInstanceState)
    }
}
