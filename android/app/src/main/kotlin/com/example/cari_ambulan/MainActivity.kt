package com.example.cari_ambulan

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var siren: MediaPlayer? = null

    /** Alarm volume before the siren raised it, restored on stop. */
    private var savedAlarmVolume: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Used by EmergencyAlert (lib/core/alerts/emergency_alert.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cari_ambulan/ringtone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        playSiren()
                        result.success(null)
                    }
                    "stop" -> {
                        stopSiren()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Used by MapTiles (lib/core/map/map_tiles.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cari_ambulan/assets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "location" -> result.success(assetLocation(call.arguments as String))
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Where a Flutter asset's bytes sit inside the installed APK, so Dart can
     * read it in place instead of copying it out. Only works for assets
     * stored uncompressed (`noCompress` in build.gradle.kts); null otherwise.
     */
    private fun assetLocation(asset: String): Map<String, Any>? {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        return try {
            assets.openFd(key).use { fd ->
                mapOf(
                    "path" to applicationInfo.sourceDir,
                    "offset" to fd.startOffset,
                    "length" to fd.length,
                )
            }
        } catch (_: java.io.IOException) {
            null
        }
    }

    /**
     * Loops the siren (res/raw/emergency_siren.wav) on the alarm stream at full
     * volume, so an emergency order is heard even when the phone is on silent.
     */
    private fun playSiren() {
        stopSiren()
        raiseAlarmVolume()
        siren = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            setDataSource(
                this@MainActivity,
                Uri.parse("android.resource://$packageName/${R.raw.emergency_siren}"),
            )
            isLooping = true
            setVolume(1f, 1f)
            prepare()
            start()
        }
    }

    private fun stopSiren() {
        siren?.run {
            stop()
            release()
        }
        siren = null
        restoreAlarmVolume()
    }

    private fun raiseAlarmVolume() {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (savedAlarmVolume == null) {
            savedAlarmVolume = audio.getStreamVolume(AudioManager.STREAM_ALARM)
        }
        try {
            audio.setStreamVolume(
                AudioManager.STREAM_ALARM,
                audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0,
            )
        } catch (_: SecurityException) {
            // Do Not Disturb can block volume changes; play at the current level.
        }
    }

    private fun restoreAlarmVolume() {
        val volume = savedAlarmVolume ?: return
        savedAlarmVolume = null
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        try {
            audio.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
        } catch (_: SecurityException) {
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
    }

    /**
     * The ringing notification's full-screen intent lands here when the app is
     * already the top activity of a locked phone: Android doesn't turn the
     * screen on for that, so do it like an incoming call does.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreen()
    }

    @Suppress("DEPRECATION")
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            power.newWakeLock(
                PowerManager.FULL_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                "cari_ambulan:incoming_call",
            ).acquire(15_000L)
        } catch (_: Exception) {
            // The screen just stays as it is.
        }
    }

    override fun onDestroy() {
        stopSiren()
        super.onDestroy()
    }
}
