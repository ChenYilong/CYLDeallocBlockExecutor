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
