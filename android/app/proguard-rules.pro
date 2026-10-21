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

# Kotlin classes that Pigeon's native interop (JNI) looks up by name.
#
# shared_preferences_android 2.5.0 talks to its Kotlin code through JNI, so the
# Dart side resolves the method descriptor at runtime. R8 renamed
# kotlin.coroutines.Continuation (and the classes below), which rewrote the
# descriptor of SharedPreferencesApiRegistrar.getAll to a name that no longer
# exists. Every call to SharedPreferences.getInstance() then failed with
# NoSuchMethodError, which aborted Supabase's initialisation and left the app
# with no backend at all ("the service is unavailable" on sign-in).
#
# Debug and profile builds are unaffected because R8 only runs on release.
# These are the rules from step 5 of Pigeon's native interop guide:
# https://github.com/flutter/packages/blob/main/packages/pigeon/native_interop_guide.md#step-5-android-release-build-configuration-jni
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
