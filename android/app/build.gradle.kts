import java.io.ByteArrayInputStream
import java.io.FileInputStream
import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.X509Certificate
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Turns android/app/google-services.json into Firebase resources. It needs
    // the plugin to run after com.android.application, because it reads the
    // applicationId to pick the matching client out of the JSON file.
    id("com.google.gms.google-services")
}

// Release signing.
//
// The keystore lives in android/key.properties, which is deliberately not
// committed. When the file is missing the release build falls back to the
// debug key and says so loudly: a debug-signed APK installs fine but cannot
// be published, and replacing it later with a properly signed build fails
// with a signature mismatch unless the app is uninstalled first.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Icon tree shaking is switched off for every build.
//
// The const-finder tool that ships with the current Flutter SDK crashes on
// this project with "IconTreeShakerException: ConstFinder failure: Reference
// to dart:core::Object is not bound to an AST node", which aborts release and
// profile builds. It is a toolchain bug (dart-lang/sdk#55111) and it cannot be
// fixed from the application code.
//
// The Flutter Gradle plugin reads this flag, so setting it here keeps
// `flutter build apk --release` working without having to remember
// `--no-tree-shake-icons`. The cost is a larger icon font inside the APK.
project.ext.set("tree-shake-icons", "false")

android {
    // The namespace is the package the R class and the generated resources
    // live in. It is kept identical to the applicationId below, and to the
    // package name the Firebase console knows this app by, so the
    // google-services plugin finds the matching client in google-services.json
    // and nothing has to be translated between the two.
    namespace = "com.example.new_coffee"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.new_coffee"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/key.properties is missing, so the release " +
                        "build is signed with the debug key. It cannot be " +
                        "published to a store. See android/key.properties.example.",
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// The package name the release build is installed under. Google matches an
// Android OAuth client against it together with the certificate fingerprint.
val releaseApplicationId: String = android.defaultConfig.applicationId ?: ""

// Prints the fingerprint of every certificate a build of this app can be
// signed with.
//
// Google binds an Android OAuth client to one certificate. An app signed with
// a certificate whose SHA-1 was never registered fails on a real device with
// "clientConfigurationError", while the debug build - a different certificate -
// keeps working. That is why Google Sign-In can work in debug and break in
// release, and it is why the fingerprint that has to be registered must never
// be guessed.
//
// The task runs as part of every release build and prints the SHA-1 and
// SHA-256 of both the debug and the release certificate. It can also be run on
// its own with `./gradlew :app:printSigningFingerprints`.
val printSigningFingerprints by tasks.registering {
    group = "signing"
    description =
        "Prints the SHA-1/SHA-256 fingerprints of the debug and release signing certificates."
    doLast {
        // The debug certificate is the one an emulator or a test phone is
        // actually handed, so it is the first SHA-1 a developer has to register.
        // The Android Gradle Plugin owns that keystore, so its configured values
        // are read rather than a guessed path.
        val debug = android.signingConfigs.findByName("debug")
        val debugStore = debug?.storeFile
        val printed = mutableMapOf<String, String>()
        if (debugStore != null) {
            printFingerprint(
                label = "Debug signing certificate",
                store = debugStore,
                password = debug.storePassword ?: "android",
                alias = debug.keyAlias ?: "androiddebugkey",
            )?.let { printed["debug"] = it }
        } else {
            logger.warn(
                "The debug signing configuration has no keystore, so the debug " +
                    "fingerprint could not be printed.",
            )
        }

        if (!hasReleaseKeystore) {
            logger.warn(
                "android/key.properties is missing: the release build is signed " +
                    "with the debug key, so there is no separate release " +
                    "fingerprint to register.",
            )
        } else {
            printFingerprint(
                label = "Release signing certificate",
                store = file(keystoreProperties["storeFile"] as String),
                password = keystoreProperties["storePassword"] as String,
                alias = keystoreProperties["keyAlias"] as String,
            )?.let { printed["release"] = it }
        }

        checkFingerprintsAgainstRecord(printed)
    }
}

/// Compares the fingerprints just read from the real keystores with the record
/// the config checker and the suite trust.
///
/// A keystore that is renewed without re-registering its SHA-1 in Google Cloud
/// produces the same `[16] Account reauth failed` as a never-registered one, and
/// only this comparison notices. Warns, never fails: printing a fingerprint is
/// also the step taken *before* the console entry exists.
fun checkFingerprintsAgainstRecord(printed: Map<String, String>) {
    val record = rootDir.parentFile.resolve("tool/google_sign_in_setup.json")
    if (!record.exists()) {
        logger.warn(
            "${record.path} is missing, so the printed fingerprints cannot be " +
                "compared with what the sign-in check trusts.",
        )
        return
    }
    val entries =
        Regex(
            """"kind"\s*:\s*"([^"]+)"\s*,\s*"subject"\s*:\s*"[^"]*"\s*,\s*"sha1"\s*:\s*"([^"]+)""",
        ).findAll(record.readText())
    if (entries.none()) {
        logger.warn(
            "No signingCertificates entries were readable in ${record.path}.",
        )
        return
    }
    for (entry in entries) {
        val kind = entry.groupValues[1]
        val recorded = entry.groupValues[2]
        val actual = printed[kind]
        when {
            actual == null -> logger.warn(
                "The record lists a $kind certificate, but this build prints no " +
                    "$kind fingerprint.",
            )

            actual.equals(recorded, ignoreCase = true) -> logger.lifecycle(
                "  $kind SHA-1 MATCHES ${record.name}.",
            )

            else -> logger.warn(
                "The $kind SHA-1 DOES NOT MATCH ${record.name}: recorded " +
                    "$recorded, the keystore says $actual. Register the new " +
                    "fingerprint in Google Cloud and update the record, or " +
                    "that build keeps being refused.",
            )
        }
    }
}

/// Reads the certificate of [alias] out of [store] and prints what Google needs.
///
/// Returns the SHA-1 so the task can compare it with the record in
/// `tool/google_sign_in_setup.json`. A fingerprint that cannot be printed is
/// reported and never breaks the build, so the answer is nullable.
fun printFingerprint(
    label: String,
    store: File,
    password: String,
    alias: String,
): String? {
    val bytes = runCatching { store.readBytes() }.getOrElse {
        logger.warn("Could not read the keystore at ${store.path}: $it")
        return null
    }
    // The keystore is JKS or PKCS12 depending on what keytool wrote it,
    // and both types are read through the same KeyStore API. The bytes
    // are read once and replayed for each attempt.
    val keyStore = listOf("JKS", "PKCS12").firstNotNullOfOrNull { type ->
        runCatching {
            KeyStore.getInstance(type).apply {
                load(ByteArrayInputStream(bytes), password.toCharArray())
            }
        }.getOrNull()
    }
    if (keyStore == null) {
        logger.warn("Could not open the keystore at ${store.path}.")
        return null
    }
    val certificate = keyStore.getCertificate(alias) as? X509Certificate
    if (certificate == null) {
        logger.warn("No certificate found for alias '$alias' in ${store.path}.")
        return null
    }
    val encoded = certificate.encoded
    fun fingerprint(algorithm: String): String =
        MessageDigest.getInstance(algorithm)
            .digest(encoded)
            .joinToString(":") { byte -> "%02X".format(byte) }
    val sha1 = fingerprint("SHA-1")
    logger.lifecycle("$label: ${certificate.subjectX500Principal.name}")
    logger.lifecycle("  SHA-1:   $sha1")
    logger.lifecycle("  SHA-256: ${fingerprint("SHA-256")}")
    logger.lifecycle(
        "Register the SHA-1 above for package name " +
            "\"$releaseApplicationId\" in the Android OAuth client, or " +
            "Google Sign-In fails on a real device.",
    )
    return sha1
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(printSigningFingerprints)
}

dependencies {
    // card_flutter -> Card-Android (Tap Payments) uses Glide for the NFC gif.
    implementation("com.github.bumptech.glide:glide:4.16.0")
    annotationProcessor("com.github.bumptech.glide:compiler:4.16.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
