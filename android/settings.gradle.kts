pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        requireNotNull(properties.getProperty("flutter.sdk")) { "flutter.sdk not set in local.properties" }
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
plugins { id("dev.flutter.flutter-plugin-loader") version "1.0.0" }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "scan_and_open"
include(":app")
