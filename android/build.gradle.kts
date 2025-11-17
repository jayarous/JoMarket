import com.android.build.gradle.BaseExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.api.provider.Provider
import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.jvm.toolchain.JavaCompiler
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.gradle.jvm.toolchain.JavaToolchainService
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.gradle.kotlin.dsl.getByType

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
subprojects {
    project.evaluationDependsOn(":app")
}

fun Project.configureRequestedToolchain() {
    val androidExtension = extensions.findByName("android") as? BaseExtension ?: return
    val configureAction = {
        val requestedTarget = androidExtension.compileOptions.targetCompatibility
        val targetMajor = requestedTarget.majorVersion.substringAfterLast('.').toInt()
        val requestedLanguageVersion = JavaLanguageVersion.of(targetMajor)

        val toolchains = extensions.getByType<JavaToolchainService>()
        val compiler: Provider<JavaCompiler> = toolchains.compilerFor {
            languageVersion.set(requestedLanguageVersion)
        }

        tasks.withType(JavaCompile::class.java).configureEach {
            if (!javaCompiler.isPresent) {
                javaCompiler.set(compiler)
            }
        }

        val currentProject = this
        plugins.withId("org.jetbrains.kotlin.android") {
            currentProject.extensions.configure<KotlinAndroidProjectExtension>("kotlin") {
                try {
                    jvmToolchain(targetMajor)
                } catch (ex: IllegalStateException) {
                    currentProject.logger.info(
                        "Skipping Kotlin jvmToolchain override for ${currentProject.path}: ${ex.message}"
                    )
                }
            }
        }
    }
    if (state.executed) {
        configureAction()
    } else {
        afterEvaluate { configureAction() }
    }
}

subprojects {
    plugins.withId("com.android.application") {
        project.configureRequestedToolchain()
    }
    plugins.withId("com.android.library") {
        project.configureRequestedToolchain()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Add Google services classpath for Firebase plugins
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}
