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

    // Patch for Flutter dependencies that predate the AGP 8.x namespace requirement.
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<com.android.build.gradle.LibraryExtension> {
                if (namespace == null) {
                    val manifest = sourceSets.getByName("main").manifest.srcFile
                    if (manifest.exists()) {
                        val doc = javax.xml.parsers.DocumentBuilderFactory
                            .newInstance().newDocumentBuilder().parse(manifest)
                        val pkg = doc.documentElement.getAttribute("package")
                        if (pkg.isNotEmpty()) namespace = pkg
                    }
                }
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
