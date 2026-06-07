package com.example.papaha_vpn

import android.app.Activity
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val TAG = "MainActivity"
        const val METHOD_CHANNEL = "com.papaha.vpn/xray"
        const val EVENT_CHANNEL = "com.papaha.vpn/xray_status"
        const val APPS_CHANNEL = "com.example.papaha_vpn/apps"
        const val VPN_PERMISSION_REQUEST = 100
    }

    private var pendingResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingConfig: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for VPN status
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    PapahaVpnService.statusCallback = { status ->
                        runOnUiThread { eventSink?.success(status) }
                    }
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    PapahaVpnService.statusCallback = null
                }
            })

        // MethodChannel for VPN control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val vlessUrl = call.argument<String>("config") ?: ""
                        pendingConfig = vlessUrl
                        val vpnIntent = VpnService.prepare(this)
                        if (vpnIntent != null) {
                            pendingResult = result
                            startActivityForResult(vpnIntent, VPN_PERMISSION_REQUEST)
                        } else {
                            // Разрешение уже есть — сохраняем и запускаем
                            saveVlessAndStart(vlessUrl)
                            result.success(true)
                        }
                    }
                    "disconnect" -> {
                        stopVpnService()
                        result.success(true)
                    }
                    "refreshWidget" -> {
                        VpnWidgetProvider.refreshAllWidgets(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // MethodChannel: list of installed user apps for split tunneling
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstalledApps") {
                    try {
                        val pm = packageManager
                        val packages = pm.getInstalledPackages(PackageManager.GET_META_DATA)
                        val apps = packages
                            .filter { pkg ->
                                // only user-installed apps (not system)
                                val flags = pkg.applicationInfo?.flags ?: 0
                                (flags and ApplicationInfo.FLAG_SYSTEM) == 0
                                    && pkg.packageName != packageName
                            }
                            .map { pkg ->
                                val appInfo = pkg.applicationInfo ?: return@map null
                                mapOf(
                                    "packageName" to pkg.packageName,
                                    "label" to pm.getApplicationLabel(appInfo).toString()
                                )
                            }
                            .filterNotNull()
                            .sortedBy { it["label"] }
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("APPS_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveVlessAndStart(vlessUrl: String) {
        // Сохраняем VLESS URL для виджета/тайла
        val prefs = getSharedPreferences(VpnWidgetProvider.PREFS_NAME, MODE_PRIVATE)
        prefs.edit()
            .putString(VpnWidgetProvider.KEY_LAST_VLESS, vlessUrl)
            .apply()
        // Запускаем PapahaVpnService с VLESS URL
        startVpnService(vlessUrl)
    }

    private fun startVpnService(vlessUrl: String) {
        val intent = Intent(this, PapahaVpnService::class.java).apply {
            action = PapahaVpnService.ACTION_START
            putExtra(PapahaVpnService.EXTRA_CONFIG, vlessUrl)
        }
        startForegroundService(intent)
    }

    private fun stopVpnService() {
        val intent = Intent(this, PapahaVpnService::class.java).apply {
            action = PapahaVpnService.ACTION_STOP
        }
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST) {
            if (resultCode == Activity.RESULT_OK) {
                pendingConfig?.let { saveVlessAndStart(it) }
                pendingConfig = null
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            }
            pendingResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == VpnWidgetProvider.ACTION_TOGGLE_VPN) {
            triggerFlutterToggle()
        }
    }

    override fun onStart() {
        super.onStart()
        if (intent?.action == VpnWidgetProvider.ACTION_TOGGLE_VPN) {
            // Ждём пока Flutter engine готов
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                triggerFlutterToggle()
            }, 800)
        }
    }

    private fun triggerFlutterToggle() {
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, METHOD_CHANNEL).invokeMethod("widgetToggle", null)
        }
    }
}
