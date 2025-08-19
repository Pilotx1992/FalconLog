# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Google Sign-In classes
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Keep Hive classes (Flutter local database)
-keep class hive.** { *; }

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep native method names
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep all model classes (for JSON serialization)
-keep class **.models.** { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Don't obfuscate
-dontobfuscate

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}
