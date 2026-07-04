import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (gitignored). When that file
// is absent (e.g. a fresh clone, CI), the build falls back to the debug key so
// `flutter run` still works — only Play uploads need the real release key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.wiltkey.wiltkey_client"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Must match the package name registered in the Play Console. This is the
        // app's permanent identity on Play and can't change after publishing.
        // (The Kotlin source `namespace` below stays com.wiltkey.wiltkey_client —
        // that's internal only and doesn't need to match the applicationId.)
        applicationId = "xyz.artfacility.wiltkey"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dual-flavor distribution (see documentation/Notif_Fragmenting.md):
    //   • play — Google Play build. Keeps the canonical applicationId so it stays
    //     the SAME Play listing (internal testing / verification unaffected).
    //     Compiles in Firebase Cloud Messaging for a battery-light wake-up ping.
    //   • foss — GitHub/website build. Gets the .foss applicationId suffix so it's
    //     a distinct installable, and pulls in ZERO Google Play Services code.
    // Flutter requires a flavor to be named on build/run, e.g.:
    //   flutter run   --flavor foss  --dart-define=WK_FCM=false
    //   flutter build appbundle --flavor play --dart-define=WK_FCM=true
    flavorDimensions += "distribution"
    productFlavors {
        create("play") {
            dimension = "distribution"
            // No applicationIdSuffix: this IS xyz.artfacility.wiltkey.
        }
        create("foss") {
            dimension = "distribution"
            applicationIdSuffix = ".foss"
            versionNameSuffix = "-foss"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real release/upload key when android/key.properties is present,
            // otherwise the debug key (keeps `flutter run` working without it).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 obfuscation was renaming/stripping reflectively-instantiated classes
            // (e.g. androidx.work's WorkDatabase_Impl via WorkManagerInitializer),
            // crashing the app on startup. Disabled for test builds; revisit with
            // targeted keep rules before a Play Store release.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase Cloud Messaging — compiled into the PLAY flavor ONLY (via the
    // flavor-scoped `playImplementation` configuration). The FOSS build never sees
    // these artifacts, so it ships free of Google Play Services. The native FCM
    // service + push MethodChannel live under src/play/ to match.
    "playImplementation"(platform("com.google.firebase:firebase-bom:33.5.1"))
    "playImplementation"("com.google.firebase:firebase-messaging")
}

// Apply the Google Services plugin ONLY when building the Play flavor. It requires
// google-services.json and would fail the Google-free FOSS build, so we gate it on
// the requested task name containing "Play" (Gradle configures plugins before it
// knows the active flavor, so a task-name check is the standard workaround).
if (gradle.startParameter.taskRequests.toString().contains("Play", ignoreCase = true)) {
    apply(plugin = "com.google.gms.google-services")
}
