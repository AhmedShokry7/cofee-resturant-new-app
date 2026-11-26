allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// The Firebase BoM version used by the FlutterFire plugins.
//
// firebase_core and the other Firebase plugins import the BoM themselves
// (see firebase_core/android/build.gradle), so the version is set here once
// instead of being repeated as a `platform(...)` dependency in the app
// module. Every native Firebase library in the app then resolves to the same
// BoM.
ext {
    set("FirebaseSDKVersion", "35.0.2")
    set("FlutterFire", mapOf("FirebaseSDKVersion" to "35.0.2"))
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Keep Android library plugins aligned with the SDK required by the app's
// resolved AndroidX dependencies (some Flutter plugins still declare API 33).
subprojects {
    afterEvaluate {
        val androidExtension = extensions.findByName("android") ?: return@afterEvaluate
        val compileSdkSetter = androidExtension.javaClass.methods.firstOrNull {
            it.name in setOf("setCompileSdkVersion", "compileSdkVersion") &&
                it.parameterCount == 1 &&
                (it.parameterTypes[0] == Int::class.javaPrimitiveType ||
                    it.parameterTypes[0] == Int::class.javaObjectType)
        }
        compileSdkSetter?.invoke(androidExtension, 36)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
