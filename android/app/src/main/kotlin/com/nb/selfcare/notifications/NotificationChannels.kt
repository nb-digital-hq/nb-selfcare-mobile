package com.nb.selfcare.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.nb.selfcare.MainActivity
import com.nb.selfcare.R

/** Canales de notificación de la app. Todos son locales: no hay push remoto. */
object NotificationChannels {
    const val FASTING = "fasting_timer"
    const val REMINDERS = "habit_reminders"
    const val MOVEMENT = "movement_nudges"

    fun ensure(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannels(
            listOf(
                NotificationChannel(FASTING, context.getString(R.string.channel_fasting_name), NotificationManager.IMPORTANCE_LOW).apply {
                    description = context.getString(R.string.channel_fasting_desc)
                    setShowBadge(false)
                },
                NotificationChannel(REMINDERS, context.getString(R.string.channel_reminders_name), NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = context.getString(R.string.channel_reminders_desc)
                },
                NotificationChannel(MOVEMENT, context.getString(R.string.channel_movement_name), NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = context.getString(R.string.channel_movement_desc)
                },
            ),
        )
    }

    /** Abre la app (o la trae al frente) al tocar una notificación. */
    fun openAppIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
