# WebRTC (LiveKit voice calls) is called from native code by name.
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**
