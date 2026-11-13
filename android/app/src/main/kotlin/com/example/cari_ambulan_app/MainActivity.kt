package com.example.cari_ambulan_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.WindowManager
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

    private val mainHandler = Handler(Looper.getMainLooper())

    /** Hides from the lock screen again if Dart never takes over. */
    private val releaseLaunchHold = Runnable { setOverLockScreen(false) }

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
        // Used by LockScreen (lib/core/alerts/lock_screen.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cari_ambulan/lock_screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        mainHandler.removeCallbacks(releaseLaunchHold)
                        setOverLockScreen(true)
                        result.success(null)
                    }
                    "hide" -> {
                        mainHandler.removeCallbacks(releaseLaunchHold)
                        setOverLockScreen(false)
                        result.success(null)
                    }
                    // Android 14+ lets the user turn full-screen ringing off.
                    "canRing" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE ||
                            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                                .canUseFullScreenIntent(),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showIfRinging(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showIfRinging(intent)
    }

    /**
     * The ringing notification (EmergencyAlert, ids 1001 and 1002) opened the
     * app, maybe through its full-screen intent on a locked phone. Show over
     * the lock screen before Flutter has started; Dart takes over once it finds
     * the call or order, otherwise this lapses so the app never stays readable
     * on a locked phone.
     */
    private fun showIfRinging(intent: Intent?) {
        if (intent?.action != "SELECT_NOTIFICATION") return
        val id = intent.getIntExtra("notificationId", -1)
        if (id != 1001 && id != 1002) return
        setOverLockScreen(true)
        mainHandler.removeCallbacks(releaseLaunchHold)
        mainHandler.postDelayed(releaseLaunchHold, 30_000L)
    }

    /** Like an incoming phone call: over the lock screen, screen turned on. */
    @Suppress("DEPRECATION")
    private fun setOverLockScreen(show: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(show)
            setTurnScreenOn(show)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (show) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (show) wakeScreen()
    }

    /** setTurnScreenOn only acts when the activity is shown, not when it already is. */
    @Suppress("DEPRECATION")
    private fun wakeScreen() {
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (power.isInteractive) return
            power.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "cari_ambulan:ringing",
            ).acquire(10_000L)
        } catch (_: Exception) {
            // The screen stays as it is; the notification still rings.
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
        mainHandler.removeCallbacks(releaseLaunchHold)
        stopSiren()
        super.onDestroy()
    }
}
