import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

/** Busca el keystore relativo a `android/app/` y luego a `android/`. */
fun resolveKeystore(path: String) =
    listOf(file(path), rootProject.file(path)).firstOrNull { it.exists() }

val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
    ?.let(::resolveKeystore)

/**
 * Solo se firma con la clave de release si `android/key.properties` existe y
 * apunta a un keystore válido. De lo contrario, el build de release usa la
 * clave de debug para que `flutter build apk --release` no falle en máquinas
 * sin credenciales (por ejemplo, CI). Un APK firmado con debug sirve para
 * probar, pero no para publicar en Google Play.
 */
val canSignRelease = releaseStoreFile != null &&
    !keystoreProperties.getProperty("storePassword").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
    !keystoreProperties.getProperty("keyPassword").isNullOrBlank()

android {
    namespace = "app.staydoct.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.staydoct.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Google Maps para Flutter Android. Se pasa en el build:
        //   flutter run -PGOOGLE_MAPS_API_KEY=...
        manifestPlaceholders["mapsApiKey"] =
            (project.findProperty("GOOGLE_MAPS_API_KEY") as String?) ?: ""
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (canSignRelease) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (canSignRelease) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Staydoct: no hay android/key.properties válido. " +
                        "El APK de release se firmará con la clave de DEBUG " +
                        "(apto para pruebas, no para Google Play).",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
