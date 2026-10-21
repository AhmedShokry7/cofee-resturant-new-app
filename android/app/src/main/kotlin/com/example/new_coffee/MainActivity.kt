package com.example.new_coffee

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    /**
     * Creates the channel the push notifications are shown in.
     *
     * Android 8 and later need a channel before a notification can be shown,
     * and the channel decides how loud it is and which screen it belongs to.
     * The id is the one the push message asks for and the one the manifest
     * names as the default, so a notification that arrives while the app is
     * closed lands in this channel instead of a fallback one.
     *
     * Creating a channel twice is harmless: the second call only updates it.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.app_name),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        channel.description = getString(R.string.notification_channel_description)
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "default_notification_channel"
    }
}
