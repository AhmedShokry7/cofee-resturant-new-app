# Glide (used by Tap Payments Card-Android for the NFC gif)
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep public class com.bumptech.glide.load.resource.gif.GifDrawable { *; }
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**
