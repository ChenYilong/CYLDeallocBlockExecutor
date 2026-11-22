plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    `maven-publish`
}

// JitPack passes the commit or tag in VERSION. JitPack 通过 VERSION 传入提交号或标签。
group = "com.github.ChenYilong"
version = System.getenv("VERSION") ?: "1.4.0"

android {
    namespace = "com.cyl.deallocblockexecutor"
    compileSdk = 35

    defaultConfig {
        // Same as CYLTabBarController's Android core.
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }

    testOptions {
        // android.os.Looper and friends answer with defaults on the JVM; the tests need no emulator.
        unitTests.isReturnDefaultValues = true
    }
}

dependencies {
    api(libs.androidx.lifecycle.common)
    implementation(libs.androidx.lifecycle.runtime)
    testImplementation(libs.junit)
    testImplementation(libs.androidx.lifecycle.runtime.testing)
    testImplementation(libs.kotlinx.coroutines.core)
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                groupId = "com.github.ChenYilong"
                artifactId = "CYLDeallocBlockExecutor"
                from(components["release"])
            }
        }
    }
}
