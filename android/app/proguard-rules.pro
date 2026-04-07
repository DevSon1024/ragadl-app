# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.devson.ragadl.** { *; }

# Jetpack Compose
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# Coil
-keep class coil.** { *; }
-dontwarn coil.**
# Ignore missing Play Core classes referenced by Flutter engine
-dontwarn com.google.android.play.core.**
# Kotlin Coroutines
-keepclassmembernames class kotlinx.** { *; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Material3
-keep class androidx.compose.material3.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
