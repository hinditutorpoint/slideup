allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        project.extensions.findByName("android")?.let { androidExt ->
            try {
                val namespace = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespace == null) {
                    val groupStr = project.group.toString()
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, groupStr)
                }
            } catch (e: Exception) {
                // Ignore reflection errors for non-matching AGP models
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
    tasks.matching { it.name.contains("Lint") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
