plugins {
    id("com.android.application") version "9.0.1"
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.21"
}
android {
    namespace = "tools.studio.agent.android"
    compileSdk = 37
    defaultConfig {
        applicationId = "tools.studio.agent.android"
        minSdk = 31
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0-dev"
        ndk { abiFilters += "arm64-v8a" }
    }
    buildFeatures { compose = true }
    sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/modelAssets"))
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }
}
dependencies {
    implementation(project(":core"))
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation(platform("androidx.compose:compose-bom:2026.02.00"))
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("com.google.ai.edge.litertlm:litertlm-android:0.18.0")
}

val syncResearchCatalogue by tasks.registering(Copy::class) {
    from(rootProject.file("../research/android-first/model-candidates.json"))
    into(layout.buildDirectory.dir("generated/modelAssets"))
}
tasks.named("preBuild") { dependsOn(syncResearchCatalogue) }
