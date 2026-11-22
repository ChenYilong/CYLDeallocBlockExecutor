plugins {
    id("com.android.library")
}

android {
    namespace = "com.chenyilong.cyldeallocblockexecutor.binding"
    compileSdk = 36

    defaultConfig {
        minSdk = 21
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all { it.useJUnit() }
        }
    }
}

dependencies {
    api(project(":core"))
    implementation("androidx.fragment:fragment:1.8.9")
    implementation("androidx.core:core:1.17.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.16")
    testImplementation("androidx.test:core:1.7.0")
    testImplementation("androidx.test.ext:junit:1.3.0")
}
