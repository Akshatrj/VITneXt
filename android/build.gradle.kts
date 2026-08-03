allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

/**
 * file_picker hardcodes compileSdk 34, but flutter_plugin_android_lifecycle
 * requires consumers to compile against API 36+. Override after each plugin
 * finishes evaluating so their own android { compileSdk … } cannot win.
 */
fun org.gradle.api.Project.forceCompileSdk36() {
    extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let {
        it.compileSdk = 36
    }
    extensions.findByType(com.android.build.gradle.AppExtension::class.java)?.let {
        it.compileSdkVersion(36)
    }
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        // Early pass (may be overwritten by the plugin's own build.gradle).
        extensions.configure(com.android.build.gradle.LibraryExtension::class.java) {
            compileSdk = 36
        }
    }
    afterEvaluate {
        forceCompileSdk36()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
