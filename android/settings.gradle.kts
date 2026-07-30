pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// US-173: this block was written as `dependencyResolution { ... }`, which is not
// a Gradle settings DSL method. Settings evaluation failed with an unresolved
// method, so no Android task could run at all. The correct name is
// `dependencyResolutionManagement`.
dependencyResolutionManagement {
    // Fail loudly if a build script ever declares its own repositories, rather
    // than silently resolving dependencies from an unreviewed source.
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Seddly"
include(":app")
