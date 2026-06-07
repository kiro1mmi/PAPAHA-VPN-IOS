package com.example.papaha_vpn

import android.content.Intent
import android.os.Build
import android.service.quicksettings.TileService
import android.service.quicksettings.Tile
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class VpnTileService : TileService() {

    private fun isConnected(): Boolean {
        val prefs = getSharedPreferences(VpnWidgetProvider.PREFS_NAME, MODE_PRIVATE)
        return prefs.getString(VpnWidgetProvider.KEY_VPN_STATUS, "disconnected") == "connected"
    }

    override fun onStartListening() {
        super.onStartListening()
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        // Открываем приложение с командой toggle — Flutter сам переключает VPN
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = VpnWidgetProvider.ACTION_TOGGLE_VPN
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivityAndCollapse(launchIntent)
    }

    private fun updateTile() {
        val tile = qsTile ?: return
        tile.label = "PAPAHA VPN"
        tile.state = if (isConnected()) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
        tile.updateTile()
    }

    override fun onTileAdded() {
        super.onTileAdded()
        updateTile()
    }
}
