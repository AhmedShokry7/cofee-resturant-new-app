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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
