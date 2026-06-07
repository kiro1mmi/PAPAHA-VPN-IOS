# libXray Integration Guide

## Overview

PAPAHA VPN v2.0 uses libXray (official Xray-core wrapper) for stable VPN connections.
This replaces the old approach of running xray as a separate process.

## Android Setup

### 1. Compile libXray for Android

```bash
# Clone libXray
git clone https://github.com/XTLS/libXray.git
cd libXray

# Install gomobile
go install golang.org/x/mobile/cmd/gomobile@latest
gomobile init

# Build for Android (requires Android NDK)
python3 build/main.py android
```

This produces `libXray.aar` in the output directory.

### 2. Add to project

```bash
cp libXray.aar PAPAHA-VPN-APP/papaha_vpn_app/android/app/libs/
```

### 3. Update build.gradle.kts

Add to `android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation(fileTree("libs"))
}
```

### 4. Update PapahaVpnService.kt

Once libXray.aar is added, replace XrayManager process-based approach with:
```kotlin
import libXray.Libxray

// Initialize
Libxray.initV2Env(context.filesDir.absolutePath, "")

// Create V2RayPoint
val v2rayPoint = Libxray.newV2RayPoint(vpnServiceSupportsSet, true)
v2rayPoint.configureFileContent = xrayJsonConfig
v2rayPoint.runLoop(false)

// Stop
v2rayPoint.stopLoop()
```

The key advantage: `vpnServiceSupportsSet.protect(fd)` is called by Xray-core
automatically for every outbound socket, preventing traffic loops.

## iOS Setup

### 1. Compile libXray for iOS

```bash
cd libXray
python3 build/main.py apple go
```

This produces `LibXray.xcframework`.

### 2. Create Network Extension target

In Xcode:
1. File → New → Target → Network Extension
2. Provider Type: Packet Tunnel
3. Name: PapahaVPNTunnel
4. Add App Group: group.com.papaha.vpn

### 3. Add libXray to extension

Drag `LibXray.xcframework` into the Network Extension target.

### 4. PacketTunnelProvider.swift

```swift
import NetworkExtension
import LibXray

class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Read config from App Group
        let config = readConfigFromAppGroup()
        
        // Start Xray via libXray
        LibXray.startXray(config)
        
        // Setup TUN
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.19.0.1")
        settings.mtu = 9000
        // ... configure routes, DNS
        
        setTunnelNetworkSettings(settings) { error in
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        LibXray.stopXray()
        completionHandler()
    }
}
```

## Current State (without libXray .aar)

The app currently works with:
- Android: xray binary + tun2socks (functional but less stable)
- iOS: Not yet implemented (needs Network Extension + libXray)

Once you compile and add libXray, the native code is ready to switch to the
in-process approach. The Flutter UI layer doesn't need any changes.
