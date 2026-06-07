import NetworkExtension
import os.log

// LibXray C functions (exported from LibXray.xcframework via cgo)
// These are the actual function signatures from libXray's xray_wrapper.go
@_silgen_name("LibXrayRunXray")
func LibXrayRunXray(_ configJSON: UnsafePointer<CChar>) -> UnsafePointer<CChar>?

@_silgen_name("LibXrayStopXray")
func LibXrayStopXray() -> UnsafePointer<CChar>?

@_silgen_name("LibXrayXrayVersion")
func LibXrayXrayVersion() -> UnsafePointer<CChar>?

@_silgen_name("LibXrayInitEnv")
func LibXrayInitEnv(_ assetPath: UnsafePointer<CChar>, _ key: UnsafePointer<CChar>) -> UnsafePointer<CChar>?

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private let log = OSLog(subsystem: "com.papaha.vpn.PacketTunnel", category: "tunnel")
    private var isXrayRunning = false
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel...", log: log, type: .info)
        
        // Read config from App Group shared UserDefaults
        let sharedDefaults = UserDefaults(suiteName: "group.com.papaha.vpn")
        let vlessKey = sharedDefaults?.string(forKey: "vpn_config") ?? ""
        
        guard !vlessKey.isEmpty else {
            os_log("No VPN config found", log: log, type: .error)
            completionHandler(makeError("No VPN configuration. Open the app first."))
            return
        }
        
        // Build Xray JSON config from VLESS URL
        let xrayConfig = buildXrayConfig(from: vlessKey)
        
        // Configure TUN
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")
        settings.mtu = 1500
        
        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.dnsSettings = dns
        
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                os_log("Failed to set tunnel settings: %{public}@", log: self.log, type: .error, error.localizedDescription)
                completionHandler(error)
                return
            }
            
            // Initialize libXray
            let assetPath = self.getAssetPath()
            _ = LibXrayInitEnv(assetPath, "")
            
            // Start Xray
            let result = LibXrayRunXray(xrayConfig)
            if let resultPtr = result {
                let resultStr = String(cString: resultPtr)
                if !resultStr.isEmpty && resultStr != "{}" {
                    os_log("Xray start result: %{public}@", log: self.log, type: .info, resultStr)
                }
            }
            
            self.isXrayRunning = true
            os_log("Xray started, tunnel active", log: self.log, type: .info)
            completionHandler(nil)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping tunnel, reason: %{public}d", log: log, type: .info, reason.rawValue)
        
        if isXrayRunning {
            _ = LibXrayStopXray()
            isXrayRunning = false
        }
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        if let config = String(data: messageData, encoding: .utf8) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.papaha.vpn")
            sharedDefaults?.set(config, forKey: "vpn_config")
        }
        completionHandler?(nil)
    }
    
    // MARK: - Helpers
    
    private func getAssetPath() -> String {
        // Geo files should be in the extension's bundle or shared container
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.papaha.vpn"
        )
        return containerURL?.path ?? Bundle.main.bundlePath
    }
    
    private func buildXrayConfig(from vlessUrl: String) -> String {
        // Parse VLESS URL and build Xray JSON config
        // Similar to Android's XrayConfigBuilder
        guard let components = URLComponents(string: vlessUrl.split(separator: "#").first.map(String.init) ?? vlessUrl) else {
            return "{}"
        }
        
        let uuid = components.user ?? ""
        let host = components.host ?? ""
        let port = components.port ?? 443
        
        let params = Dictionary(uniqueKeysWithValues:
            (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
        )
        
        let security = params["security"] ?? "none"
        let sni = params["sni"] ?? host
        let fp = params["fp"] ?? "chrome"
        let pbk = params["pbk"] ?? ""
        let sid = params["sid"] ?? ""
        let flow = params["flow"] ?? ""
        let network = params["type"] ?? "tcp"
        
        var streamSettings: [String: Any] = [
            "network": network,
            "security": security
        ]
        
        if security == "reality" {
            streamSettings["realitySettings"] = [
                "serverName": sni,
                "fingerprint": fp,
                "publicKey": pbk,
                "shortId": sid
            ]
        } else if security == "tls" {
            streamSettings["tlsSettings"] = [
                "serverName": sni,
                "fingerprint": fp
            ]
        }
        
        let config: [String: Any] = [
            "log": ["loglevel": "warning"],
            "inbounds": [
                ["tag": "socks", "port": 10808, "listen": "127.0.0.1", "protocol": "socks",
                 "settings": ["auth": "noauth", "udp": true],
                 "sniffing": ["enabled": true, "destOverride": ["http", "tls"]]]
            ],
            "outbounds": [
                ["tag": "proxy", "protocol": "vless",
                 "settings": ["vnext": [["address": host, "port": port,
                    "users": [["id": uuid, "flow": flow, "encryption": "none"]]]]],
                 "streamSettings": streamSettings],
                ["tag": "direct", "protocol": "freedom"],
                ["tag": "block", "protocol": "blackhole"]
            ],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": [
                    ["type": "field", "ip": [host], "outboundTag": "direct"],
                    ["type": "field", "ip": ["geoip:private"], "outboundTag": "direct"]
                ]
            ]
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    private func makeError(_ message: String) -> NSError {
        return NSError(domain: "com.papaha.vpn", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: message])
    }
}
