# just_audio / ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Flutter plugins general
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# record plugin
-keep class com.llfbandit.record.** { *; }

# camera plugin
-keep class io.flutter.plugins.camera.** { *; }
