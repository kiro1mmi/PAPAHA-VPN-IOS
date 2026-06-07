package com.example.papaha_vpn

import android.content.Context
import android.util.Log
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream

/**
 * Manages Xray-core process lifecycle.
 *
 * Current approach: runs xray binary as subprocess (like current implementation).
 * Target approach: when libXray .aar is integrated, this will use JNI calls instead.
 *
 * Migration path:
 * 1. Current: ProcessBuilder → xray binary (works but no protect())
 * 2. Target: libXray.runLoop() via JNI (proper protect(), in-process)
 */
object XrayManager {
    const val TAG = "XrayManager"

    private var xrayProcess: Process? = null
    private var xrayJob: Job? = null

    fun prepareAsset(context: Context, name: String): File? {
        return try {
            val file = File(context.filesDir, name)
            if (!file.exists()) {
                context.assets.open(name).use { input ->
                    FileOutputStream(file).use { output ->
                        input.copyTo(output)
                    }
                }
                file.setExecutable(true)
                Log.d(TAG, "Prepared asset: $name")
            }
            file
        } catch (e: Exception) {
            Log.e(TAG, "Failed to prepare $name: ${e.message}")
            null
        }
    }

    fun startXray(context: Context, config: String, tunFd: Int): Boolean {
        return try {
            stopXray()

            // Prepare xray binary
            val xrayFile = prepareAsset(context, "xray") ?: return false

            // Prepare geo files
            listOf("geoip.dat", "geosite.dat").forEach { name ->
                prepareAsset(context, name)
            }

            // Write config
            val configFile = File(context.filesDir, "xray_config.json")
            configFile.writeText(config)

            Log.d(TAG, "Starting xray, config size=${config.length}")

            val env = mapOf(
                "XRAY_LOCATION_ASSET" to context.filesDir.absolutePath,
                "XRAY_LOCATION_CONFIG" to context.filesDir.absolutePath
            )

            val processBuilder = ProcessBuilder(
                xrayFile.absolutePath,
                "run",
                "-config", configFile.absolutePath
            ).apply {
                environment().putAll(env)
                redirectErrorStream(true)
            }

            xrayProcess = processBuilder.start()

            // Read logs in background
            xrayJob = CoroutineScope(Dispatchers.IO).launch {
                try {
                    xrayProcess?.inputStream?.bufferedReader()?.forEachLine { line ->
                        Log.d(TAG, "Xray: $line")
                    }
                } catch (e: Exception) {
                    if (isActive) Log.e(TAG, "Xray log error: ${e.message}")
                }
            }

            // Wait for startup
            Thread.sleep(800)
            val alive = xrayProcess?.isAlive == true
            Log.d(TAG, "Xray alive: $alive")
            alive
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start xray: ${e.message}", e)
            false
        }
    }

    fun stopXray() {
        try {
            xrayJob?.cancel()
            xrayJob = null
            xrayProcess?.destroy()
            xrayProcess = null
            Log.d(TAG, "Xray stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping xray: ${e.message}")
        }
    }

    fun prepareGeoFiles(context: Context) {
        listOf("geoip.dat", "geosite.dat").forEach { name ->
            prepareAsset(context, name)
        }
    }

    fun isRunning(): Boolean = xrayProcess?.isAlive == true
}
