package com.example.papaha_vpn

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.widget.RemoteViews

class VpnWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_VPN = "com.example.papaha_vpn.WIDGET_TOGGLE_VPN"
        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_VPN_STATUS = "flutter.widget_vpn_status"
        const val KEY_LAST_VLESS = "flutter.widget_last_vless"
        const val KEY_LAST_CONFIG = "flutter.widget_last_config"

        fun refreshAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, VpnWidgetProvider::class.java))
            for (id in ids) renderWidget(context, manager, id)
        }

        fun renderWidget(context: Context, manager: AppWidgetManager, widgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isConnected = prefs.getString(KEY_VPN_STATUS, "disconnected") == "connected"

            val views = RemoteViews(context.packageName, R.layout.vpn_widget)

            if (isConnected) {
                views.setImageViewResource(R.id.widget_toggle_btn, R.drawable.widget_btn_on)
                views.setTextViewText(R.id.widget_status, "ВКЛ")
                views.setTextColor(R.id.widget_status, 0xFF00E676.toInt())
            } else {
                views.setImageViewResource(R.id.widget_toggle_btn, R.drawable.widget_btn_off)
                views.setTextViewText(R.id.widget_status, "ВЫКЛ")
                views.setTextColor(R.id.widget_status, 0x88FFFFFF.toInt())
            }

            val toggleIntent = Intent(context, VpnWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE_VPN
            }
            val pi = PendingIntent.getBroadcast(
                context, widgetId, toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_toggle_btn, pi)
            manager.updateAppWidget(widgetId, views)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) renderWidget(context, appWidgetManager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_TOGGLE_VPN) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isConnected = prefs.getString(KEY_VPN_STATUS, "disconnected") == "connected"

        if (isConnected) {
            // Выключаем напрямую
            context.startService(Intent(context, PapahaVpnService::class.java).apply {
                action = PapahaVpnService.ACTION_STOP
            })
            prefs.edit().putString(KEY_VPN_STATUS, "disconnected").apply()
            refreshAllWidgets(context)
        } else {
            // Включаем — проверяем разрешение
            val vlessUrl = prefs.getString(KEY_LAST_VLESS, "") ?: ""
            if (vlessUrl.isNotEmpty() && VpnService.prepare(context) == null) {
                // Разрешение есть — запускаем напрямую
                context.startForegroundService(Intent(context, PapahaVpnService::class.java).apply {
                    action = PapahaVpnService.ACTION_START
                    putExtra(PapahaVpnService.EXTRA_CONFIG, vlessUrl)
                })
                prefs.edit().putString(KEY_VPN_STATUS, "connected").apply()
                refreshAllWidgets(context)
            } else {
                // Нужно разрешение или нет ключа — открываем приложение
                context.startActivity(Intent(context, MainActivity::class.java).apply {
                    action = ACTION_TOGGLE_VPN
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                })
            }
        }
    }
}
