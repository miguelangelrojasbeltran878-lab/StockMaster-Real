pluginManagement {
    val localPropertiesFile = File(settingsDir, "local.properties")
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        if (localPropertiesFile.exists()) {
            localPropertiesFile.reader(Charsets.UTF_8).use { properties.load(it) }
        }
        val sdkPath = properties.getProperty("flutter.sdk")
        requireNotNull(sdkPath) { "Flutter SDK not found. Define location with flutter.sdk in local.properties." }
        sdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") } // 🔴 Esto repara el enlace de FlutterActivity
        gradlePluginPortal()
    }
}

plugins {
    
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("com.google.gms.google-services") version "4.4.1" apply false

}

include(":app")
