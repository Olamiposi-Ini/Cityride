pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // FIX: Removed 'version "1.0.0"' to prevent the "already on the classpath" error
    id("dev.flutter.flutter-plugin-loader")
    
    // UPDATED: Use 8.11.1 for better Google Maps compatibility
    id("com.android.application") version "8.11.1" apply false
    
    // UPDATED: Use 2.2.20 to fix the Kotlin "Internal compiler error"
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")