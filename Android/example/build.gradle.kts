plugins {
    id("com.android.application")
    kotlin("android")
}

android {
    namespace = "com.chenyilong.cyldeallocblockexecutor.example"
    compileSdk = 35
    defaultConfig {
        applicationId = "com.chenyilong.cyldeallocblockexecutor.example"
        minSdk = 21
        targetSdk = 35
        versionCode = 1
        versionName = "1.4.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }

dependencies {
    implementation(project(":binding"))
    implementation("androidx.recyclerview:recyclerview:1.3.2")
}
