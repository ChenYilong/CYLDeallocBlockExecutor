plugins {
    kotlin("jvm")
    `maven-publish`
}

group = "com.github.ChenYilong"
version = System.getenv("VERSION") ?: "1.4.0"

java { withSourcesJar() }

publishing {
    publications {
        create<MavenPublication>("core") {
            artifactId = "cyl-dealloc-block-executor-core"
            from(components["java"])
        }
    }
}

repositories {
    mavenCentral()
}

dependencies {
    testImplementation(kotlin("test"))
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "failed", "skipped")
        showStandardStreams = false
    }
}

// Consumers (CYLTabBarController's Android core) build with Kotlin 2.0.x and lock kotlin-stdlib 2.0.21: compile for the 2.0 language
// and API level and depend on the 2.0.21 standard library, so the published POM and the class metadata stay readable for them.
kotlin {
    coreLibrariesVersion = "2.0.21"
    compilerOptions {
        languageVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
        apiVersion.set(org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_0)
    }
}
