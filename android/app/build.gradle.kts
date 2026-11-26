import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes only from android/key.properties (docs/release/signing.md).
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.isFile) keyPropertiesFile.reader().use { load(it) }
}
fun signingValue(name: String): String? = keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
// A relative storeFile is resolved against android/.
val releaseStoreFile = signingValue("storeFile")?.let { rootProject.file(it) }
val signingProblem: String? = run {
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { signingValue(it) == null }
    when {
        !keyPropertiesFile.isFile -> "android/key.properties tidak ditemukan"
        missing.isNotEmpty() -> "android/key.properties belum lengkap: ${missing.joinToString()}"
        releaseStoreFile?.isFile != true -> "keystore di storeFile tidak ditemukan"
        else -> null
    }
}

android {
    namespace = "com.technowstack.nura"
    // flutter_local_notifications 23 requires compileSdk 37.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.technowstack.nura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
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
        create("release") {
            if (signingProblem == null) {
                storeFile = releaseStoreFile
                storePassword = signingValue("storePassword")
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // No debug-key fallback: see the task graph check below.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}

// Checked on the task graph so debug builds and tests need no keystore.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.project == project &&
            it.name in setOf("assembleRelease", "bundleRelease", "packageRelease", "packageReleaseBundle", "signReleaseBundle")
    }
    if (releaseRequested && signingProblem != null) {
        throw GradleException("$signingProblem: lihat docs/release/signing.md")
    }
}
