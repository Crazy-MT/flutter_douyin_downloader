import com.android.build.gradle.LibraryExtension
import org.gradle.api.Action
import org.gradle.api.Plugin
import org.gradle.api.plugins.ExtensionAware

allprojects {
    repositories {
        google()
        mavenCentral()
//        // 国内镜像源
//        maven { url = uri("https://maven.aliyun.com/repository/google") }
//        maven { url = uri("https://maven.aliyun.com/repository/central") }
//        maven { url = uri("https://maven.aliyun.com/repository/public") }
    }
}

class FlutterGalCompat {
    val compileSdkVersion: Int get() = 34
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    if (project.name == "gal") {
        project.plugins.withId("com.android.library", Action<Plugin<*>> {
            val android = project.extensions.getByType(LibraryExtension::class.java) as ExtensionAware
            android.extensions.add("flutter", FlutterGalCompat())
        })
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
