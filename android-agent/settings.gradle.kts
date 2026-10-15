pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = "StudioAgent"
include(":core")
// Core builds without an Android SDK. Opt in to the native application explicitly.
if (providers.gradleProperty("android").orNull == "true") include(":app")
