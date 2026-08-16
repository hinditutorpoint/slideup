import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Fallback keystore used ONLY when no release keystore credentials are
// provided (e.g. CI runs without secrets). It is generated into the build
// directory, is never committed, and simply lets `validateSigningRelease`
// succeed so the APK/AAB can be produced. It is NOT a production key.
val generatedKeystore = rootProject.layout.buildDirectory.file("slideup-release-keystore.jks")

val generateFallbackKeystore = tasks.register("generateFallbackKeystore") {
    val keystoreFile = generatedKeystore.get().asFile
    outputs.file(keystoreFile)
    onlyIf { !keystoreFile.exists() }
    doLast {
        keystoreFile.parentFile.mkdirs()
        project.exec {
            commandLine(
                "keytool",
                "-genkeypair", "-v",
                "-keystore", keystoreFile.absolutePath,
                "-storepass", "slideup-release",
                "-keypass", "slideup-release",
                "-alias", "slideup-release",
                "-keyalg", "RSA",
                "-keysize", "2048",
                "-validity", "10000",
                "-dname", "CN=SlideUp CI,O=SlideUp,C=US",
            )
        }
    }
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
                // CI fallback: generate a throwaway keystore into the build dir
                // instead of signing with the system debug config (which does
                // not exist on fresh runners and breaks validateSigningRelease).
                val fallback = generatedKeystore.get().asFile
                storeFile = fallback
                storePassword = "slideup-release"
                keyAlias = "slideup-release"
                keyPassword = "slideup-release"
                tasks.named("validateSigningRelease").configure {
                    dependsOn(generateFallbackKeystore)
                }
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
