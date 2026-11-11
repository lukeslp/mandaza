import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.compose")
    kotlin("plugin.serialization")
}

val signingValues = listOf(
    "MANDAZA_ANDROID_STORE_FILE",
    "MANDAZA_ANDROID_STORE_PASSWORD",
    "MANDAZA_ANDROID_KEY_ALIAS",
    "MANDAZA_ANDROID_KEY_PASSWORD",
).associateWith { providers.environmentVariable(it).orNull }
val hasReleaseSigning = signingValues.values.all { !it.isNullOrBlank() }

val marketingVersion = rootProject.file("../project.yml").readText()
    .let { Regex("""(?m)^[ \t]*MARKETING_VERSION:[ \t]*("?)([0-9]+(?:\.[0-9]+){0,2})\1[ \t]*(?:#.*)?$""").find(it)?.groupValues?.get(2) }
    ?: error("MARKETING_VERSION is missing or invalid in project.yml; refusing a fallback Android release version")
val androidPatchVersion = 3

android {
    namespace = "com.lukesteuber.mandaza"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.mandaza.android"
        minSdk = 24
        targetSdk = 36
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        versionCode = 10303
        versionName = "$marketingVersion.$androidPatchVersion"
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("direct") {
            dimension = "distribution"
            versionCode = 10310
            // Installed direct copies compare versionName with catalog.json, so a rebuild must raise it.
            versionName = "$marketingVersion.5"
        }
        create("play") {
            dimension = "distribution"
            versionCode = 10305
        }
        create("amazon") {
            dimension = "distribution"
            versionCode = 10308
        }
        create("fdroid") {
            dimension = "distribution"
            // Published F-Droid 1.3.6. Future phone codes must exceed all issued channel codes.
            versionCode = 10311
            versionName = "$marketingVersion.6"
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(signingValues.getValue("MANDAZA_ANDROID_STORE_FILE")!!)
                storePassword = signingValues.getValue("MANDAZA_ANDROID_STORE_PASSWORD")
                keyAlias = signingValues.getValue("MANDAZA_ANDROID_KEY_ALIAS")
                keyPassword = signingValues.getValue("MANDAZA_ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasReleaseSigning) signingConfig = signingConfigs.getByName("release")
        }
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin { compilerOptions { jvmTarget.set(JvmTarget.JVM_17) } }
    packaging { resources.excludes += "/META-INF/{AL2.0,LGPL2.1}" }
}

tasks.register("printVersion") {
    doLast { println(android.defaultConfig.versionName) }
}

dependencies {
    implementation(project(":core"))
    val composeBom = platform("androidx.compose:compose-bom:2025.10.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.4")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    add("playImplementation", "com.google.android.play:review:2.0.2")
    add("playImplementation", "com.google.android.play:review-ktx:2.0.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4-accessibility")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    // Compose otherwise selects Espresso 3.5, whose input reflection fails on Android 17.
    androidTestImplementation("androidx.test.espresso:espresso-core:3.7.0")
}
