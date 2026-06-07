package com.example.papaha_vpn

import android.net.Uri
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Builds Xray JSON config from a VLESS share URL.
 * Supports: VLESS + Reality, VLESS + TLS, VLESS + xHTTP, VLESS + WS
 */
object XrayConfigBuilder {
    private const val TAG = "XrayConfigBuilder"

    fun buildFromVlessUrl(url: String, socksPort: Int): String {
        return try {
            val parsed = parseVlessUrl(url)
            buildConfig(parsed, socksPort)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse VLESS URL: ${e.message}")
            buildFallbackConfig(socksPort)
        }
    }

    private data class VlessParams(
        val uuid: String,
        val address: String,
        val port: Int,
        val security: String, // reality, tls, none
        val sni: String,
        val fingerprint: String,
        val publicKey: String,
        val shortId: String,
        val network: String, // tcp, ws, xhttp, grpc
        val path: String,
        val host: String,
        val flow: String,
    )

    private fun parseVlessUrl(url: String): VlessParams {
        // Format: vless://uuid@host:port?params#remark
        val cleanUrl = url.trim()
        val uri = Uri.parse(cleanUrl)

        val uuid = uri.userInfo ?: ""
        val address = uri.host ?: ""
        val port = uri.port.takeIf { it > 0 } ?: 443

        val params = uri.queryParameterNames.associateWith { uri.getQueryParameter(it) ?: "" }

        return VlessParams(
            uuid = uuid,
            address = address,
            port = port,
            security = params["security"] ?: "none",
            sni = params["sni"] ?: address,
            fingerprint = params["fp"] ?: "chrome",
            publicKey = params["pbk"] ?: "",
            shortId = params["sid"] ?: "",
            network = params["type"] ?: "tcp",
            path = params["path"] ?: "/",
            host = params["host"] ?: address,
            flow = params["flow"] ?: "",
        )
    }

    private fun buildConfig(p: VlessParams, socksPort: Int): String {
        val streamSettings = JSONObject().apply {
            put("network", when (p.network) {
                "http" -> "xhttp"
                else -> p.network
            })
            put("security", p.security)

            when (p.security) {
                "reality" -> put("realitySettings", JSONObject().apply {
                    put("serverName", p.sni)
                    put("fingerprint", p.fingerprint)
                    put("publicKey", p.publicKey)
                    put("shortId", p.shortId)
                })
                "tls" -> put("tlsSettings", JSONObject().apply {
                    put("serverName", p.sni)
                    put("fingerprint", p.fingerprint)
                    put("allowInsecure", false)
                })
            }

            when (p.network) {
                "ws" -> put("wsSettings", JSONObject().apply {
                    put("path", p.path)
                    put("headers", JSONObject().apply { put("Host", p.host) })
                })
                "http", "xhttp" -> put("xhttpSettings", JSONObject().apply {
                    put("path", p.path)
                    put("host", p.host)
                })
                "grpc" -> put("grpcSettings", JSONObject().apply {
                    put("serviceName", p.path.removePrefix("/"))
                })
            }
        }

        val outbound = JSONObject().apply {
            put("tag", "proxy")
            put("protocol", "vless")
            put("settings", JSONObject().apply {
                put("vnext", JSONArray().apply {
                    put(JSONObject().apply {
                        put("address", p.address)
                        put("port", p.port)
                        put("users", JSONArray().apply {
                            put(JSONObject().apply {
                                put("id", p.uuid)
                                put("flow", p.flow)
                                put("encryption", "none")
                            })
                        })
                    })
                })
            })
            put("streamSettings", streamSettings)
        }

        return JSONObject().apply {
            put("log", JSONObject().apply { put("loglevel", "warning") })
            put("stats", JSONObject())
            put("policy", JSONObject().apply {
                put("levels", JSONObject().apply {
                    put("0", JSONObject().apply {
                        put("handshake", 4)
                        put("connIdle", 300)
                        put("uplinkOnly", 1)
                        put("downlinkOnly", 1)
                    })
                })
                put("system", JSONObject().apply {
                    put("statsOutboundUplink", true)
                    put("statsOutboundDownlink", true)
                })
            })
            put("inbounds", JSONArray().apply {
                put(JSONObject().apply {
                    put("tag", "socks")
                    put("port", socksPort)
                    put("listen", "127.0.0.1")
                    put("protocol", "socks")
                    put("settings", JSONObject().apply {
                        put("auth", "noauth")
                        put("udp", true)
                    })
                    put("sniffing", JSONObject().apply {
                        put("enabled", true)
                        put("destOverride", JSONArray().apply {
                            put("http")
                            put("tls")
                            put("quic")
                        })
                    })
                })
            })
            put("outbounds", JSONArray().apply {
                put(outbound)
                put(JSONObject().apply {
                    put("tag", "direct")
                    put("protocol", "freedom")
                    put("settings", JSONObject().apply {
                        put("domainStrategy", "UseIP")
                    })
                })
                put(JSONObject().apply {
                    put("tag", "block")
                    put("protocol", "blackhole")
                })
            })
            put("routing", JSONObject().apply {
                put("domainStrategy", "IPIfNonMatch")
                put("rules", JSONArray().apply {
                    // Direct access to VPN server
                    put(JSONObject().apply {
                        put("type", "field")
                        put("ip", JSONArray().apply { put(p.address) })
                        put("outboundTag", "direct")
                    })
                    // Private IPs direct
                    put(JSONObject().apply {
                        put("type", "field")
                        put("ip", JSONArray().apply { put("geoip:private") })
                        put("outboundTag", "direct")
                    })
                    // Block ads
                    put(JSONObject().apply {
                        put("type", "field")
                        put("domain", JSONArray().apply { put("geosite:category-ads-all") })
                        put("outboundTag", "block")
                    })
                })
            })
            put("dns", JSONObject().apply {
                put("servers", JSONArray().apply {
                    put("8.8.8.8")
                    put("1.1.1.1")
                })
            })
        }.toString(2)
    }

    private fun buildFallbackConfig(socksPort: Int): String {
        return JSONObject().apply {
            put("log", JSONObject().apply { put("loglevel", "warning") })
            put("inbounds", JSONArray().apply {
                put(JSONObject().apply {
                    put("port", socksPort)
                    put("listen", "127.0.0.1")
                    put("protocol", "socks")
                    put("settings", JSONObject().apply {
                        put("auth", "noauth")
                        put("udp", true)
                    })
                })
            })
            put("outbounds", JSONArray().apply {
                put(JSONObject().apply {
                    put("protocol", "freedom")
                })
            })
        }.toString(2)
    }
}
