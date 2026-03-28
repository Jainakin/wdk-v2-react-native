plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.facebook.react")
}

android {
    namespace = "com.tetherto.wdk.reactnative"
    compileSdk = 34

    defaultConfig {
        minSdk = 24
        targetSdk = 34
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    // The React Native Gradle plugin will add codegen-generated sources
    // to the build automatically based on the codegenConfig in package.json.
}

dependencies {
    implementation("com.facebook.react:react-android:+")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
