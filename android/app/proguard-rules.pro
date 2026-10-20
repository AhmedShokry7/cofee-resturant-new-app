# Glide (used by Tap Payments Card-Android for the NFC gif)
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep public class com.bumptech.glide.load.resource.gif.GifDrawable { *; }
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# The Tap Payments SDK is resolved by name at runtime, so R8 must not rename
# or strip it.
-keep class tap.company.** { *; }
-keep interface tap.company.** { *; }
-dontwarn tap.company.**

# Flutter plugins are registered from generated code, but several of them
# (Google Sign-In, image_picker, geolocator) also look their platform
# implementation up by name.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**

# Kotlin metadata is read reflectively by several libraries.
-keepattributes *Annotation*, InnerClasses, Signature, RuntimeVisible*Annotations, AnnotationDefault
