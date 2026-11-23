pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "cyl-dealloc-block-executor-android"
include(":core")

// `:binding` needs the Android SDK (AGP); without one, `:core:test` still runs.
val localProperties = file("local.properties")
val hasSdk = System.getenv("ANDROID_HOME") != null || System.getenv("ANDROID_SDK_ROOT") != null ||
    (localProperties.exists() && localProperties.readText().contains("sdk.dir"))
if (hasSdk) {
    include(":binding")
    include(":example") // a device check app: logs every event the binding fires
}
