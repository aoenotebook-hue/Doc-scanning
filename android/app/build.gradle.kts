plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("dev.flutter.flutter-gradle-plugin") }
android { namespace="app.scanandopen"; compileSdk=35
  defaultConfig { applicationId="app.scanandopen"; minSdk=23; targetSdk=35; versionCode=1; versionName="1.0.0" }
  compileOptions { sourceCompatibility=JavaVersion.VERSION_17; targetCompatibility=JavaVersion.VERSION_17 }
kotlinOptions { jvmTarget="17" }
}
flutter { source="../.." }
dependencies { implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1") }
