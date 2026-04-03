# Seddly ProGuard Rules

# Keep Room entities
-keep class com.pearsonmedia.seddly.data.local.entity.** { *; }

# Keep serialization classes
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.pearsonmedia.seddly.**$$serializer { *; }
-keepclassmembers class com.pearsonmedia.seddly.** {
    *** Companion;
}
-keepclasseswithmembers class com.pearsonmedia.seddly.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**

# ML Kit
-keep class com.google.mlkit.** { *; }
