package com.wiltkey.wiltkey_client

// FOSS-flavor MainActivity. Lives in src/foss/ (NOT src/main/) because the Play
// flavor supplies its own MainActivity under src/play/ — a class of the same
// fully-qualified name can't exist in both `main` and a flavor source set
// (they're additive, so it would be a redeclaration). Plain: no Firebase.
//
// All the hardening (FLAG_SECURE, anti-tapjacking, the wiltkey/security channel)
// lives in the shared SecureFlutterActivity base in src/main/, so this is empty.
class MainActivity : SecureFlutterActivity()
