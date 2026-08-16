import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.slideup.mediaplayer"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    packaging {
        jniLibs {
            pickFirsts.add("**/libc++_shared.so")
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.slideup.mediaplayer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            val defaultKeyFile = file("my-release-key.keystore")
            val customKeystorePath = project.findProperty("MY_KEYSTORE") as String?
                ?: keystoreProperties.getProperty("storeFile")

            val resolvedStoreFile = when {
                !customKeystorePath.isNullOrEmpty() -> {
                    val f = File(customKeystorePath)
                    if (f.isAbsolute) f else rootProject.file(customKeystorePath)
                }
                defaultKeyFile.exists() -> defaultKeyFile
                else -> null
            }

            val sPassword = project.findProperty("MY_STORE_PASSWORD") as String?
                ?: keystoreProperties.getProperty("storePassword")
            val kAlias = project.findProperty("MY_KEY_ALIAS") as String?
                ?: keystoreProperties.getProperty("keyAlias")
            val kPassword = project.findProperty("MY_KEY_PASSWORD") as String?
                ?: keystoreProperties.getProperty("keyPassword")

            if (resolvedStoreFile != null && resolvedStoreFile.exists() && !sPassword.isNullOrEmpty() && !kAlias.isNullOrEmpty()) {
                storeFile = resolvedStoreFile
                storePassword = sPassword
                keyAlias = kAlias
                keyPassword = if (!kPassword.isNullOrEmpty()) kPassword else sPassword
            } else {
                // Fall back to debug signing config when release keystore credentials are not provided
                initWith(signingConfigs.getByName("debug"))
            }
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }

    dependencies {
        implementation("androidx.multidex:multidex:2.0.1")
        implementation("androidx.work:work-runtime-ktx:2.9.0")
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
}

flutter {
    source = "../.."
}
