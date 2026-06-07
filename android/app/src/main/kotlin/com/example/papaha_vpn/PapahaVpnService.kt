package com.example.papaha_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*

/**
 * VPN Service: xray process (SOCKS) + tun2socks (TUN → SOCKS bridge).
 * Simple and proven approach.
 */
class PapahaVpnService : VpnService() {

    companion object {
        const val TAG = "PapahaVpnService"
        const val CHANNEL_ID = "papaha_vpn_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_START = "com.example.papaha_vpn.START"
        const val ACTION_STOP = "com.example.papaha_vpn.STOP"
        const val EXTRA_CONFIG = "config"

        const val SOCKS_PORT = 10808
        const val TUN_MTU = 1500

        var statusCallback: ((String) -> Unit)? = null
        var isRunning = false
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var tun2socksProcess: Process? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val config = intent.getStringExtra(EXTRA_CONFIG) ?: ""
                serviceScope.launch { startVpn(config) }
            }
            ACTION_STOP -> stopVpn()
        }
        return START_STICKY
    }

    private suspend fun startVpn(vlessUrl: String) {
        Log.d(TAG, "Starting VPN...")
        statusCallback?.invoke("CONNECTING")

        try {
            createNotificationChannel()
            withContext(Dispatchers.Main) {
                startForeground(NOTIFICATION_ID, buildNotification("Подключение..."))
            }

            // 1. Build xray config (SOCKS inbound only)
            val xrayConfig = XrayConfigBuilder.buildFromVlessUrl(vlessUrl, SOCKS_PORT)
            Log.d(TAG, "Xray config built")

            // 2. Prepare and start xray process
            XrayManager.prepareGeoFiles(this)
            val xrayStarted = XrayManager.startXray(this, xrayConfig, 0)
            if (!xrayStarted) {
                Log.e(TAG, "Xray failed to start")
                statusCallback?.invoke("ERROR:VPN engine failed")
                stopSelf()
                return
            }
            Log.d(TAG, "Xray started on SOCKS port $SOCKS_PORT")

            // 3. Create TUN interface
            val builder = Builder()
                .setSession("PAPAHA VPN")
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("1.1.1.1")
                .setMtu(TUN_MTU)

            // Exclude our own app
            try { builder.addDisallowedApplication(packageName) } catch (_: Exception) {}

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e(TAG, "Failed to establish TUN")
                statusCallback?.invoke("ERROR:Cannot create VPN tunnel")
                XrayManager.stopXray()
                stopSelf()
                return
            }
            Log.d(TAG, "TUN established, fd=${vpnInterface!!.fd}")

            // 4. Start tun2socks to bridge TUN traffic to xray SOCKS
            startTun2socks()

            // Wait a moment and verify
            delay(1000)

            if (XrayManager.isRunning()) {
                isRunning = true
                statusCallback?.invoke("CONNECTED")
                withContext(Dispatchers.Main) {
                    updateNotification("PAPAHA VPN подключен")
                }
                Log.d(TAG, "VPN connected!")
            } else {
                Log.e(TAG, "Xray died after start")
                statusCallback?.invoke("ERROR:Connection failed")
                stopVpn()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            statusCallback?.invoke("ERROR:${e.message}")
            stopVpn()
        }
    }

    private fun startTun2socks() {
        try {
            val tun2socksFile = XrayManager.prepareAsset(this, "tun2socks") ?: return
            tun2socksFile.setExecutable(true)

            val fd = vpnInterface!!.fd

            val cmd = arrayOf(
                tun2socksFile.absolutePath,
                "--netif-ipaddr", "10.0.0.1",
                "--netif-netmask", "255.255.255.0",
                "--socks-server-addr", "127.0.0.1:$SOCKS_PORT",
                "--tunmtu", TUN_MTU.toString(),
                "--tunfd", fd.toString(),
                "--enable-udprelay",
                "--loglevel", "warning"
            )

            tun2socksProcess = ProcessBuilder(*cmd)
                .redirectErrorStream(true)
                .start()

            Log.d(TAG, "tun2socks started")
        } catch (e: Exception) {
            Log.e(TAG, "tun2socks failed: ${e.message}")
        }
    }

    private fun stopVpn() {
        Log.d(TAG, "Stopping VPN...")
        isRunning = false

        tun2socksProcess?.destroy()
        tun2socksProcess = null

        XrayManager.stopXray()

        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {}

        statusCallback?.invoke("DISCONNECTED")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVpn()
        serviceScope.cancel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "PAPAHA VPN", NotificationManager.IMPORTANCE_LOW
            ).apply { description = "VPN status" }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, PapahaVpnService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PAPAHA VPN")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_vpn_notification)
            .addAction(android.R.drawable.ic_delete, "Отключить", stopIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(text))
    }
}
