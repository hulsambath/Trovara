# ObjectBox ProGuard rules
-keep class com.trovara.models.** { *; }
-keep class io.objectbox.** { *; }
-keep enum io.objectbox.** { *; }
-keep interface io.objectbox.** { *; }

# Keep the generated ObjectBox classes
-keep class com.trovara.objectbox.** { *; }

# Firebase ProGuard rules (standard)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Easy Localization
-keep class com.easy_localization.** { *; }
