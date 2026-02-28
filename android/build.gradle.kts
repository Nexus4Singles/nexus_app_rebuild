allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Suppress obsolete Java version warnings for all plugins
    afterEvaluate {
        if (project.plugins.hasPlugin("java")) {
            tasks.withType<JavaCompile> {
                options.compilerArgs.add("-Xlint:-options")
                options.compilerArgs.add("-Xlint:-unchecked")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
