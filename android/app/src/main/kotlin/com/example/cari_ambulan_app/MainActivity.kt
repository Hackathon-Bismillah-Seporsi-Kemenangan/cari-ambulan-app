package com.example.cari_ambulan_app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
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

    override fun onDestroy() {
        stopSiren()
        super.onDestroy()
    }
}
