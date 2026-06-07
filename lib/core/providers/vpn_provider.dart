import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_v2ray_plus/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_provider.dart';
import '../services/widget_service.dart';

enum VpnStatus { disconnected, connecting, connected, error }

class VpnState {
  final VpnStatus status;
  final int? pingMs;
  final String? errorMessage;
  final String? activeServer;
  final Duration connectionDuration;
  final int uploadSpeed;
  final int downloadSpeed;

  const VpnState({
    this.status = VpnStatus.disconnected,
    this.pingMs,
    this.errorMessage,
    this.activeServer,
    this.connectionDuration = Duration.zero,
    this.uploadSpeed = 0,
    this.downloadSpeed = 0,
  });

  VpnState copyWith({
    VpnStatus? status,
    int? pingMs,
    String? errorMessage,
    String? activeServer,
    Duration? connectionDuration,
    int? uploadSpeed,
    int? downloadSpeed,
  }) =>
      VpnState(
        status: status ?? this.status,
        pingMs: pingMs ?? this.pingMs,
        errorMessage: errorMessage ?? this.errorMessage,
        activeServer: activeServer ?? this.activeServer,
        connectionDuration: connectionDuration ?? this.connectionDuration,
        uploadSpeed: uploadSpeed ?? this.uploadSpeed,
        downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      );
}

class VpnNotifier extends StateNotifier<VpnState> {
  final FlutterV2ray _v2ray = FlutterV2ray();
  Timer? _durationTimer;
  Timer? _pingTimer;
  DateTime? _connectedAt;
  Set<String> _excludedApps = {};
  List<String> _lastKeys = [];
  bool _routingEnabled = true; // iOS split routing

  static const _nativeChannel = MethodChannel('com.papaha.vpn/xray');

  VpnNotifier() : super(const VpnState()) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _initAndroid();
    }
    // Слушаем widgetToggle от виджета/тайла (только Android)
    if (!kIsWeb && Platform.isAndroid) {
      _nativeChannel.setMethodCallHandler((call) async {
        if (call.method == 'widgetToggle') {
          await toggle(keys: _lastKeys);
        }
      });
    }
  }

  void _initAndroid() {
    _v2ray.initializeVless(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_notification',
    );

    _v2ray.onStatusChanged.listen((status) {
      switch (status.state) {
        case 'CONNECTED':
          if (state.status != VpnStatus.connected) {
            _connectedAt = DateTime.now();
            _startDurationTimer();
            _startPingTimer();
            state = state.copyWith(status: VpnStatus.connected, errorMessage: null);
            WidgetService.updateVpnStatus(true);
          }
          break;
        case 'CONNECTING':
          state = state.copyWith(status: VpnStatus.connecting);
          break;
        case 'DISCONNECTED':
          _stopDurationTimer();
          _stopPingTimer();
          state = state.copyWith(
            status: VpnStatus.disconnected,
            pingMs: null,
            connectionDuration: Duration.zero,
            uploadSpeed: 0,
            downloadSpeed: 0,
          );
          WidgetService.updateVpnStatus(false);
          break;
      }
    });
  }

  void updateExcludedApps(Set<String> apps) {
    _excludedApps = apps;
  }

  void updateRouting(bool enabled) {
    _routingEnabled = enabled;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _connectedAt ??= DateTime.now();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (state.status == VpnStatus.connected && _connectedAt != null) {
        state = state.copyWith(
          connectionDuration: DateTime.now().difference(_connectedAt!),
        );
      }
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedAt = null;
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _doPing();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (state.status == VpnStatus.connected) _doPing();
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _doPing() async {
    final server = state.activeServer;
    if (server == null) return;
    final ping = await _tcpPing(server);
    if (ping > 0 && mounted && state.status == VpnStatus.connected) {
      state = state.copyWith(pingMs: ping);
    }
  }

  Future<void> toggle({required List<String> keys}) async {
    if (keys.isNotEmpty) _lastKeys = keys;
    if (state.status == VpnStatus.connected || state.status == VpnStatus.connecting) {
      await _disconnect();
    } else {
      await _connect(keys.isNotEmpty ? keys : _lastKeys);
    }
  }

  Future<void> connectToServer(String key) async {
    if (state.status == VpnStatus.connected || state.status == VpnStatus.connecting) {
      await _disconnect();
    }
    await _connect([key]);
  }

  Future<void> _connect(List<String> keys) async {
    if (keys.isEmpty) {
      state = state.copyWith(
        status: VpnStatus.error,
        errorMessage: 'Нет доступных серверов. Обновите конфигурацию.',
      );
      return;
    }

    state = state.copyWith(status: VpnStatus.connecting, errorMessage: null);

    try {
      if (kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 600));
        _connectedAt = DateTime.now();
        _startDurationTimer();
        final bestKey = keys.first;
        final ping = await _tcpPing(bestKey);
        state = state.copyWith(
          status: VpnStatus.connected,
          pingMs: ping > 0 ? ping : 42,
          activeServer: bestKey,
        );
        _startPingTimer();
        WidgetService.updateVpnStatus(true);
        return;
      }

      if (!Platform.isAndroid && !Platform.isIOS) {
        state = state.copyWith(
          status: VpnStatus.error,
          errorMessage: 'VPN поддерживается только на Android и iOS',
        );
        return;
      }

      final bestKey = await _findFastestKey(keys);
      state = state.copyWith(activeServer: bestKey);

      // Сохраняем для виджета/тайла (Android only)
      if (Platform.isAndroid) await _saveLastVless(bestKey);

      final parser = FlutterV2ray.parseFromURL(bestKey);
      final config = parser.getFullConfiguration();

      if (config.isEmpty) {
        state = state.copyWith(
          status: VpnStatus.error,
          errorMessage: 'Не удалось разобрать VPN-ключ',
        );
        return;
      }

      final allowed = await _v2ray.requestPermission();
      if (!allowed && Platform.isAndroid) {
        // На iOS requestPermission всегда возвращает true или обрабатывается внутри startVless
        state = state.copyWith(
          status: VpnStatus.error,
          errorMessage: 'Разрешение на VPN отклонено',
        );
        return;
      }

      await _v2ray.startVless(
        remark: 'PAPAHA VPN',
        config: config,
        blockedApps: Platform.isAndroid && _excludedApps.isNotEmpty
            ? _excludedApps.toList()
            : null,
        // iOS: если маршрутизация включена — российские подсети идут напрямую
        bypassSubnets: (Platform.isIOS && _routingEnabled)
            ? _ruSubnets
            : null,
        dnsServers: const ['8.8.8.8', '1.1.1.1'],
        proxyOnly: Platform.isIOS,
        showNotificationDisconnectButton: true,
        notificationDisconnectButtonName: 'Отключить',
      );

      _connectedAt = DateTime.now();
      _startDurationTimer();
      _startPingTimer();
      state = state.copyWith(status: VpnStatus.connected, errorMessage: null);
      WidgetService.updateVpnStatus(true);

    } catch (e) {
      state = state.copyWith(
        status: VpnStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await _v2ray.stopVless();
      }
    } catch (_) {}
    _stopDurationTimer();
    _stopPingTimer();
    WidgetService.updateVpnStatus(false);
    state = state.copyWith(
      status: VpnStatus.disconnected,
      pingMs: null,
      connectionDuration: Duration.zero,
      uploadSpeed: 0,
      downloadSpeed: 0,
    );
  }

  Future<int> _tcpPing(String key) async {
    try {
      final uri = Uri.tryParse(key.split('#').first);
      if (uri == null) return -1;
      final host = uri.host;
      final port = uri.port;
      if (host.isEmpty || port == 0) return -1;
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 3));
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  Future<void> _saveLastVless(String key) async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('widget_last_vless', key);
    } catch (_) {}
  }

  Future<String> _findFastestKey(List<String> keys) async {
    if (keys.length == 1) return keys.first;
    String? bestKey;
    int bestPing = 99999;
    final results = await Future.wait(
      keys.map((key) => _tcpPing(key)),
      eagerError: false,
    );
    for (int i = 0; i < keys.length; i++) {
      final ping = results[i];
      if (ping > 0 && ping < bestPing) {
        bestPing = ping;
        bestKey = keys[i];
      }
    }
    if (bestKey != null && bestPing < 99999) {
      state = state.copyWith(pingMs: bestPing, activeServer: bestKey);
    }
    return bestKey ?? keys.first;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }

  // Основные российские IP подсети для bypass (маршрутизация)
  static const List<String> _ruSubnets = [
    '5.8.0.0/13', '5.16.0.0/13', '5.24.0.0/14', '5.44.0.0/14',
    '31.13.0.0/16', '31.148.0.0/16', '37.9.0.0/16', '37.18.0.0/15',
    '45.8.0.0/16', '45.9.0.0/16', '45.10.0.0/15', '45.12.0.0/14',
    '45.80.0.0/14', '77.37.0.0/16', '77.72.0.0/13', '78.24.0.0/13',
    '79.96.0.0/11', '80.64.0.0/11', '81.0.0.0/9', '82.96.0.0/11',
    '83.0.0.0/10', '84.0.0.0/9', '85.0.0.0/9', '87.224.0.0/11',
    '88.0.0.0/9', '89.0.0.0/9', '90.0.0.0/9', '91.0.0.0/9',
    '92.39.0.0/16', '92.40.0.0/13', '93.100.0.0/14', '93.153.0.0/16',
    '94.25.0.0/16', '94.100.0.0/14', '95.24.0.0/13', '176.0.0.0/9',
    '178.0.0.0/9', '185.0.0.0/9', '188.0.0.0/8', '193.0.0.0/8',
    '194.0.0.0/8', '195.0.0.0/8', '213.0.0.0/8',
    // localhost и private
    '127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16',
  ];
}

final vpnProvider = StateNotifierProvider<VpnNotifier, VpnState>((ref) {
  final notifier = VpnNotifier();
  ref.listen<SettingsState>(settingsProvider, (_, next) {
    notifier.updateExcludedApps(next.excludedPackages);
    notifier.updateRouting(next.routingEnabled);
  }, fireImmediately: true);
  return notifier;
});
