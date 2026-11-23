plugins {
    id("com.android.library")
    kotlin("android")
    `maven-publish`
}

// JitPack passes the commit or tag in VERSION.
group = "com.github.ChenYilong"
version = System.getenv("VERSION") ?: "1.4.0"

android {
    namespace = "com.chenyilong.cyldeallocblockexecutor.binding"
    compileSdk = 34
    defaultConfig { minSdk = 21 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    testOptions { unitTests.isIncludeAndroidResources = true }
    publishing { singleVariant("release") { withSourcesJar() } }
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                artifactId = "cyl-dealloc-block-executor-android"
                from(components["release"])
            }
        }
    }
}


dependencies {
    api(project(":core"))
    api("androidx.fragment:fragment:1.8.5")
    // Only for `observeScrolling(owner, recyclerView)`: an app that uses it already has RecyclerView.
    compileOnly("androidx.recyclerview:recyclerview:1.3.2")
    testImplementation("androidx.recyclerview:recyclerview:1.3.2")
    testImplementation(kotlin("test"))
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("androidx.test:core:1.6.1")
}

// Offline Robolectric: set CYL_ROBOLECTRIC_DIR to a folder holding the android-all jar
// (for example a mirror when Maven Central refuses the runtime download).
System.getenv("CYL_ROBOLECTRIC_DIR")?.let { dir ->
    tasks.withType<Test>().configureEach {
        systemProperty("robolectric.offline", "true")
        systemProperty("robolectric.dependency.dir", dir)
    }
}

// Consumers (CYLTabBarController's Android core) build with Kotlin 2.0.x and lock kotlin-stdlib 2.0.21: compile for the 2.0 language
// and API level and depend on the 2.0.21 standard library, so the published POM and the class metadata stay readable for them.
kotlin {
    coreLibrariesVersion = "2.0.21"
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
    }
}
